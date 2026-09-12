import 'package:flutter/foundation.dart';

import '../models/assessment.dart';
import '../models/clinical.dart';
import '../models/daily.dart';
import '../models/game.dart';
import '../models/memory_fragment.dart';
import '../models/patient.dart';
import '../services/adaptive_difficulty_service.dart';
import 'ai_models.dart';

/// Everything the AI layer is allowed to know.
///
/// This is the seam that keeps the AI modular. It is built from ordinary
/// domain objects — the same ones the repositories already return — so when a
/// real backend replaces the local store, nothing in the AI layer changes: the
/// context is simply assembled from different sources.
///
/// It is also the privacy boundary. Only what is listed here can reach a model
/// provider, and [redacted] controls whether that includes the patient's name.
@immutable
class PatientAiContext {
  const PatientAiContext({
    required this.patient,
    required this.sessions,
    required this.levels,
    required this.cognitiveProfile,
    required this.reminders,
    required this.now,
    this.mood,
    this.journal = const <JournalEntry>[],
    this.completedToday = const <GameId>{},
    this.lastPlayed,
    this.engagementToday = 0,
    this.replyLanguage,
    this.intake,
    this.recentTurns = const <ConversationTurn>[],
    this.memoryInvitesRemainingToday = 0,
    this.memoryResurfaceCandidate,
    this.totalSharedMemories = 0,
    this.knownMemories = const <MemoryFragment>[],
    this.moodCheckInActive = false,
    this.moodCheckInTurn = 0,
  });

  final Patient patient;

  /// Newest first, exactly as `AppState.sessions` holds them.
  final List<GameSession> sessions;

  final Map<GameId, int> levels;
  final CognitiveProfile cognitiveProfile;
  final List<Reminder> reminders;

  /// Injected rather than read from the clock, so prompts and their expected
  /// answers are reproducible in tests.
  final DateTime now;

  final MoodLevel? mood;
  final List<JournalEntry> journal;
  final Set<GameId> completedToday;
  final GameId? lastPlayed;
  final int engagementToday;

  /// The language the assistant must answer in — the interface language, not
  /// the profile's, because the patient may have switched it deliberately.
  /// Null leaves the model to follow the profile.
  final String? replyLanguage;

  /// What the person said about themselves during onboarding.
  ///
  /// The richest personal material the app holds — why they came, what they
  /// still do unaided, who is around them — and the only source that makes a
  /// daily question about *this* person rather than about people in general.
  final IntakeRecord? intake;
  // ── Memory companion ────────────────────────────────────────────────────
  //
  // This session's own turns, oldest first, so a reply can stay coherent
  // ("you just said...") without a persisted store. Capped by the caller —
  // see `AiContextBuilder` — to keep the prompt small.
  final List<ConversationTurn> recentTurns;

  /// How many new-story invitations or resurfacings Saathi may still offer
  /// today (0, 1 or 2) — computed by `AppState.memoryInvitesRemainingToday`,
  /// not here, since the pacing decision belongs with the durable store.
  final int memoryInvitesRemainingToday;

  /// The one fragment `AppState` has picked as best to gently reoffer today,
  /// if any and if the budget allows it. The model decides *whether* and
  /// *how* to bring it up — never a quiz, an offer — this is only ever a
  /// candidate, not an instruction. This is the *only* fragment the model is
  /// ever told it may proactively raise; see [knownMemories] for the rest.
  final MemoryFragment? memoryResurfaceCandidate;

  /// How many memories have been shared in total, ever.
  final int totalSharedMemories;

  /// Every story this person has shared with Saathi before, across every past
  /// session — not just today's resurface candidate. Capped by the caller
  /// (see `AiContextBuilder`) to keep the prompt bounded as the store grows.
  ///
  /// This exists so recognition works both ways: if the patient brings up
  /// something she has mentioned before, or asks "did I tell you about my
  /// sister?", Saathi can actually know — without it, every fact she has ever
  /// shared is invisible the instant it stops being today's one candidate.
  /// The distinction from [memoryResurfaceCandidate] is proactive vs.
  /// reactive: the system prompt is explicit that Saathi may *recognise* or
  /// *answer from* anything here, but may only *proactively bring up*
  /// [memoryResurfaceCandidate] — otherwise this list would reopen the same
  /// "never turn a memory into a quiz" risk the resurfacing budget exists to
  /// prevent.
  final List<MemoryFragment> knownMemories;

  // ── Mood Check-In ───────────────────────────────────────────────────────
  //
  // Set only while the patient is inside the guided Mood Check-In
  // conversation (see `MoodCheckInScreen`) — every other call into `ask()`
  // leaves these at their defaults. When active, the assistant narrows to
  // one caring follow-up question at a time about how the patient feels,
  // instead of its usual schedule/reminders/companionship range, and reports
  // back when it judges the check-in complete — see the "MOOD CHECK-IN MODE"
  // section of `GeminiAiService._assistantSystem` and the equivalent branch
  // in `OnDeviceAiService.ask`.

  /// True for every turn of the check-in conversation, from the patient's
  /// first answer to the closing message.
  final bool moodCheckInActive;

  /// How many of the patient's answers this check-in has already received —
  /// 0 for the very first one. Used so the model (and the on-device fallback)
  /// know when to stop asking and wrap up, rather than running indefinitely.
  final int moodCheckInTurn;

  // ── Derived signals ────────────────────────────────────────────────────

  /// Sessions from the last [days] days, newest first.
  List<GameSession> recent({int days = 14}) =>
      sessions.where((GameSession s) => s.dayOffset < days).toList(growable: false);

  List<Reminder> get dueReminders => reminders
      .where((Reminder r) => !r.done && r.kind != ReminderKind.appointment)
      .toList(growable: false);

  List<Reminder> get doneReminders =>
      reminders.where((Reminder r) => r.done).toList(growable: false);

  int get adherencePercent {
    final List<Reminder> daily = reminders
        .where((Reminder r) => r.kind != ReminderKind.appointment)
        .toList(growable: false);
    if (daily.isEmpty) return 0;
    return ((daily.where((Reminder r) => r.done).length / daily.length) * 100).round();
  }

  /// Mean accuracy over [days], or null when nothing was played.
  double? averageAccuracy({int days = 14}) {
    final List<GameSession> window = recent(days: days);
    if (window.isEmpty) return null;
    return window.fold<double>(0, (double a, GameSession s) => a + s.performance.accuracy) /
        window.length;
  }

  /// Mean accuracy per activity, for spotting a domain that is slipping.
  Map<GameId, double> accuracyByGame({int days = 14}) {
    final Map<GameId, List<double>> buckets = <GameId, List<double>>{};
    for (final GameSession s in recent(days: days)) {
      buckets.putIfAbsent(s.gameId, () => <double>[]).add(s.performance.accuracy);
    }
    return <GameId, double>{
      for (final MapEntry<GameId, List<double>> e in buckets.entries)
        e.key: e.value.reduce((double a, double b) => a + b) / e.value.length,
    };
  }

  /// Positive when the recent half of the window scored better than the older
  /// half. Null when there is not enough history to say anything.
  double? accuracyTrend({int days = 14}) {
    final List<GameSession> window = recent(days: days);
    if (window.length < 4) return null;
    final int half = window.length ~/ 2;
    // `sessions` is newest first, so the first half is the *recent* half.
    final double newer = window
            .take(half)
            .fold<double>(0, (double a, GameSession s) => a + s.performance.accuracy) /
        half;
    final double older = window
            .skip(half)
            .fold<double>(0, (double a, GameSession s) => a + s.performance.accuracy) /
        (window.length - half);
    return newer - older;
  }

  /// Activities not played in the window — a gap worth closing.
  List<GameId> get untouchedActivities {
    final Set<GameId> played = recent().map((GameSession s) => s.gameId).toSet();
    return GameId.values.where((GameId g) => !played.contains(g)).toList(growable: false);
  }

  int levelOf(GameId id) => levels[id] ?? 1;

  /// A short clock label matching the one `AppState` writes into sessions.
  String get clockLabel {
    final int h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$h:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  String get partOfDay {
    if (now.hour < 12) return 'morning';
    if (now.hour < 17) return 'afternoon';
    return 'evening';
  }

  /// The context as the model sees it.
  ///
  /// Compact on purpose — a smaller prompt is cheaper, faster and leaks less.
  /// Set [redacted] to replace the patient's name with a placeholder, for
  /// deployments that must not send identifying data to a model provider.
  /// The onboarding answers, trimmed to what a question generator needs.
  ///
  /// Deliberately not the whole record: raw symptom scores invite a model to
  /// comment on severity, and nothing in this app is allowed to do that. What
  /// goes out is context for warmth, not material for a verdict.
  static Map<String, dynamic> _intakeJson(IntakeRecord intake, {required bool redacted}) {
    return <String, dynamic>{
      'completedBy': intake.completedBy?.name,
      'concerns': intake.reason.concerns
          .map((PresentingConcern c) => c.label)
          .toList(growable: false),
      'onset': intake.reason.onset?.label,
      'everydayIndependencePercent': intake.function.independencePercent,
      'stillDoesUnaided': <String>[
        for (final FunctionalItem item in FunctionCatalogue.items)
          if ((intake.function.levels[item.id] ?? FunctionLevel.independent) ==
              FunctionLevel.independent)
            item.label,
      ],
      'needsSomeHelpWith': <String>[
        for (final FunctionalItem item in intake.function.needingHelp) item.label,
      ],
      'sleepQuality': intake.medical.sleepQuality?.name,
      'sleepHours': intake.medical.sleepHours,
      'lowMood': intake.medical.lowMood?.name,
      if (!redacted) 'hasCaregiver': intake.caregiver != null,
    };
  }

  Map<String, dynamic> toPromptJson({bool redacted = false, int days = 14}) {
    final String name = redacted ? 'the patient' : patient.shortName;
    final Map<GameId, double> byGame = accuracyByGame(days: days);
    final double? trend = accuracyTrend(days: days);

    return <String, dynamic>{
      'patient': <String, dynamic>{
        'name': name,
        'age': patient.age,
        'language': patient.language,
        if (!redacted) ...<String, dynamic>{
          'location': patient.location,
          'occupation': patient.occupation,
          'favouriteActivity': patient.favouriteActivity,
          'favouriteFood': patient.favouriteFood,
          'family': <Map<String, String>>[
            for (final FamilyMember f in patient.family)
              <String, String>{'name': f.name, 'relation': f.relation},
          ],
        },
        'stageNote': patient.stageNote,
      },
      'replyLanguage': replyLanguage ?? patient.language,
      if (intake != null) 'onboarding': _intakeJson(intake!, redacted: redacted),
      'today': <String, dynamic>{
        'partOfDay': partOfDay,
        'time': clockLabel,
        'mood': mood?.name,
        'engagement': engagementToday,
        'activitiesCompleted':
            completedToday.map((GameId g) => g.name).toList(growable: false),
        'remindersDue': <Map<String, String>>[
          for (final Reminder r in dueReminders)
            <String, String>{'time': r.time, 'title': r.title, 'kind': r.kind.name},
        ],
        'remindersDone': doneReminders.map((Reminder r) => r.title).toList(growable: false),
        'adherencePercent': adherencePercent,
        'journal': <Map<String, dynamic>>[
          for (final JournalEntry e in journal)
            <String, dynamic>{'about': e.label, 'answer': e.answer, 'positive': e.positive},
        ],
        'routine': <Map<String, String>>[
          for (final RoutineItem r in patient.routine)
            <String, String>{'time': r.time, 'title': r.title},
        ],
      },
      'performance': <String, dynamic>{
        'windowDays': days,
        'sessionCount': recent(days: days).length,
        'averageAccuracy': averageAccuracy(days: days)?.round(),
        'accuracyTrend': trend == null
            ? 'not enough history'
            : trend > 3
                ? 'improving'
                : trend < -3
                    ? 'declining'
                    : 'steady',
        'byActivity': <String, dynamic>{
          for (final MapEntry<GameId, double> e in byGame.entries)
            e.key.name: <String, dynamic>{
              'accuracy': e.value.round(),
              'level': levelOf(e.key),
              'domain': _domainOf(e.key)?.name,
              'levelMeaning': AdaptiveDifficultyService.levelDescription(e.key, levelOf(e.key)),
            },
        },
        'notPlayedRecently':
            untouchedActivities.map((GameId g) => g.name).toList(growable: false),
        'recentSessions': <Map<String, dynamic>>[
          for (final GameSession s in recent(days: days).take(12))
            <String, dynamic>{
              'activity': s.gameId.name,
              'daysAgo': s.dayOffset,
              'level': s.level,
              'accuracy': s.performance.accuracy.round(),
              'focus': s.performance.focus.round(),
              'memory': s.performance.memory.round(),
              'hints': s.performance.hintsUsed,
              'mistakes': s.performance.mistakes,
              'seconds': s.performance.seconds,
              'expectedSeconds':
                  AdaptiveDifficultyService.expectedSeconds(s.gameId, s.level),
              'completed': s.performance.completed,
            },
        ],
      },
      'cognitiveDomains': <String, int>{
        for (final MapEntry<CognitiveDomain, int> e in cognitiveProfile.scores.entries)
          e.key.name: e.value,
      },
      'overallScore': cognitiveProfile.overall,
      'conversation': <String, dynamic>{
        'recentTurns': <Map<String, String>>[
          for (final ConversationTurn t in recentTurns)
            <String, String>{'from': t.fromUser ? 'patient' : 'Saathi', 'text': t.text},
        ],
        'moodCheckIn': <String, dynamic>{
          'active': moodCheckInActive,
          'turnNumber': moodCheckInTurn,
        },
      },
      'memoryCompanion': <String, dynamic>{
        'totalSharedMemories': totalSharedMemories,
        'invitesRemainingToday': memoryInvitesRemainingToday,
        'resurfaceCandidate': memoryResurfaceCandidate == null || redacted
            ? null
            : <String, dynamic>{
                'category': memoryResurfaceCandidate!.category.name,
                'summary': memoryResurfaceCandidate!.summary,
                'mentionedName': memoryResurfaceCandidate!.mentionedName,
                'timesResurfacedBefore': memoryResurfaceCandidate!.timesResurfaced,
              },
        // Everything shared before, not just today's candidate — see the
        // field doc on `knownMemories` for why. Gated by `redacted` the same
        // way `patient.family` is above: this is exactly the kind of
        // personally-identifying content that flag exists to strip.
        'sharedMemories': redacted
            ? const <Map<String, dynamic>>[]
            : <Map<String, dynamic>>[
                for (final MemoryFragment f in knownMemories)
                  <String, dynamic>{
                    'category': f.category.name,
                    'summary': f.summary,
                    'mentionedName': f.mentionedName,
                    'daysAgo': now.difference(f.createdAt).inDays,
                  },
              ],
      },
    };
  }

  /// The domain an activity exercises, from the one canonical map in
  /// `models/game.dart`. This used to be a second copy here, and the copy
  /// disagreed — it filed the attention activity under memory.
  ///
  /// `null` for an activity with no cognitive-domain claim at all (Mood
  /// Canvas) — in practice this is never actually reached for it, since it
  /// never appears in a scored session that these callers iterate.
  static CognitiveDomain? _domainOf(GameId id) => GameDomains.of(id);

  static CognitiveDomain? domainOf(GameId id) => _domainOf(id);
}
