import 'dart:ui';

import '../../l10n/app_localizations.dart';
import '../models/assessment.dart';
import '../models/daily.dart';
import '../models/game.dart';
import '../models/patient.dart';
import '../services/adaptive_difficulty_service.dart';
import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_service.dart';

/// The AI layer with no network.
///
/// This is not a placeholder. Most of this app's users are on intermittent
/// rural connections, so the offline answer is the one they will see most
/// often, and it has to be genuinely useful rather than an apology. It reads
/// the same signals the prompt sends to Gemini — accuracy, trend, hints,
/// mistakes, pace, domain scores, mood, adherence — and reaches a conclusion
/// from them directly.
///
/// It is also the safety net: every failure mode of the remote service ends
/// up here, so the caregiver always gets *something* defensible.
class OnDeviceAiService implements AiService {
  const OnDeviceAiService();

  @override
  bool get isAvailable => true;

  @override
  void dispose() {}

  // ── Today's questions ──────────────────────────────────────────────────

  @override
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext context) async =>
      AiSuccess<List<DailyQuestion>>(buildDailyQuestions(context));

  /// Personal questions with no network.
  ///
  /// Built from the same onboarding answers the prompt would send: the person's
  /// name, work, family, what they still do unaided and what they came worried
  /// about. Every question is answerable in one tap and none of them tests
  /// anybody — a daily question that feels like an exam gets avoided, and an
  /// avoided question measures nothing.
  ///
  /// Synchronous so the remote service can reuse it as a fallback body.
  List<DailyQuestion> buildDailyQuestions(PatientAiContext context) {
    final AppLocalizations l = AppLocalizations(Locale(context.replyLanguage ?? 'en'));
    final Patient p = context.patient;
    final String name = p.shortName.isEmpty ? l.aiFriend : p.shortName;
    final IntakeRecord? intake = context.intake;
    final List<DailyQuestion> questions = <DailyQuestion>[];

    questions.add(DailyQuestion(
      id: 'ai_sleep',
      text: context.partOfDay == 'morning'
          ? l.aiMorning(name)
          : l.aiRestQuestion(name),
      journalLabel: l.aiRestLabel,
      options: <QuestionOption>[
        QuestionOption(
            label: l.aiRestWell, emoji: '😊', response: l.aiRestWellReply),
        QuestionOption(
            label: l.aiRestSoSo, emoji: '😐', response: l.aiRestSoSoReply),
        QuestionOption(
            label: l.aiRestPoorly,
            emoji: '😔',
            positive: false,
            response: l.aiRestPoorlyReply),
      ],
    ));

    // Someone's work is the richest thing the profile holds: it is decades of
    // practised skill, and asking about it is a question they can win.
    if (p.occupation.trim().isNotEmpty) {
      questions.add(DailyQuestion(
        id: 'ai_work',
        text: l.aiWorkQuestion(p.occupation.toLowerCase()),
        journalLabel: l.aiWorkLabel,
        options: <QuestionOption>[
          QuestionOption(
              label: l.aiWorkYes, emoji: '💭', response: l.aiWorkYesReply),
          QuestionOption(
              label: l.aiWorkSometimes, emoji: '🙂', response: l.aiWorkSometimesReply),
          QuestionOption(
              label: l.aiWorkNotLately, emoji: '🌾', response: l.aiWorkNotLatelyReply),
        ],
      ));
    }

    if (p.family.isNotEmpty) {
      final FamilyMember member = p.family.first;
      questions.add(DailyQuestion(
        id: 'ai_family',
        text: l.aiFamilyQuestion(member.name),
        journalLabel: l.aiFamilyLabel,
        sceneId: member.sceneId,
        options: <QuestionOption>[
          QuestionOption(
              label: l.aiFamilyYes, emoji: '📞', response: l.aiFamilyYesReply),
          QuestionOption(
              label: l.aiFamilyNotYet, emoji: '🕐', response: l.aiFamilyNotYetReply),
          QuestionOption(
              label: l.aiFamilyRemindMe,
              emoji: '💛',
              positive: false,
              response: l.aiFamilyRemindMeReply(member.name)),
        ],
      ));
    }

    // What they still do unaided, asked as a strength rather than a check.
    final String? kept = intake == null
        ? null
        : <String?>[
            for (final FunctionalItem item in FunctionCatalogue.items)
              if ((intake.function.levels[item.id] ?? FunctionLevel.independent) ==
                  FunctionLevel.independent)
                item.label,
          ].whereType<String>().firstOrNull;
    if (kept != null) {
      questions.add(DailyQuestion(
        id: 'ai_function',
        text: l.aiFunctionQuestion(kept.toLowerCase()),
        journalLabel: l.aiFunctionLabel,
        options: <QuestionOption>[
          QuestionOption(
              label: l.aiFunctionYes, emoji: '👍', response: l.aiFunctionYesReply),
          QuestionOption(
              label: l.aiFunctionHelp, emoji: '🤝', response: l.aiFunctionHelpReply),
          QuestionOption(
              label: l.aiFunctionNotToday, emoji: '🌤️', response: l.aiFunctionNotTodayReply),
        ],
      ));
    }

    return questions;
  }

  // ── Cognitive insight ──────────────────────────────────────────────────

  @override
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext context) async =>
      AiSuccess<CognitiveInsight>(buildInsight(context));

  /// Synchronous so the remote service can reuse it as a fallback body.
  CognitiveInsight buildInsight(PatientAiContext context) {
    final AppLocalizations l = AppLocalizations(Locale(context.replyLanguage ?? 'en'));
    final double? average = context.averageAccuracy();
    final double? trend = context.accuracyTrend();
    final Map<GameId, double> byGame = context.accuracyByGame();
    final String name = context.patient.shortName;

    // ── summary ─────────────────────────────────────────────────────────
    final List<String> summary = <String>[];
    if (average == null) {
      summary.add(l.aiInsightNoActivity(name));
    } else {
      final int sessions = context.recent().length;
      summary.add(l.aiInsightActivityCount(
        name,
        sessions.toString(),
        sessions == 1 ? l.aiActivitySingular : l.aiActivityPlural,
        average.round().toString(),
      ));
      if (trend != null) {
        summary.add(switch (trend) {
          > 3 => l.aiInsightTrendStronger,
          < -3 => l.aiInsightTrendWeaker,
          _ => l.aiInsightTrendSteady,
        });
      }
      if (context.mood != null) {
        final String pronoun = l.aiInsightPronounShe;
        summary.add(l.aiInsightMood(pronoun, context.mood!.label.toLowerCase()));
      }
    }

    // ── strengths ───────────────────────────────────────────────────────
    final List<String> strengths = <String>[];
    final List<MapEntry<GameId, double>> ranked = byGame.entries.toList()
      ..sort((MapEntry<GameId, double> a, MapEntry<GameId, double> b) =>
          b.value.compareTo(a.value));

    if (ranked.isNotEmpty && ranked.first.value >= 70) {
      final MapEntry<GameId, double> best = ranked.first;
      final String pronoun = l.aiInsightPronounHer;
      strengths.add(l.aiInsightStrongestActivity(
        _activityName(best.key, l),
        pronoun,
        best.value.round().toString(),
        PatientAiContext.domainOf(best.key)?.label.toLowerCase() ?? '',
      ));
    }
    final List<GameSession> unaided = context
        .recent()
        .where((GameSession s) => s.performance.hintsUsed == 0 && s.performance.completed)
        .toList(growable: false);
    if (unaided.isNotEmpty) {
      strengths.add(l.aiInsightUnaidedSessions(
        unaided.length.toString(),
        context.recent().length.toString(),
      ));
    }
    if (context.adherencePercent >= 80 && context.reminders.isNotEmpty) {
      strengths.add(l.aiInsightReminders(context.adherencePercent.toString()));
    }
    final MapEntry<CognitiveDomain, int>? topDomain = _extremeDomain(context, best: true);
    if (topDomain != null && strengths.length < 3) {
      final int matches = context.cognitiveProfile.scores.values
          .where((int s) => s == topDomain.value)
          .length;
      if (matches == 1) {
        strengths.add(l.aiInsightTopDomain(topDomain.key.label, topDomain.value.toString()));
      } else if (matches == 2) {
        final CognitiveDomain other = context.cognitiveProfile.scores.entries
            .firstWhere((MapEntry<CognitiveDomain, int> e) =>
                e.value == topDomain.value && e.key != topDomain.key)
            .key;
        strengths.add(l.aiInsightTopDomainTied(
          topDomain.key.label,
          topDomain.value.toString(),
          other.label.toLowerCase(),
        ));
      } else {
        strengths.add(l.aiInsightTopDomainMultiple(topDomain.key.label, topDomain.value.toString()));
      }
    }
    if (strengths.isEmpty) {
      strengths.add(l.aiInsightEngaging);
    }

    // ── areas needing attention ─────────────────────────────────────────
    final List<String> attention = <String>[];
    if (ranked.isNotEmpty && ranked.last.value < 60) {
      final MapEntry<GameId, double> worst = ranked.last;
      final String pronoun = l.aiInsightPronounShe;
      attention.add(l.aiInsightLowestActivity(
        _activityName(worst.key, l),
        worst.value.round().toString(),
        pronoun,
      ));
    }
    final List<GameSession> abandoned = context
        .recent()
        .where((GameSession s) => !s.performance.completed)
        .toList(growable: false);
    if (abandoned.isNotEmpty) {
      attention.add(l.aiInsightAbandoned(
        abandoned.length.toString(),
        abandoned.length == 1 ? l.aiInsightAbandonedSingular : l.aiInsightAbandonedPlural,
      ));
    }
    final List<GameSession> slow = context.recent().where((GameSession s) {
      final int expected =
          AdaptiveDifficultyService.expectedSeconds(s.gameId, s.level);
      return s.performance.seconds > expected * 1.5;
    }).toList(growable: false);
    if (slow.isNotEmpty && attention.length < 3) {
      attention.add(l.aiInsightSlow(
        slow.length.toString(),
        slow.length == 1 ? l.aiInsightSlowSingular : l.aiInsightSlowPlural,
      ));
    }
    if (context.untouchedActivities.isNotEmpty && attention.length < 3) {
      final List<String> names = context.untouchedActivities
          .take(2)
          .map((GameId g) => _activityName(g, l))
          .toList(growable: false);
      attention.add(l.aiInsightNotPlayed(
        names.join(' and '),
        names.length == 1 ? l.aiInsightNotPlayedSingular : l.aiInsightNotPlayedPlural,
      ));
    }
    if (trend != null && trend < -3 && attention.length < 3) {
      attention.add(l.aiInsightDownwardTrend);
    }
    if (attention.isEmpty) {
      attention.add(l.aiInsightNoAttention);
    }

    // ── recommendation ──────────────────────────────────────────────────
    final (GameId activity, String why) = _recommend(context, byGame);
    final int level = context.levelOf(activity);

    return CognitiveInsight(
      summary: summary.join(' '),
      strengths: strengths,
      attentionAreas: attention,
      recommendedActivity: activity,
      recommendedDifficulty: level,
      reason: why,
      evidence: _evidence(context, average, trend, activity, level),
      source: AiSource.onDevice,
      generatedAt: context.now,
    );
  }

  /// Prefer an activity that has not been done today, weakest domain first —
  /// but never one she is failing badly, which would be discouraging.
  (GameId, String) _recommend(PatientAiContext context, Map<GameId, double> byGame) {
    final AppLocalizations l = AppLocalizations(Locale(context.replyLanguage ?? 'en'));
    final List<GameId> untouched = context.untouchedActivities
        .where((GameId g) =>
            !context.completedToday.contains(g) &&
            g != context.lastPlayed &&
            PatientAiContext.domainOf(g) != null)
        .toList(growable: false);
    if (untouched.isNotEmpty) {
      final GameId pick = untouched.first;
      return (
        pick,
        '${_activityName(pick, l)} has not been played in the last two weeks, so it '
            'exercises ${(PatientAiContext.domainOf(pick)?.label ?? 'thinking').toLowerCase()} work that '
            'nothing else has covered recently.'
      );
    }

    final List<MapEntry<GameId, double>> candidates = byGame.entries
        .where((MapEntry<GameId, double> e) =>
            !context.completedToday.contains(e.key) && e.key != context.lastPlayed)
        .toList()
      ..sort((MapEntry<GameId, double> a, MapEntry<GameId, double> b) =>
          a.value.compareTo(b.value));

    // Something in the 45–75% band is the useful kind of hard: challenging
    // without being disheartening.
    for (final MapEntry<GameId, double> e in candidates) {
      if (e.value >= 45 && e.value <= 75) {
        return (
          e.key,
          '${_activityName(e.key, l)} sits at ${e.value.round()}%, enough room to '
              'improve without being discouraging, which is where practice helps most.'
        );
      }
    }
    if (candidates.isNotEmpty) {
      final MapEntry<GameId, double> pick = candidates.first;
      return (
        pick.key,
        '${_activityName(pick.key, l)} is the weakest recent activity at '
            '${pick.value.round()}%, so it is where attention is most useful.'
      );
    }

    return (
      GameId.memoryCards,
      'Everything else has been done today. NER Memory Cards is a gentle way to '
          'finish without adding pressure.'
    );
  }

  List<String> _evidence(
    PatientAiContext context,
    double? average,
    double? trend,
    GameId activity,
    int level,
  ) {
    return <String>[
      if (average != null)
        'Average accuracy ${average.round()}% across ${context.recent().length} sessions',
      if (trend != null)
        'Trend ${trend > 0 ? '+' : ''}${trend.round()} points, recent half vs earlier half',
      if (context.mood != null) 'Mood today: ${context.mood!.label}',
      'Adherence today ${context.adherencePercent}%',
      'Overall domain score ${context.cognitiveProfile.overall}',
      'Level $level: ${AdaptiveDifficultyService.levelDescription(activity, level)}',
    ];
  }

  MapEntry<CognitiveDomain, int>? _extremeDomain(PatientAiContext c, {required bool best}) {
    if (c.cognitiveProfile.scores.isEmpty) return null;
    final List<MapEntry<CognitiveDomain, int>> e =
        c.cognitiveProfile.scores.entries.toList()
          ..sort((MapEntry<CognitiveDomain, int> a, MapEntry<CognitiveDomain, int> b) =>
              best ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    return e.first;
  }

  // ── Memory assistant ───────────────────────────────────────────────────

  @override
  Future<AiResult<AssistantReply>> ask(String question, PatientAiContext context) async =>
      AiSuccess<AssistantReply>(buildReply(question, context));

  /// Answers from the context alone. Every branch is grounded in a fact the
  /// app actually holds — nothing here can invent a reminder or a relative.
  ///
  /// Synchronous, and also called directly by [LlamaOnDeviceAiService] to
  /// build its deterministic fallback/structure — so the `moodCheckInActive`
  /// branch has to live here rather than in [ask], or that wrapper would
  /// bypass it entirely and never see `moodCheckInDone`/`moodLevel`.
  AssistantReply buildReply(String question, PatientAiContext context) {
    // Checked before classify(): a check-in answer like "tired" or "fine"
    // would otherwise be read as ordinary companionship small talk, and the
    // screen needs the moodCheckInDone/moodLevel signal this branch alone
    // produces.
    if (context.moodCheckInActive) return _moodCheckInReply(question, context);

    final AssistantIntent intent = classify(question);
    return switch (intent) {
      AssistantIntent.schedule => _scheduleReply(context),
      AssistantIntent.activity => _activityReply(context),
      AssistantIntent.reminders => _remindersReply(context),
      AssistantIntent.people => _peopleReply(question, context),
      AssistantIntent.orientation => _orientationReply(context),
      AssistantIntent.companionship => _companionshipReply(context),
      // classify() never produces either of these — the life-story companion
      // turn needs a real model to judge when it fits naturally, and a mood
      // check-in reply is only ever reached through `ask()`'s dedicated
      // branch above, never through keyword classification. Reached only if
      // something upstream ever passes one of these intents through
      // directly.
      AssistantIntent.memoryMoment => _companionshipReply(context),
      AssistantIntent.moodCheckIn => _companionshipReply(context),
      AssistantIntent.outOfScope => _outOfScopeReply(context),
    };
  }

  /// A small, fixed decision tree standing in for the model's free-form
  /// follow-up questions — this runs with no network and no model at all, so
  /// it has to reach a sensible next question from keywords alone. English
  /// only today, same caveat as every other on-device reply in this class.
  static const List<String> _lowWords = <String>[
    'sad', 'low', 'down', 'upset', 'crying', 'cry', 'unhappy', 'depress'
  ];
  static const List<String> _lonelyWords = <String>['lonely', 'alone', 'miss'];
  static const List<String> _worriedWords = <String>[
    'worried', 'anxious', 'scared', 'afraid', 'nervous', 'fear'
  ];
  static const List<String> _angryWords = <String>[
    'angry', 'frustrated', 'annoyed', 'irritated', 'mad'
  ];
  static const List<String> _tiredWords = <String>['tired', 'exhausted', 'sleepy', 'weak'];
  static const List<String> _goodWords = <String>[
    'good', 'fine', 'happy', 'great', 'well', 'okay', 'ok', 'nice', 'lovely'
  ];

  AssistantReply _moodCheckInReply(String answer, PatientAiContext context) {
    final String a = ' ${answer.toLowerCase().trim()} ';
    bool has(List<String> words) => words.any(a.contains);

    final (MoodLevel level, String followUp) = has(_lonelyWords)
        ? (
            MoodLevel.low,
            'That sounds hard to sit with. Have you been able to talk to '
                'anyone today?'
          )
        : has(_lowWords)
            ? (
                MoodLevel.low,
                "I'm glad you told me. Is it something on your mind, or more "
                    'that today has just felt heavy?'
              )
            : has(_worriedWords)
                ? (MoodLevel.low, "What's on your mind? I'm listening.")
                : has(_angryWords)
                    ? (
                        MoodLevel.okay,
                        'That is understandable. Did something happen that '
                            'frustrated you?'
                      )
                    : has(_tiredWords)
                        ? (
                            MoodLevel.okay,
                            'Rest matters. Has sleep been alright for you '
                                'lately?'
                          )
                        : has(_goodWords)
                            ? (
                                MoodLevel.good,
                                "That's lovely to hear. What's made today good "
                                    'so far?'
                              )
                            : (MoodLevel.okay, 'Tell me a little more about that.');

    // Two follow-ups then a close, matching the Gemini prompt's own pacing
    // (wrap up once turnNumber reaches 2, i.e. this is the third answer).
    if (context.moodCheckInTurn >= 2) {
      return AssistantReply(
        text: 'Thank you for telling me how you feel. I am here whenever you '
            'want to talk more, about anything at all.',
        intent: AssistantIntent.moodCheckIn,
        source: AiSource.onDevice,
        moodCheckInDone: true,
        moodLevel: level,
      );
    }

    return AssistantReply(
      text: followUp,
      intent: AssistantIntent.moodCheckIn,
      source: AiSource.onDevice,
    );
  }

  /// Keyword intent matching.
  ///
  /// Crude by design: it runs on-device with no model, and a wrong guess costs
  /// only a slightly-off answer that still comes from real context. English
  /// only today — the language work is a later phase.
  static AssistantIntent classify(String raw) {
    // Trimmed and padded with single spaces so a *word* match (' hi ') can't
    // miss a bare "hi" the way a raw `.contains('hi ')` would — that exact
    // bug once sent a plain "hi" straight to the out-of-scope fallback.
    final String q = ' ${raw.toLowerCase().trim()} ';
    bool has(List<String> words) => words.any(q.contains);

    if (has(<String>['remind', 'medicine', 'medication', 'tablet', 'pill', 'water', 'drink'])) {
      return AssistantIntent.reminders;
    }
    if (has(<String>['what should i do', 'activity', 'game', 'play', 'exercise', 'practice'])) {
      return AssistantIntent.activity;
    }
    if (has(<String>['today', 'schedule', 'plan', 'routine', 'happening', 'my day'])) {
      return AssistantIntent.schedule;
    }
    if (has(<String>['who is', 'who are', 'my daughter', 'my son', 'my husband',
        'my wife', 'family', 'grandchild'])) {
      return AssistantIntent.people;
    }
    if (has(<String>['where am i', 'what day', 'what time', 'what year', 'where do i live'])) {
      return AssistantIntent.orientation;
    }
    if (has(<String>[' hi ', ' hi,', ' hi!', 'hello', 'how are you', 'thank you',
        'good morning', 'good evening', 'lonely', 'scared', 'sad'])) {
      return AssistantIntent.companionship;
    }
    return AssistantIntent.outOfScope;
  }

  AssistantReply _scheduleReply(PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    final List<Reminder> due = c.dueReminders;
    final StringBuffer b = StringBuffer();
    if (due.isEmpty) {
      b.write(l.aiScheduleAllDone + ' ');
    } else {
      final Reminder next = due.first;
      b.write(l.aiScheduleNext(next.title.toLowerCase(), next.time) + ' ');
      if (due.length > 1) {
        b.write('There ${due.length == 2 ? 'is' : 'are'} ${due.length - 1} more after that. ');
      }
    }
    if (c.completedToday.isEmpty) {
      b.write(l.aiScheduleNoActivity);
    } else {
      b.write('You have already done ${c.completedToday.length} '
          '${c.completedToday.length == 1 ? 'activity' : 'activities'} today. Well done.');
    }
    return AssistantReply(
      text: b.toString().trim(),
      intent: AssistantIntent.schedule,
      source: AiSource.onDevice,
      followUps: <String>[l.aiScheduleFollowUpActivity, l.aiScheduleFollowUpReminders],
    );
  }

  AssistantReply _activityReply(PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    final CognitiveInsight insight = buildInsight(c);
    final GameId pick = insight.recommendedActivity;
    return AssistantReply(
      text: l.aiActivityTry(_activityName(pick, l), _activityInvitation(pick, c.patient, l)),
      intent: AssistantIntent.activity,
      source: AiSource.onDevice,
      suggestedActivity: pick,
      followUps: <String>[l.aiScheduleFollowUpToday, l.aiScheduleFollowUpLater],
    );
  }

  AssistantReply _remindersReply(PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    final List<Reminder> due = c.dueReminders;
    if (due.isEmpty) {
      return AssistantReply(
        text: c.reminders.isEmpty
            ? l.aiRemindersNothingToday
            : l.aiRemindersAllDone,
        intent: AssistantIntent.reminders,
        source: AiSource.onDevice,
        followUps: <String>[l.aiScheduleFollowUpActivity],
      );
    }
    final List<String> lines = due
        .take(3)
        .map((Reminder r) => '${r.title.toLowerCase()} at ${r.time}')
        .toList(growable: false);
    return AssistantReply(
      text: l.aiRemindersStillHave(_join(lines, l)),
      intent: AssistantIntent.reminders,
      source: AiSource.onDevice,
      followUps: <String>[l.aiScheduleFollowUpToday, l.aiScheduleFollowUpActivity],
    );
  }

  AssistantReply _peopleReply(String question, PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    final String q = question.toLowerCase();
    for (final FamilyMember f in c.patient.family) {
      if (q.contains(f.name.toLowerCase()) || q.contains(f.relation.toLowerCase())) {
        return AssistantReply(
          text: '${f.name} is your ${f.relation.toLowerCase()}.'
              '${f.note.isEmpty ? '' : ' ${f.note}'}',
          intent: AssistantIntent.people,
          source: AiSource.onDevice,
          followUps: const <String>['What do I have today?'],
        );
      }
    }
    if (c.patient.family.isEmpty) {
      return _outOfScopeReply(c);
    }
    final String names = _join(
        c.patient.family.map((FamilyMember f) => '${f.name}, your ${f.relation.toLowerCase()}')
            .toList(growable: false), l);
    return AssistantReply(
      text: l.aiPeopleFamilyHere(names),
      intent: AssistantIntent.people,
      source: AiSource.onDevice,
      followUps: const <String>['What do I have today?'],
    );
  }

  AssistantReply _orientationReply(PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    return AssistantReply(
      text: l.aiOrientationTime(c.clockLabel, c.partOfDay, c.patient.location.isEmpty ? '' : l.aiOrientationLocation(c.patient.location)),
      intent: AssistantIntent.orientation,
      source: AiSource.onDevice,
      followUps: const <String>['What do I have today?', 'What are my reminders?'],
    );
  }

  AssistantReply _companionshipReply(PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    final String opener = switch (c.mood) {
      MoodLevel.low => l.aiCompanionshipLow,
      MoodLevel.okay => l.aiCompanionshipOkay,
      MoodLevel.good => l.aiCompanionshipGood,
      null => l.aiCompanionshipGood,
    };
    return AssistantReply(
      text: l.aiCompanionshipOffer(opener),
      intent: AssistantIntent.companionship,
      source: AiSource.onDevice,
      followUps: <String>[l.aiScheduleFollowUpToday, l.aiScheduleFollowUpActivity],
    );
  }

  /// The guardrail. Anything the app does not know is declined warmly and the
  /// patient is steered back to something it *can* answer — never a guess.
  AssistantReply _outOfScopeReply(PatientAiContext c) {
    final AppLocalizations l = AppLocalizations(Locale(c.replyLanguage ?? 'en'));
    return AssistantReply(
      text: l.aiOutOfScope,
      intent: AssistantIntent.outOfScope,
      source: AiSource.onDevice,
      followUps: <String>[
        l.aiScheduleFollowUpToday,
        l.aiScheduleFollowUpReminders,
        l.aiScheduleFollowUpActivity,
      ],
    );
  }

  static String _join(List<String> parts, AppLocalizations l) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return l.aiJoinAnd(parts.sublist(0, parts.length - 1).join(', '), parts.last);
  }

  static String _activityName(GameId id, AppLocalizations l) => switch (id) {
        GameId.procedure => l.aiGameProcedure,
        GameId.story => l.aiGameStory,
        GameId.familiarPlace => l.aiGameFamiliarPlace,
        GameId.melody => l.aiGameMelody,
        GameId.weaves => l.aiGameWeaves,
        GameId.memoryCards => l.aiGameMemoryCards,
        GameId.villageMarket => l.gameVillageMarketName,
        GameId.moodCanvas => l.gameMoodCanvasName,
      };

  static String _activityInvitation(GameId id, Patient p, AppLocalizations l) => switch (id) {
        GameId.procedure => l.aiGameProcedureInvitation,
        GameId.story => l.aiGameStoryInvitation,
        GameId.familiarPlace => l.aiGameFamiliarPlaceInvitation,
        GameId.melody => l.aiGameMelodyInvitation,
        GameId.weaves => l.aiGameWeavesInvitation,
        GameId.memoryCards => l.aiGameMemoryCardsInvitation,
        // No dedicated aiGame*Invitation key exists for these two yet — each
        // game's own intro-screen companion message already says exactly
        // this ("shall we see what we can find?" / "let's draw and talk"),
        // so reusing it here beats inventing a near-duplicate string.
        GameId.villageMarket => l.gameVillageMarketIntroMessage,
        GameId.moodCanvas => l.gameMoodCanvasInstructions,
      };
}
