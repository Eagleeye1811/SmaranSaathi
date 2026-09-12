import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/local/sync_operation.dart';
import '../../data/mock/demo_journey.dart';
import '../../data/mock/mock_data.dart';
import '../../data/repositories/repositories.dart';
import '../models/assessment.dart';
import '../models/onboarding.dart';
import '../models/clinical.dart';
import '../models/daily.dart';
import '../models/game.dart';
import '../models/memory_fragment.dart';
import '../models/monitoring.dart';
import '../models/mood_drawing.dart';
import '../models/patient.dart';
import '../models/report.dart';
import '../models/safety.dart';
import '../models/settings.dart';
import 'adaptive_difficulty_service.dart';
import 'cognitive_monitoring_service.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';
import 'personalization_service.dart';
import 'sync_manager.dart';

export '../models/settings.dart' show AppSettings, TextSizePreference, TextSizePreferenceX;

enum AppRole { none, patient, caregiver, doctor }

/// The single source of truth for the running app.
///
/// Holds the personalised profile, session history, journal, reminders,
/// accessibility preferences and connectivity state, and keeps every role's
/// screens consistent with one another — a game finished in the patient app
/// immediately changes the caregiver dashboard and the clinician trend.
///
/// **Persistence model.** Every field below is an in-memory read model, so all
/// getters stay synchronous and no screen ever awaits. Each mutation writes
/// through to a repository and, in the same call, records an entry in the sync
/// outbox. Construct with [AppState.new] for a throwaway in-memory session
/// (tests, the pure demo) or with the Hive repositories plus [hydrate] for a
/// build that survives restart.
class AppState extends ChangeNotifier {
  AppState({
    PatientRepository? patients,
    GameRepository? games,
    AnalyticsRepository? analytics,
    ReminderRepository? reminders,
    DailyRepository? daily,
    AssessmentRepository? assessment,
    MemoryFragmentRepository? memories,
    MoodDrawingRepository? moodDrawings,
    SettingsRepository? settings,
    SyncRepository? sync,
    ConnectivityService? connectivity,
    SyncTransport? transport,
  })  : _patients = patients ?? MockPatientRepository(),
        _games = games ?? MockGameRepository(),
        _analytics = analytics ?? MockAnalyticsRepository(),
        _reminderRepo = reminders ?? MockReminderRepository(),
        _daily = daily ?? MockDailyRepository(),
        _assessment = assessment ?? MockAssessmentRepository(),
        _memories = memories ?? MockMemoryFragmentRepository(),
        _moodDrawingRepo = moodDrawings ?? MockMoodDrawingRepository(),
        _settingsRepo = settings ?? MockSettingsRepository(),
        _connectivity = OverridableConnectivityService(
            connectivity ?? ManualConnectivityService()) {
    _sync = SyncManager(
      repository: sync ?? MockSyncRepository(),
      connectivity: _connectivity,
      transport: transport ?? const LoopbackTransport(),
    )..addListener(notifyListeners);
  }

  final PatientRepository _patients;
  final GameRepository _games;
  final AnalyticsRepository _analytics;
  final ReminderRepository _reminderRepo;
  final DailyRepository _daily;
  final AssessmentRepository _assessment;
  final MemoryFragmentRepository _memories;
  final MoodDrawingRepository _moodDrawingRepo;
  final SettingsRepository _settingsRepo;
  final OverridableConnectivityService _connectivity;
  late final SyncManager _sync;

  static const AdaptiveDifficultyService adaptive = AdaptiveDifficultyService();
  static const PersonalizationService personalization = PersonalizationService();
  static const CognitiveMonitoringService monitor = CognitiveMonitoringService();

  SyncManager get syncManager => _sync;

  // ── Write serialisation ────────────────────────────────────────────────
  //
  // Mutations are synchronous for the UI and asynchronous underneath. Writes
  // are chained rather than fired in parallel so two rapid taps can never
  // interleave into the same box, and `flush` lets tests await the disk.
  Future<void> _writes = Future<void>.value();

  Future<void> _write(Future<void> Function() operation) {
    _writes = _writes.then((_) => operation()).catchError(
      (Object error, StackTrace stack) {
        // A failed local write must never take the app down: the user keeps
        // working against the in-memory model and the next write retries.
        debugPrint('AppState: local write failed ($error)');
      },
    );
    return _writes;
  }

  /// Awaits every queued write, including any sync drain those writes kicked
  /// off. Call before asserting on disk contents or closing the boxes.
  Future<void> flush() async {
    await _writes;
    await _sync.settled;
    // A drain can itself queue follow-up writes; one more pass settles them.
    await _writes;
  }

  // ── Session ────────────────────────────────────────────────────────────
  AppRole _role = AppRole.none;
  AppRole get role => _role;

  bool _profileReady = true;
  bool get profileReady => _profileReady;

  /// The person the app is about.
  ///
  /// Blank until a caregiver has actually answered the onboarding. It used to
  /// start as a fully-populated sample patient, which meant a fresh install
  /// showed someone else's name, family and memories until it happened to be
  /// overwritten — and worse, made it impossible to tell a real profile from
  /// the sample one. Empty is honest; [profileReady] says which state we are
  /// in and every screen is expected to handle it.
  Patient _patient = MockData.emptyPatient;
  Patient get patient => _patient;

  /// True once the onboarding has produced a real person to show.
  bool get hasPatientProfile => _patient.name.trim().isNotEmpty;

  /// The caregiver filling this in — their own name and relation, taken from
  /// the onboarding rather than from a hardcoded stand-in.
  String get caregiverName => _intake.onboarding.caregiverName.trim();

  HelperRole? get caregiverRelation => _intake.onboarding.helper;

  bool get hasCaregiverProfile => caregiverName.isNotEmpty;

  List<Patient> get caregiverPatients =>
      hasPatientProfile ? <Patient>[_patient] : const <Patient>[];

  void setPatient(Patient p) {
    _patient = p;
    notifyListeners();
  }

  /// Draft used by the caregiver onboarding flow.
  Patient _draft = MockData.emptyPatient;
  Patient get draft => _draft;

  bool _hydrated = false;

  /// True once [hydrate] has finished restoring a persisted session.
  bool get hydrated => _hydrated;

  void setRole(AppRole r) {
    _role = r;
    _persistSettings();
    notifyListeners();
  }

  void updateDraft(Patient p) {
    _draft = p;
    notifyListeners();
  }

  void resetDraft() {
    _draft = MockData.emptyPatient;
    notifyListeners();
  }

  /// Finishes onboarding: the draft becomes the live personalised profile.
  Future<void> commitDraft() async {
    final Patient p = _draft;
    // Whatever the caregiver actually entered, and nothing else. Backfilling
    // the sample family, memories and routine here is what used to make a
    // brand-new profile come pre-loaded with a stranger's relatives.
    _patient = p;
    _profileReady = true;
    notifyListeners();
    await _write(() async {
      await _patients.save(_patient);
      await _sync.enqueue(SyncOperationKind.profileUpdate, <String, dynamic>{
        'patientId': _patient.id,
        'name': _patient.name,
      });
    });
  }

  /// Updates the patient's phone number for real-time SMS notifications.
  void updatePatientPhoneNumber(String phoneNumber) {
    _patient = _patient.copyWith(phoneNumber: phoneNumber);
    notifyListeners();
    _write(() async {
      await _patients.save(_patient);
      await _sync.enqueue(SyncOperationKind.profileUpdate, <String, dynamic>{
        'patientId': _patient.id,
        'name': _patient.name,
        'phoneNumber': phoneNumber,
      });
    });
  }

  // ── Hydration ──────────────────────────────────────────────────────────

  /// Restores a previous session from local storage.
  ///
  /// Safe to call when nothing has been stored yet — the seeded demo profile
  /// and history are written on first run so a fresh install still opens onto
  /// a populated app rather than an empty one.
  Future<void> hydrate() async {
    final AppSettings settings = await _settingsRepo.load();
    _textSize = settings.textSize;
    _highContrast = settings.highContrast;
    _reduceMotion = settings.reduceMotion;
    _voicePrompts = settings.voicePrompts;
    _localeCode = settings.localeCode;
    _connectivity.forcedOffline = settings.offlineOverride;
    _safeZone = SafeZone.decode(settings.safeZoneJson);

    // The role the device was last used as. Persisted but never restored
    // until now, so every returning user was sent back to the role picker.
    _role = _roleFromName(settings.lastRole);

    // The account first: everything below is scoped to it.
    _accountId = settings.lastAccountId;

    final Patient? stored = _accountId == null
        ? await _patients.current()
        : await _patients.byId(_patientIdFor(_accountId!)) ?? await _patients.current();
    if (stored != null) {
      _patient = stored;
    } else {
      await _patients.save(_patient);
    }

    await _loadPatientScopedData();

    // The structured intake and the personal baseline, for whichever account
    // this device last worked on.
    _intake = await _assessment.intake(_assessmentScope) ?? IntakeRecord.empty;
    _baseline = await _assessment.baseline(_assessmentScope);
    _memoryFragments = await _memories.all(_assessmentScope);

    if (_seedDemo && _intake.completedAtIso == null) {
      await loadDemoJourney();
    }

    await _sync.load();
    _hydrated = true;
    notifyListeners();
  }

  /// Loads everything keyed by the current patient id.
  ///
  /// Split out of [hydrate] because signing in and out has to redo exactly
  /// this: levels, history, reminders and today's conversation all belong to
  /// one person, and switching accounts without reloading them would show the
  /// previous person's day to whoever signed in next.
  Future<void> _loadPatientScopedData() async {
    final Map<GameId, int> levels = await _games.levels(_patient.id);
    _levels
      ..clear()
      ..addAll(MockData.startingLevels);
    if (levels.isEmpty) {
      for (final MapEntry<GameId, int> e in MockData.startingLevels.entries) {
        await _games.saveLevel(_patient.id, e.key, e.value);
      }
    } else {
      _levels.addAll(levels);
    }

    final List<GameSession> history = await _games.history(_patient.id);
    _sessions.clear();
    if (history.isEmpty) {
      // Only a demo build writes the sample fortnight. A real install starts
      // with nothing, and every number on the dashboard stays blank until the
      // person has actually played something.
      if (_seedDemo) {
        _sessions.addAll(MockData.history());
        for (final GameSession s in _sessions) {
          await _games.recordSession(_patient.id, s);
        }
      }
    } else {
      _sessions.addAll(history);
    }

    // Computed from the sessions just loaded rather than read back, so the
    // scores on screen always correspond to activities that were really
    // played by this person.
    _profile = _profileFromSessions();

    // Reminders: the schedule is authored, the done flags are the user's.
    await _reminderRepo.seedIfEmpty(MockData.reminders());
    final List<Reminder> storedReminders = await _reminderRepo.today(_patient.id);
    _reminders
      ..clear()
      ..addAll(storedReminders.isEmpty ? MockData.reminders() : storedReminders);

    // Today's conversation.
    final DailySnapshot snapshot = await _daily.load(_patient.id);
    _mood = snapshot.mood;
    _journal
      ..clear()
      ..addAll(snapshot.journal);
    _answered
      ..clear()
      ..addAll(snapshot.answeredQuestions);
    _journeyDone
      ..clear()
      ..addAll(snapshot.journeyDone);
    _todayEngagement = snapshot.engagement;
    _completedToday.clear();
    for (final String name in snapshot.completedGameIds) {
      for (final GameId id in GameId.values) {
        if (id.name == name) _completedToday.add(id);
      }
    }

    _moodDrawings
      ..clear()
      ..addAll(await _moodDrawingRepo.all(_patient.id));
  }

  /// The local profile id an account's data is filed under.
  static String _patientIdFor(String uid) => 'acct_$uid';

  static AppRole _roleFromName(String? name) {
    for (final AppRole role in AppRole.values) {
      if (role.name == name) return role;
    }
    return AppRole.none;
  }

  // ── Games ──────────────────────────────────────────────────────────────
  final Map<GameId, int> _levels = Map<GameId, int>.from(MockData.startingLevels);
  Map<GameId, int> get levels => Map<GameId, int>.unmodifiable(_levels);
  int levelOf(GameId id) => _levels[id] ?? 1;

  // Empty on a real install. A dashboard that shows a fortnight of scores to
  // someone who has not played anything is not a demo aid, it is a lie about
  // that person's own record — so the sample history is now reachable only
  // through `MM_DEMO` or the explicit "Load demonstration history" action.
  final List<GameSession> _sessions =
      _seedDemo ? MockData.history() : <GameSession>[];
  List<GameSession> get sessions => List<GameSession>.unmodifiable(_sessions);

  final Set<GameId> _completedToday = <GameId>{};
  Set<GameId> get completedToday => Set<GameId>.unmodifiable(_completedToday);

  // Mood Canvas drawings — never a GameSession, see MoodDrawing's doc comment.
  final List<MoodDrawing> _moodDrawings = <MoodDrawing>[];
  List<MoodDrawing> get moodDrawings => List<MoodDrawing>.unmodifiable(_moodDrawings);

  AdaptiveDecision? _lastDecision;
  AdaptiveDecision? get lastDecision => _lastDecision;

  GameId? _lastPlayed;
  GameId? get lastPlayed => _lastPlayed;

  // Empty until the person has played something. The authored profile is a
  // demo fixture, and showing it to a real user would put six invented domain
  // scores on their own record.
  CognitiveProfile _profile = _seedDemo
      ? MockData.aamaProfile()
      : const CognitiveProfile(
          scores: <CognitiveDomain, int>{},
          overall: 0,
          updated: 'No activities yet',
        );
  CognitiveProfile get cognitiveProfile => _profile;

  /// The domain profile implied by the sessions actually recorded.
  ///
  /// Derived, never stored-and-trusted: a profile read back from disk can
  /// outlive the sessions it was computed from (a reset, a demo load, a
  /// different account), and a stale score is worse than none.
  CognitiveProfile _profileFromSessions() {
    if (_sessions.isEmpty) {
      return const CognitiveProfile(
        scores: <CognitiveDomain, int>{},
        overall: 0,
        updated: 'No activities yet',
      );
    }
    final Map<CognitiveDomain, double> current = monitor.domainScores(_sessions);
    return CognitiveProfile(
      scores: <CognitiveDomain, int>{
        for (final MapEntry<CognitiveDomain, double> e in current.entries)
          e.key: e.value.round(),
      },
      overall: current.isEmpty
          ? 0
          : (current.values.reduce((double a, double b) => a + b) / current.length).round(),
      updated: 'From your ${_sessions.length} '
          '${_sessions.length == 1 ? 'activity' : 'activities'}',
    );
  }

  /// Records a finished play-through and lets it ripple through every role.
  ///
  /// The result is in memory before this returns and on disk shortly after —
  /// the write is queued, not awaited, so the result screen never waits on IO.
  AdaptiveDecision finishGame(GameId id, GamePerformance p) {
    final int level = levelOf(id);
    final AdaptiveDecision decision =
        adaptive.evaluate(gameId: id, currentLevel: level, performance: p);

    final GameSession session = GameSession(
      gameId: id,
      dayOffset: 0,
      level: level,
      performance: p,
      timeLabel: _clockLabel(),
    );
    _sessions.insert(0, session);

    _levels[id] = decision.nextLevel;
    _completedToday.add(id);
    _lastDecision = decision;
    _lastPlayed = id;
    _journeyDone.add('game');

    // Recomputed from every session on record rather than nudged by a delta.
    // A nudged score drifts away from the sessions it claims to summarise —
    // and after a restart, where it is derived again, it would silently
    // change. Same input, same number, always.
    _profile = _profileFromSessions();

    _todayEngagement = math.min(99, _todayEngagement + math.max(2, (p.overall / 22).round()));
    _lastActiveMinutes = 0;

    final CognitiveProfile profileToSave = _profile;
    final int engagementToSave = _todayEngagement;
    _write(() async {
      await _games.recordSession(_patient.id, session);
      await _games.saveLevel(_patient.id, id, decision.nextLevel);
      await _analytics.saveProfile(_patient.id, profileToSave);
      await _daily.markGameCompleted(_patient.id, id);
      await _daily.markJourneyStep(_patient.id, 'game');
      await _daily.saveEngagement(_patient.id, engagementToSave);
      await _sync.enqueue(SyncOperationKind.gameSession, <String, dynamic>{
        'patientId': _patient.id,
        'gameId': id.name,
        'level': level,
        'nextLevel': decision.nextLevel,
        'accuracy': p.accuracy,
        'focus': p.focus,
        'memory': p.memory,
        'hintsUsed': p.hintsUsed,
        'mistakes': p.mistakes,
        'seconds': p.seconds,
        'completed': p.completed,
        'overall': p.overall,
        'attempts': p.attempts,
        'correct': p.correct,
        'responseMillis': p.responseMillis,
        'timeLabel': session.timeLabel,
      });
    });

    notifyListeners();
    return decision;
  }

  /// Saves a finished Mood Check-In: the drawing, and the short guided
  /// conversation that followed it (empty if the patient closed out before
  /// the check-in phase produced one — see `MoodCheckInScreen`).
  ///
  /// Deliberately parallel to, not built on, [finishGame]: there is no
  /// `AdaptiveDifficultyService.evaluate()` call and no `GameSession` here —
  /// neither free drawing nor a feelings conversation has a score to adapt
  /// against. `completedToday` still gets the entry it needs for the app's
  /// "done today" tracking, via the same `_daily` completion marker
  /// `finishGame` itself uses.
  ///
  /// When the conversation produced a [moodLevel], this also calls
  /// [setMood] — the same signal the quick `MoodPicker` on the health
  /// dashboard sets — so a real conversation about how the patient feels
  /// updates the one mood reading the rest of the app (the companionship
  /// opener, the caregiver insight) already reads, rather than being
  /// stranded in this feature alone.
  Future<MoodDrawing> saveMoodDrawing(
    Uint8List png, {
    List<MoodCheckInTurn> transcript = const <MoodCheckInTurn>[],
    MoodLevel? moodLevel,
  }) {
    final MoodDrawing drawing = MoodDrawing(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      dayOffset: 0,
      timeLabel: _clockLabel(),
      pngBytes: png,
      transcript: transcript,
      moodLevel: moodLevel,
    );
    _moodDrawings.insert(0, drawing);
    _completedToday.add(GameId.moodCanvas);
    _lastActiveMinutes = 0;
    notifyListeners();
    if (moodLevel != null) setMood(moodLevel);
    return _write(() async {
      await _moodDrawingRepo.add(_patient.id, drawing);
      await _daily.markGameCompleted(_patient.id, GameId.moodCanvas);
      await _sync.enqueue(SyncOperationKind.moodDrawingSaved, <String, dynamic>{
        'patientId': _patient.id,
        'drawingId': drawing.id,
        'at': drawing.timeLabel,
      });
    }).then((_) => drawing);
  }

  /// A doctor's own freeform note about a drawing — never generated
  /// automatically. `notedBy` is [MockData.doctorName], the same stand-in
  /// clinician identity every other doctor screen in this prototype uses.
  void addDoctorNoteToDrawing(String drawingId, String note, {required String notedBy}) {
    final int i = _moodDrawings.indexWhere((MoodDrawing d) => d.id == drawingId);
    if (i < 0) return;
    final String notedAt = DateTime.now().toIso8601String();
    _moodDrawings[i] =
        _moodDrawings[i].copyWith(doctorNote: note, notedBy: notedBy, notedAtIso: notedAt);
    notifyListeners();
    _write(() async {
      await _moodDrawingRepo.addDoctorNote(_patient.id, drawingId, note,
          notedBy: notedBy, notedAtIso: notedAt);
      await _sync.enqueue(SyncOperationKind.doctorNoteAdded, <String, dynamic>{
        'patientId': _patient.id,
        'drawingId': drawingId,
        'notedBy': notedBy,
        'at': notedAt,
      });
    });
  }

  String _clockLabel() {
    final DateTime now = DateTime.now();
    final int h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final String m = now.minute.toString().padLeft(2, '0');
    return '$h:$m ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  List<GameSession> sessionsFor(GameId id) =>
      _sessions.where((GameSession s) => s.gameId == id).toList(growable: false);

  double averageAccuracy() {
    if (_sessions.isEmpty) return 0;
    final double sum =
        _sessions.fold(0, (double a, GameSession s) => a + s.performance.accuracy);
    return sum / _sessions.length;
  }

  int gamesCompletedTotal() => _sessions.length;

  // ── Assessment, baseline and monitoring ───────────────────────────────
  //
  // The intake is what turns activity scores into a health profile: why the
  // person came, what they and their caregiver notice, how daily life is
  // affected, and what else could explain a change. Every step writes through
  // immediately, so a questionnaire abandoned half way is never lost.

  /// Set with `--dart-define=MM_DEMO=true` to open onto the twelve-week
  /// demonstration history instead of an empty profile.
  static const bool _seedDemo = bool.fromEnvironment('MM_DEMO');

  /// The signed-in Firebase uid, or null when nobody has signed in on this
  /// device. Everything the person *answers* is filed under it.
  String? _accountId;
  String? get accountId => _accountId;

  /// Where the assessment is stored and re-read from.
  ///
  /// Falls back to the patient id so the app works exactly as before with no
  /// sign-in at all — the auth layer stays optional, which is what lets the
  /// whole journey run offline and on a device with no Firebase config.
  String get _assessmentScope => _accountId ?? _patient.id;

  IntakeRecord _intake = IntakeRecord.empty;
  IntakeRecord get intake => _intake;

  CognitiveBaseline? _baseline;
  CognitiveBaseline? get baseline => _baseline;

  /// True once the person has consented, answered every questionnaire and
  /// completed the baseline run.
  bool get intakeComplete => _intake.isComplete && _baseline != null;

  // ── Memory companion ───────────────────────────────────────────────────
  //
  // Every real life-story the patient has shared with Saathi, across every
  // session — the substance behind "remembers what she told me last week".
  // Saved from a genuine personal story only, never from a quiz answer; see
  // `core/ai/gemini_ai_service.dart`'s system prompt for the rule that keeps
  // it that way. Also what furnishes the Memory Home (`features/patient/
  // memory_home/`): each fragment decorates the room matching its category.

  List<MemoryFragment> _memoryFragments = <MemoryFragment>[];
  List<MemoryFragment> get memoryFragments => List.unmodifiable(_memoryFragments);

  /// At most two memory turns (a new story, or an old one gently reoffered)
  /// per day — the pacing the product asks for. Counts anything touched
  /// today, so a resurfacing counts the same as a fresh share.
  static const int _dailyMemoryBudget = 2;

  int get memoryInvitesRemainingToday {
    final DateTime today = DateTime.now();
    final int touchedToday =
        _memoryFragments.where((MemoryFragment f) => f.wasTouchedOn(today)).length;
    return (_dailyMemoryBudget - touchedToday).clamp(0, _dailyMemoryBudget);
  }

  /// The best fragment to gently reoffer today, or null when there is
  /// nothing to resurface (no memories yet, or today's budget is spent).
  /// Prefers whatever has gone longest without being revisited, and never
  /// picks something created today — a memory should sit for at least a day
  /// before it comes back as an offer.
  MemoryFragment? get memoryResurfaceCandidate {
    if (memoryInvitesRemainingToday <= 0) return null;
    final DateTime today = DateTime.now();
    final List<MemoryFragment> eligible = _memoryFragments
        .where((MemoryFragment f) => !f.wasCreatedOn(today))
        .toList(growable: false)
      ..sort((MemoryFragment a, MemoryFragment b) {
        final DateTime aTime = a.lastResurfacedAt ?? a.createdAt;
        final DateTime bTime = b.lastResurfacedAt ?? b.createdAt;
        return aTime.compareTo(bTime);
      });
    return eligible.isEmpty ? null : eligible.first;
  }

  /// How many memories furnish each room of the Memory Home.
  Map<MemoryCategory, int> get memoriesByCategory {
    final Map<MemoryCategory, int> counts = <MemoryCategory, int>{
      for (final MemoryCategory c in MemoryCategory.values) c: 0,
    };
    for (final MemoryFragment f in _memoryFragments) {
      counts[f.category] = (counts[f.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Turns a story the AI noticed in conversation into a persisted fragment.
  /// Local-only for now — not part of the sync outbox — so this works fully
  /// offline; syncing it to the caregiver/doctor view is a natural next step
  /// once there is a Firestore shape for it.
  Future<MemoryFragment> saveSharedMemory(SharedMemory shared) {
    final MemoryFragment fragment = MemoryFragment(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      category: shared.category,
      summary: shared.summary,
      mentionedName: shared.mentionedName,
      createdAt: DateTime.now(),
    );
    _memoryFragments = <MemoryFragment>[..._memoryFragments, fragment];
    notifyListeners();
    return _write(() => _memories.add(_assessmentScope, fragment)).then((_) => fragment);
  }

  /// Records that Saathi just offered [fragmentId] back to the patient, so it
  /// moves to the back of the resurfacing queue.
  Future<void> markMemoryResurfaced(String fragmentId) {
    final DateTime now = DateTime.now();
    final int i = _memoryFragments.indexWhere((MemoryFragment f) => f.id == fragmentId);
    if (i < 0) return Future<void>.value();
    _memoryFragments = <MemoryFragment>[..._memoryFragments]
      ..[i] = _memoryFragments[i].copyWith(
        lastResurfacedAt: now,
        timesResurfaced: _memoryFragments[i].timesResurfaced + 1,
      );
    notifyListeners();
    return _write(() => _memories.markResurfaced(_assessmentScope, fragmentId, now));
  }

  /// Where "Continue" resumes the intake.
  IntakeStep get nextIntakeStep => _intake.nextStep;

  /// The longitudinal picture — recomputed from the session history rather
  /// than cached, so a figure on the dashboard can never drift out of step
  /// with the sessions behind it.
  MonitoringSnapshot get monitoring => monitor.snapshot(
        sessions: _sessions,
        baseline: _baseline,
        intake: _intake,
      );

  /// The clinician-ready summary. Built from the same objects the screens
  /// read, so what is shared is exactly what was shown.
  ClinicalReport buildReport({DateTime? now}) => ClinicalReport.build(
        patient: _patient,
        intake: _intake,
        snapshot: monitoring,
        now: now ?? DateTime.now(),
      );

  /// Activities still to play in the baseline run, in catalogue order.
  ///
  /// Derived from [baselinePlan] itself, not `GameId.values` — an activity
  /// that isn't part of the baseline at all (Mood Canvas has no clinical
  /// baseline measure to capture) must never count as "remaining", or the
  /// baseline could never be marked complete.
  List<GameId> get baselineRemaining => baselinePlan
      .expand((List<GameId> day) => day)
      .where((GameId g) => !_intake.baselineActivities.contains(g.name))
      .toList(growable: false);

  bool get baselineRunComplete => baselineRemaining.isEmpty;

  // ── The three-day baseline plan ─────────────────────────────────────────
  //
  // Six activities, two a day, three days, then a fourth day for Village
  // Market alone — it's the newest activity and stands fine on its own, so
  // the original three paired days are left untouched. Paired so each
  // sitting covers two different domains rather than two of the same, which
  // keeps a single bad day from landing entirely on one part of the profile.
  static const List<List<GameId>> baselinePlan = <List<GameId>>[
    <GameId>[GameId.memoryCards, GameId.story],
    <GameId>[GameId.familiarPlace, GameId.melody],
    <GameId>[GameId.weaves, GameId.procedure],
    <GameId>[GameId.villageMarket],
  ];

  static String _dayKey(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  /// 0-based index of the day being worked on, 3 once every activity is done.
  int get baselineDayIndex {
    for (int day = 0; day < baselinePlan.length; day++) {
      final bool done = baselinePlan[day]
          .every((GameId g) => _intake.baselineActivities.contains(g.name));
      if (!done) return day;
    }
    return baselinePlan.length;
  }

  /// The activities for the current day, in order, unfinished ones first.
  List<GameId> get baselineToday {
    final int day = baselineDayIndex;
    if (day >= baselinePlan.length) return const <GameId>[];
    return baselinePlan[day];
  }

  List<GameId> get baselineTodayRemaining => baselineToday
      .where((GameId g) => !_intake.baselineActivities.contains(g.name))
      .toList(growable: false);

  /// True once the profile exists — the baseline is frozen and monitoring has
  /// something to compare against.
  bool get baselineReady => _baseline != null;

  /// A demo override for the one-day-at-a-time rule. Real use waits for
  /// tomorrow; a fifteen-minute demonstration cannot, so the screen offers an
  /// explicit "I have time now" that sets this for the session.
  bool _baselineDayUnlocked = false;
  void unlockNextBaselineDay() {
    _baselineDayUnlocked = true;
    notifyListeners();
  }

  /// Whether today's session can be started right now.
  ///
  /// Blocked only when the previous day's pair was finished *today* — spacing
  /// is the point of the plan — and never when the day is half done.
  bool canStartBaselineSession({DateTime? now}) {
    if (baselineDayIndex >= baselinePlan.length) return false;
    if (_baselineDayUnlocked) return true;
    if (baselineTodayRemaining.length < baselineToday.length) return true;
    return !_intake.baselineSessionDates.contains(_dayKey(now ?? DateTime.now()));
  }

  void _saveIntake(IntakeRecord next, {Map<String, dynamic>? syncPayload}) {
    // Stamp the record with the account that answered it, so the answers can
    // always be attributed even after the file is copied or synced.
    _intake = _accountId == null ? next : next.copyWith(accountId: _accountId);
    notifyListeners();
    _write(() async {
      await _assessment.saveIntake(_assessmentScope, next);
      if (syncPayload != null) {
        await _sync.enqueue(SyncOperationKind.assessmentUpdate, <String, dynamic>{
          'patientId': _patient.id,
          if (_accountId != null) 'accountId': _accountId,
          ...syncPayload,
        });
      }
    });
  }

  void giveConsent() {
    final DateTime now = DateTime.now();
    _saveIntake(
      _intake.copyWith(
        consent: ConsentRecord(understood: true, atIso: now.toIso8601String()),
        startedAtIso: _intake.startedAtIso.isEmpty ? now.toIso8601String() : null,
      ),
      syncPayload: <String, dynamic>{'step': 'consent', 'at': now.toIso8601String()},
    );
  }

  /// The profile step.
  ///
  /// The identifying details live on [Patient] — including the profession,
  /// which is not just a report line: [PersonalizationService] reads it to
  /// choose the procedures and stories the activities are built from.
  void saveIntakeProfile({
    required String name,
    required int age,
    required String language,
    String? occupation,
    CompletedBy? completedBy,
  }) {
    _patient = _patient.copyWith(
      name: name.trim().isEmpty ? _patient.name : name.trim(),
      shortName: name.trim().isEmpty ? _patient.shortName : name.trim().split(' ').first,
      age: age,
      language: language,
      occupation: (occupation ?? '').trim().isEmpty ? _patient.occupation : occupation!.trim(),
    );
    final Patient saved = _patient;
    _saveIntake(
      _intake.copyWith(completedBy: completedBy),
      syncPayload: <String, dynamic>{'step': 'profile'},
    );
    _write(() async {
      await _patients.save(saved);
      await _sync.enqueue(SyncOperationKind.profileUpdate, <String, dynamic>{
        'patientId': saved.id,
        'name': saved.name,
      });
    });
  }

  /// Files one screen's worth of onboarding answers.
  ///
  /// Every onboarding screen calls this and nothing else: [IntakeRecord
  /// .withOnboarding] re-derives the symptom, function, medical, reason and
  /// caregiver structures from the answers each time, so a screen cannot
  /// forget to update the things that read from it.
  void saveOnboarding(OnboardingRecord next) {
    final IntakeRecord updated = _intake.withOnboarding(
      next,
      // The report attributes observations to the relation, which the helper
      // question already gives us; a separate "and what is your name" question
      // would buy nothing the record does not already have.
      caregiverName: '',
    );
    _saveIntake(
      updated,
      syncPayload: <String, dynamic>{'step': 'onboarding', ...next.toJson()},
    );
  }

  void saveReason(ReasonForVisit reason) => _saveIntake(
        _intake.copyWith(reason: reason),
        syncPayload: <String, dynamic>{'step': 'reason', ...reason.toJson()},
      );

  void saveSafetyCheck(SafetyCheck safety) => _saveIntake(
        _intake.copyWith(safety: safety),
        syncPayload: <String, dynamic>{'step': 'safety', ...safety.toJson()},
      );

  void answerSymptom(String itemId, SymptomFrequency frequency) => _saveIntake(
        _intake.copyWith(symptoms: _intake.symptoms.withResponse(itemId, frequency)),
      );

  void saveSymptoms(SymptomAssessment symptoms) => _saveIntake(
        _intake.copyWith(symptoms: symptoms),
        syncPayload: <String, dynamic>{'step': 'symptoms', ...symptoms.toJson()},
      );

  void setFunctionLevel(String itemId, FunctionLevel level) => _saveIntake(
        _intake.copyWith(function: _intake.function.withLevel(itemId, level)),
      );

  void saveFunction(FunctionalAssessment function) => _saveIntake(
        _intake.copyWith(function: function),
        syncPayload: <String, dynamic>{'step': 'function', ...function.toJson()},
      );

  void saveMedicalHistory(MedicalHistory medical) => _saveIntake(
        _intake.copyWith(medical: medical),
        syncPayload: <String, dynamic>{'step': 'medical', ...medical.toJson()},
      );

  void saveCaregiverObservation(CaregiverObservation observation) => _saveIntake(
        _intake.copyWith(caregiver: observation),
        syncPayload: <String, dynamic>{'step': 'caregiver', ...observation.toJson()},
      );

  /// Records one activity of the baseline run. Called on the result screen, so
  /// an interrupted baseline resumes rather than restarting.
  void markBaselineActivity(GameId id, {DateTime? now}) {
    if (_intake.baselineActivities.contains(id.name)) return;
    final Set<String> activities = <String>{..._intake.baselineActivities, id.name};
    // Stamp the day when the pair for that day is finished, so the next
    // session waits for tomorrow rather than for the next tap.
    final bool dayFinished = baselinePlan.any((List<GameId> pair) =>
        pair.contains(id) && pair.every((GameId g) => activities.contains(g.name)));
    _saveIntake(_intake.copyWith(
      baselineActivities: activities,
      baselineSessionDates: dayFinished
          ? <String>{..._intake.baselineSessionDates, _dayKey(now ?? DateTime.now())}
          : null,
    ));
  }

  /// Closes the questionnaire without freezing a baseline.
  ///
  /// The two used to happen together, which meant a person could not reach
  /// their own home screen until all six activities were done in one sitting.
  /// The questionnaire is finished here; the baseline is built three days
  /// later, from the sessions played from the dashboard.
  /// Builds the patient's profile out of the onboarding answers.
  ///
  /// The person screen already saved name, age, language and occupation as
  /// they were typed. This fills in the rest from answers given elsewhere in
  /// the questionnaire, so that finishing the onboarding produces a profile
  /// rather than a half-filled shell:
  ///
  ///  - what they still enjoy becomes the favourite activity the companion
  ///    opens conversations with,
  ///  - a reported diagnosis becomes the stage note a clinician reads first.
  ///
  /// Nothing is invented. A field the questionnaire never asked about is left
  /// empty, because a plausible guess in a health record is worse than a gap.
  Patient _patientFromOnboarding(Patient base, DateTime at) {
    final OnboardingRecord o = _intake.onboarding;

    final String favourite = o.enjoys.isEmpty
        ? base.favouriteActivity
        : o.enjoys.first.reportLabel;

    final String stage = switch (o.diagnosisStatus) {
      DiagnosisStatus.yes => o.diagnosedConditions.isEmpty
          ? 'Diagnosed condition reported'
          : 'Reported diagnosis: ${o.diagnosedConditions.first.name}',
      DiagnosisStatus.no => 'No diagnosis reported',
      DiagnosisStatus.notSure || null => 'Being monitored, no diagnosis reported',
    };

    return base.copyWith(
      favouriteActivity: favourite,
      stageNote: stage,
      joinedOn: 'Profile created ${at.day}/${at.month}/${at.year}',
    );
  }

  void completeIntakeQuestionnaire({DateTime? now}) {
    if (_intake.completedAtIso != null) return;
    final DateTime at = now ?? DateTime.now();

    // The profile is created here, at the end, rather than screen by screen:
    // a half-answered questionnaire should not leave a half-real person on
    // the caregiver's dashboard.
    _patient = _patientFromOnboarding(_patient, at);
    _profileReady = true;
    final Patient created = _patient;
    _write(() async {
      await _patients.save(created);
      await _sync.enqueue(SyncOperationKind.profileUpdate, <String, dynamic>{
        'patientId': created.id,
        'name': created.name,
      });
    });

    _saveIntake(
      _intake.copyWith(completedAtIso: at.toIso8601String()),
      // The whole record, not just the last step: this is the snapshot the
      // backend files under the account, and it is the one a clinician's
      // report is later built from.
      syncPayload: <String, dynamic>{
        'step': 'intakeCompleted',
        'at': at.toIso8601String(),
        'intake': _intake.copyWith(completedAtIso: at.toIso8601String()).toJson(),
      },
    );
  }

  /// Closes the intake and freezes the personal baseline.
  ///
  /// The baseline is computed from the person's *earliest* sessions in each
  /// domain, which is exactly what the baseline run just produced. Everything
  /// afterwards is reported as a deviation from it.
  Future<void> captureBaseline({DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    // From the sessions just played, not the oldest in the box. A fresh
    // install seeds a fortnight of sample history so the charts are not blank,
    // and baselining against that would mean the person's own assessment never
    // reached their own baseline.
    final CognitiveBaseline captured = monitor.buildBaseline(
      _sessions,
      at: at,
      perDomain: 1,
      fromEarliest: false,
    );
    _baseline = captured;
    _intake = _intake.copyWith(
      completedAtIso: _intake.completedAtIso ?? at.toIso8601String(),
      baselineActivities: <String>{for (final GameId g in GameId.values) g.name},
    );
    notifyListeners();
    final IntakeRecord record = _intake;
    await _write(() async {
      await _assessment.saveBaseline(_assessmentScope, captured);
      await _assessment.saveIntake(_assessmentScope, record);
      await _sync.enqueue(SyncOperationKind.baselineCaptured, <String, dynamic>{
        'patientId': _patient.id,
        if (_accountId != null) 'accountId': _accountId,
        ...captured.toJson(),
      });
    });
  }

  /// Loads the twelve-week demonstration history — a complete monitoring
  /// record that would otherwise take twelve weeks to produce. Replaces any
  /// existing history, so it is offered explicitly rather than run silently.
  Future<void> loadDemoJourney({DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final List<GameSession> demo = DemoJourney.sessions();

    _sessions
      ..clear()
      ..addAll(demo);
    _intake = DemoJourney.intake(now: at);
    _baseline = monitor.buildBaseline(demo, at: at.subtract(const Duration(days: DemoJourney.weeks * 7)));

    // Keep the legacy domain profile in step, so the caregiver and clinician
    // screens built on it show the same person as the new ones.
    final Map<CognitiveDomain, double> current = monitor.domainScores(demo);
    _profile = CognitiveProfile(
      scores: <CognitiveDomain, int>{
        for (final MapEntry<CognitiveDomain, double> e in current.entries)
          e.key: e.value.round(),
      },
      overall: current.isEmpty
          ? _profile.overall
          : (current.values.reduce((double a, double b) => a + b) / current.length).round(),
      updated: 'Updated just now',
    );

    for (final GameId id in GameId.values) {
      _levels[id] = 2;
    }

    final IntakeRecord record = _intake;
    final CognitiveBaseline? captured = _baseline;
    final CognitiveProfile profile = _profile;
    notifyListeners();

    await _write(() async {
      for (final GameSession session in demo.reversed) {
        await _games.recordSession(_patient.id, session);
      }
      for (final GameId id in GameId.values) {
        await _games.saveLevel(_patient.id, id, 2);
      }
      await _analytics.saveProfile(_patient.id, profile);
      await _assessment.saveIntake(_assessmentScope, record);
      if (captured != null) await _assessment.saveBaseline(_assessmentScope, captured);
    });
  }

  /// Binds this device's assessment to a signed-in account.
  ///
  /// Called once sign-in returns a uid, before the intake starts. Two things
  /// happen: the storage scope moves to the uid, and whatever that account
  /// already answered is loaded — so signing in on a second device continues
  /// the questionnaire rather than restarting it, and signing in as someone
  /// else on a shared device does not inherit the previous person's answers.
  /// Binds the app to a signed-in account and loads everything that belongs
  /// to it: the profile, the questionnaire, the baseline, the activity history
  /// and today's conversation.
  ///
  /// Called from the sign-in screen and again at every launch for an account
  /// Firebase has already restored — which is what stops a returning person
  /// from being asked to do the onboarding twice.
  Future<void> signInAccount(String uid) async {
    if (_accountId == uid) return;
    // Only answers given *anonymously* can be adopted. Switching from one
    // account to another must never carry the first person's answers across.
    final bool wasAnonymous = _accountId == null;
    final Patient anonymous = _patient;
    _accountId = uid;

    final IntakeRecord? stored = await _assessment.intake(uid);
    final CognitiveBaseline? baseline = await _assessment.baseline(uid);
    final Patient? storedPatient = await _patients.byId(_patientIdFor(uid));
    final List<MemoryFragment> storedMemories = await _memories.all(uid);

    // A first sign-in adopts anything already answered anonymously on this
    // device rather than throwing it away — someone who started the
    // questionnaire and only then created an account keeps their progress.
    final bool adopting = wasAnonymous && stored == null && _intake.consentGiven;

    if (adopting) {
      final IntakeRecord adopted = _intake.copyWith(accountId: uid);
      _intake = adopted;
      _patient = anonymous.copyWith(id: _patientIdFor(uid));
      final Patient owned = _patient;
      final CognitiveBaseline? keep = _baseline;
      await _write(() async {
        await _patients.save(owned);
        await _assessment.saveIntake(uid, adopted);
        if (keep != null) await _assessment.saveBaseline(uid, keep);
        // Re-file the answers under the account remotely too. Without this the
        // record exists on the phone under the new uid but the backend still
        // holds it against the anonymous device id.
        await _sync.enqueue(SyncOperationKind.assessmentUpdate, <String, dynamic>{
          'patientId': owned.id,
          'accountId': uid,
          'step': 'accountLinked',
          'intake': adopted.toJson(),
          if (keep != null) 'baseline': keep.toJson(),
        });
        if (_baseline != null) await _assessment.saveBaseline(uid, _baseline!);
        for (final MemoryFragment f in _memoryFragments) {
          await _memories.add(uid, f);
        }
      });
    } else {
      _intake = stored ?? IntakeRecord.empty;
      _baseline = baseline;
      // A returning account gets its own profile back; a brand-new one starts
      // from the blank template rather than inheriting the last person's name.
      _patient = storedPatient ??
          MockData.emptyPatient.copyWith(id: _patientIdFor(uid));
      if (storedPatient == null) {
        // Brand-new account on this device: the role belongs to the person,
        // not to the phone, so it is asked once rather than inherited from
        // whoever used it last.
        if (stored == null) _role = AppRole.none;
        final Patient fresh = _patient;
        await _write(() async => _patients.save(fresh));
      }
      await _loadPatientScopedData();
      _memoryFragments = storedMemories;
    }

    _profileReady = true;
    _persistSettings();
    notifyListeners();
  }

  /// Returns the app to its anonymous state.
  ///
  /// Nothing is deleted: the account's answers, baseline and history stay on
  /// disk under its own id and come back at the next sign-in. What this does
  /// is stop showing them, which on a shared phone is the whole point.
  Future<void> signOutAccount() async {
    if (_accountId == null) return;
    _accountId = null;
    // The role goes with the account. `lastRole` exists so a *returning*
    // person is not re-asked, but an explicit sign-out means the next person
    // to pick up the phone may be someone else — and keeping the old role
    // sent them straight back into the patient app with no way to reach the
    // role picker at all.
    _role = AppRole.none;
    _patient = MockData.emptyPatient;
    _profileReady = false;
    _baseline = null;
    _intake = IntakeRecord.empty;
    _mood = null;
    _lastDecision = null;
    _lastPlayed = null;
    _persistSettings();

    _intake = await _assessment.intake(_assessmentScope) ?? IntakeRecord.empty;
    _baseline = await _assessment.baseline(_assessmentScope);
    await _loadPatientScopedData();
    _memoryFragments = await _memories.all(_assessmentScope);
    notifyListeners();
  }

  Future<void> resetAssessment() async {
    _intake = IntakeRecord.empty;
    _baseline = null;
    notifyListeners();
    await _write(() async {
      await _assessment.saveIntake(_assessmentScope, IntakeRecord.empty);
    });
  }

  // ── Daily conversation ─────────────────────────────────────────────────
  MoodLevel? _mood;
  MoodLevel? get mood => _mood;

  final List<JournalEntry> _journal = <JournalEntry>[];
  List<JournalEntry> get journal => List<JournalEntry>.unmodifiable(_journal);

  final Set<String> _answered = <String>{};
  bool answered(String questionId) => _answered.contains(questionId);

  final Set<String> _journeyDone = <String>{};
  Set<String> get journeyDone => Set<String>.unmodifiable(_journeyDone);

  // Starts at nothing and is earned by real activity, mood check-ins and
  // reminders. It used to open at 78 on a fresh install, which read as
  // "you have already done most of today" before the person had done any.
  int _todayEngagement = _seedDemo ? 78 : 0;
  int get todayEngagement => _todayEngagement;

  int _lastActiveMinutes = _seedDemo ? 12 : 0;
  String get lastActiveLabel =>
      _lastActiveMinutes == 0 ? 'Just now' : '$_lastActiveMinutes min ago';

  void setMood(MoodLevel m) {
    _mood = m;
    _journeyDone.add('checkin');
    _lastActiveMinutes = 0;
    _write(() async {
      await _daily.saveMood(_patient.id, m);
      await _daily.markJourneyStep(_patient.id, 'checkin');
      await _sync.enqueue(SyncOperationKind.moodCheckIn, <String, dynamic>{
        'patientId': _patient.id,
        'mood': m.name,
        'at': _clockLabel(),
      });
    });
    notifyListeners();
  }

  void answerQuestion(DailyQuestion q, QuestionOption option) {
    _answered.add(q.id);
    final JournalEntry entry = JournalEntry(
      questionId: q.id,
      label: q.journalLabel,
      answer: option.label,
      positive: option.positive,
      time: _clockLabel(),
    );
    _journal.add(entry);
    _journeyDone.add('memory');
    _todayEngagement = math.min(99, _todayEngagement + (option.positive ? 2 : 1));
    _lastActiveMinutes = 0;

    final int engagementToSave = _todayEngagement;
    _write(() async {
      await _daily.addJournalEntry(_patient.id, entry, q.id);
      await _daily.markJourneyStep(_patient.id, 'memory');
      await _daily.saveEngagement(_patient.id, engagementToSave);
      await _sync.enqueue(SyncOperationKind.journalEntry, <String, dynamic>{
        'patientId': _patient.id,
        'questionId': q.id,
        'answer': option.label,
        'positive': option.positive,
        'at': entry.time,
      });
    });
    notifyListeners();
  }

  void completeReflection() {
    _journeyDone.add('reflection');
    _write(() async {
      await _daily.markJourneyStep(_patient.id, 'reflection');
      await _sync.enqueue(SyncOperationKind.reflection, <String, dynamic>{
        'patientId': _patient.id,
        'at': _clockLabel(),
      });
    });
    notifyListeners();
  }

  // ── Reminders ──────────────────────────────────────────────────────────
  final List<Reminder> _reminders = MockData.reminders();
  List<Reminder> get reminders => List<Reminder>.unmodifiable(_reminders);

  List<Reminder> get medicineReminders =>
      _reminders.where((Reminder r) => r.kind == ReminderKind.medicine).toList();

  void toggleReminder(String id) {
    final int i = _reminders.indexWhere((Reminder r) => r.id == id);
    if (i < 0) return;
    final bool done = !_reminders[i].done;
    _reminders[i] = _reminders[i].copyWith(done: done);
    _lastActiveMinutes = 0;
    _write(() async {
      await _reminderRepo.setDone(id, done);
      await _sync.enqueue(SyncOperationKind.reminderToggle, <String, dynamic>{
        'patientId': _patient.id,
        'reminderId': id,
        'done': done,
        'at': _clockLabel(),
      });
    });
    notifyListeners();
  }

  void addReminder(String title, String timeStr, int minutesFromMidnight, ReminderKind kind, {String detail = '', bool smsEnabled = true}) {
    final reminder = Reminder(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      time: timeStr,
      minutesFromMidnight: minutesFromMidnight,
      title: title,
      kind: kind,
      detail: detail,
      done: false,
      smsEnabled: smsEnabled,
    );
    _reminders.add(reminder);
    _reminders.sort((a, b) => a.minutesFromMidnight.compareTo(b.minutesFromMidnight));
    LocalNotificationService.instance.scheduleReminderNotification(reminder);
    _write(() async {
      await _reminderRepo.save(reminder);
      await _sync.enqueue(SyncOperationKind.reminderCreate, <String, dynamic>{
        'patientId': _patient.id,
        'reminder': <String, dynamic>{
          'id': reminder.id,
          'time': reminder.time,
          'minutes_from_midnight': reminder.minutesFromMidnight,
          'title': reminder.title,
          'kind': reminder.kind.name,
          'detail': reminder.detail,
          'sms_enabled': reminder.smsEnabled,
        },
        'at': _clockLabel(),
      });
    });
    notifyListeners();
  }

  /// Appointments are not part of the daily adherence figure — a clinic visit
  /// on Thursday should not read as a missed reminder today.
  List<Reminder> get dailyReminders =>
      _reminders.where((Reminder r) => r.kind != ReminderKind.appointment).toList();

  int get remindersDone => dailyReminders.where((Reminder r) => r.done).length;
  int get remindersTotal => dailyReminders.length;

  int get medicineDone => medicineReminders.where((Reminder r) => r.done).length;
  int get medicineTotal => medicineReminders.length;

  int get adherencePercent =>
      remindersTotal == 0 ? 0 : ((remindersDone / remindersTotal) * 100).round();

  // ── Accessibility ──────────────────────────────────────────────────────
  TextSizePreference _textSize = TextSizePreference.large;
  TextSizePreference get textSize => _textSize;
  set textSize(TextSizePreference v) {
    _textSize = v;
    _persistSettings();
    notifyListeners();
  }

  bool _highContrast = false;
  bool get highContrast => _highContrast;
  set highContrast(bool v) {
    _highContrast = v;
    _persistSettings();
    notifyListeners();
  }

  bool _reduceMotion = false;
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool v) {
    _reduceMotion = v;
    _persistSettings();
    notifyListeners();
  }

  bool _voicePrompts = true;
  bool get voicePrompts => _voicePrompts;
  set voicePrompts(bool v) {
    _voicePrompts = v;
    _persistSettings();
    notifyListeners();
  }

  /// The interface language code (`en`/`hi`/`as`/`mr`), so it survives a
  /// restart. `AppState` only stores the choice — `LocaleController` (see
  /// `lib/l10n/locale_controller.dart`) is what actually drives the live UI,
  /// deliberately kept separate since it has no other reason to touch Hive.
  /// `MemoryMitraApp` seeds the controller from this at startup; whatever
  /// calls `LocaleController.setLocale` is responsible for also setting this
  /// so the two stay in sync (see `LanguageSelector`).
  String? _localeCode;
  String? get localeCode => _localeCode;
  set localeCode(String? v) {
    _localeCode = v;
    _persistSettings();
    notifyListeners();
  }

  void _persistSettings() {
    final AppSettings snapshot = AppSettings(
      textSize: _textSize,
      highContrast: _highContrast,
      reduceMotion: _reduceMotion,
      voicePrompts: _voicePrompts,
      offlineOverride: _connectivity.forcedOffline,
      lastRole: _role == AppRole.none ? null : _role.name,
      lastAccountId: _accountId,
      safeZoneJson: _safeZone?.encode(),
      localeCode: _localeCode,
    );
    _write(() => _settingsRepo.save(snapshot));
  }

  // ── Safe zone ──────────────────────────────────────────────────────────

  SafeZone? _safeZone;

  /// The area the caregiver expects the patient to stay inside, or null when
  /// none has been drawn yet.
  SafeZone? get safeZone => _safeZone;

  /// Wandering events, newest first, mirrored here from `SafeZoneMonitor` so
  /// the caregiver dashboard can show them without owning the monitor.
  final List<SafeZoneEvent> _safeZoneEvents = <SafeZoneEvent>[];
  List<SafeZoneEvent> get safeZoneEvents =>
      List<SafeZoneEvent>.unmodifiable(_safeZoneEvents);

  /// The most recent unresolved departure, or null when the patient is home.
  SafeZoneEvent? get activeWanderAlert {
    if (_safeZoneEvents.isEmpty) return null;
    final SafeZoneEvent newest = _safeZoneEvents.first;
    return newest.kind == SafeZoneEventKind.left ? newest : null;
  }

  void setSafeZone(SafeZone? zone) {
    _safeZone = zone;
    _persistSettings();
    notifyListeners();
  }

  void recordSafeZoneEvent(SafeZoneEvent event) {
    _safeZoneEvents.insert(0, event);
    if (_safeZoneEvents.length > 50) _safeZoneEvents.removeLast();
    notifyListeners();
  }

  // ── Connectivity and sync ──────────────────────────────────────────────

  /// True when the device has no route to the network, or the caregiver has
  /// switched the app to work offline.
  bool get offline => !_connectivity.isOnline;

  /// Operations written locally that have not reached the server.
  int get pendingSync => _sync.pendingCount;

  bool get syncing => _sync.isSyncing;

  DateTime? get lastSyncedAt => _sync.lastSyncedAt;

  /// The caregiver's manual switch. Forcing offline is honoured immediately;
  /// switching back on lets the real connection decide, and drains the queue.
  void setOffline(bool value) {
    _connectivity.forcedOffline = value;
    _persistSettings();
    notifyListeners();
  }

  /// Drains the outbox. A no-op while offline or when nothing is queued.
  Future<void> syncNow() async {
    await flush();
    await _sync.sync();
    await flush();
  }

  /// The outbox, newest first — backs the caregiver's sync detail list.
  Future<List<PendingOperation>> pendingOperations() => _sync.inspect();

  // ── Derived views used by the caregiver / clinician screens ────────────
  Recommendation get todaysRecommendation => personalization.recommend(
        _patient,
        completedToday: <GameId, int>{for (final GameId g in _completedToday) g: 1},
        avoid: _lastPlayed,
      );

  List<SeriesPoint> get engagementWeek {
    final List<double> base = List<double>.from(MockData.weeklyEngagement);
    base[base.length - 1] = _todayEngagement.toDouble();
    return MockData.series(base);
  }

  List<SeriesPoint> get gamesWeek {
    final List<double> base = List<double>.from(MockData.weeklyGames);
    base[base.length - 1] = _completedToday.length.toDouble();
    return MockData.series(base);
  }

  List<SeriesPoint> get adherenceWeek {
    final List<double> base = List<double>.from(MockData.weeklyAdherence);
    base[base.length - 1] = adherencePercent.toDouble();
    return MockData.series(base);
  }

  List<SeriesPoint> get memoryActivityWeek {
    final List<double> base = List<double>.from(MockData.weeklyMemoryActivity);
    base[base.length - 1] =
        _journal.where((JournalEntry e) => e.positive).length.toDouble();
    return MockData.series(base);
  }

  /// The clinician caseload, with the demo patient kept in step with the app.
  List<ClinicPatient> get caseload {
    final List<ClinicPatient> list = MockData.caseload();
    final int i = list.indexWhere((ClinicPatient c) => c.id == _patient.id);
    if (i >= 0) {
      final List<double> trend = List<double>.from(list[i].thirtyDay);
      trend[trend.length - 1] = _profile.overall.toDouble();
      list[i] = list[i].copyWith(
        score: _profile.overall,
        profile: _profile,
        thirtyDay: trend,
      );
    }
    return list;
  }

  List<DoctorAlert> get alerts => MockData.alerts();

  Future<List<DailyQuestion>> loadQuestions() => _patients.dailyQuestions(_patient);
  Future<List<GameDefinition>> loadGames() => _games.catalogue();
  Future<List<ClinicPatient>> loadCaseload() => _analytics.caseload();

  @override
  void dispose() {
    _sync.removeListener(notifyListeners);
    _sync.dispose();
    unawaited(_connectivity.dispose());
    super.dispose();
  }
}

/// Makes [AppState] available to the widget tree without a state-management
/// package.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing to changes.
  static AppState read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!.notifier!;
  }
}
