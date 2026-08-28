import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/local/sync_operation.dart';
import '../../data/mock/demo_journey.dart';
import '../../data/mock/mock_data.dart';
import '../../data/repositories/repositories.dart';
import '../models/assessment.dart';
import '../models/clinical.dart';
import '../models/daily.dart';
import '../models/game.dart';
import '../models/monitoring.dart';
import '../models/patient.dart';
import '../models/report.dart';
import '../models/settings.dart';
import 'adaptive_difficulty_service.dart';
import 'cognitive_monitoring_service.dart';
import 'connectivity_service.dart';
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

  Patient _patient = MockData.aama;
  Patient get patient => _patient;

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
    _patient = p.copyWith(
      family: p.family.isEmpty ? MockData.family : p.family,
      memories: p.memories.isEmpty ? MockData.memories : p.memories,
      assets: p.assets.isEmpty ? MockData.assets : p.assets,
      routine: p.routine.isEmpty ? MockData.routine : p.routine,
    );
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
    _connectivity.forcedOffline = settings.offlineOverride;

    final Patient? stored = await _patients.current();
    if (stored != null) {
      _patient = stored;
    } else {
      await _patients.save(_patient);
    }

    // Activity levels and history.
    final Map<GameId, int> levels = await _games.levels(_patient.id);
    if (levels.isEmpty) {
      for (final MapEntry<GameId, int> e in MockData.startingLevels.entries) {
        await _games.saveLevel(_patient.id, e.key, e.value);
      }
    } else {
      _levels.addAll(levels);
    }

    final List<GameSession> history = await _games.history(_patient.id);
    if (history.isEmpty) {
      // Seed the demo's prior fortnight so charts and trends are not blank on
      // a fresh install. Real sessions are appended in front of these.
      for (final GameSession s in _sessions) {
        await _games.recordSession(_patient.id, s);
      }
    } else {
      _sessions
        ..clear()
        ..addAll(history);
    }

    _profile = await _analytics.profile(_patient.id);

    // Reminders: the schedule is authored, the done flags are the user's.
    await _reminderRepo.seedIfEmpty(MockData.reminders());
    final List<Reminder> storedReminders = await _reminderRepo.today(_patient.id);
    if (storedReminders.isNotEmpty) {
      _reminders
        ..clear()
        ..addAll(storedReminders);
    }

    // Today's conversation.
    final DailySnapshot snapshot = await _daily.load(_patient.id);
    _mood = snapshot.mood;
    _journal
      ..clear()
      ..addAll(snapshot.journal);
    _answered.addAll(snapshot.answeredQuestions);
    _journeyDone.addAll(snapshot.journeyDone);
    _todayEngagement = snapshot.engagement;
    for (final String name in snapshot.completedGameIds) {
      for (final GameId id in GameId.values) {
        if (id.name == name) _completedToday.add(id);
      }
    }

    // The structured intake and the personal baseline, for whichever account
    // this device last worked on.
    _accountId = settings.lastAccountId;
    _intake = await _assessment.intake(_assessmentScope) ?? IntakeRecord.empty;
    _baseline = await _assessment.baseline(_assessmentScope);

    if (_seedDemo && _intake.completedAtIso == null) {
      await loadDemoJourney();
    }

    await _sync.load();
    _hydrated = true;
    notifyListeners();
  }

  // ── Games ──────────────────────────────────────────────────────────────
  final Map<GameId, int> _levels = Map<GameId, int>.from(MockData.startingLevels);
  Map<GameId, int> get levels => Map<GameId, int>.unmodifiable(_levels);
  int levelOf(GameId id) => _levels[id] ?? 1;

  final List<GameSession> _sessions = MockData.history();
  List<GameSession> get sessions => List<GameSession>.unmodifiable(_sessions);

  final Set<GameId> _completedToday = <GameId>{};
  Set<GameId> get completedToday => Set<GameId>.unmodifiable(_completedToday);

  AdaptiveDecision? _lastDecision;
  AdaptiveDecision? get lastDecision => _lastDecision;

  GameId? _lastPlayed;
  GameId? get lastPlayed => _lastPlayed;

  CognitiveProfile _profile = MockData.aamaProfile();
  CognitiveProfile get cognitiveProfile => _profile;

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

    // Nudge the domain the activity exercises, plus a smaller general effect.
    final CognitiveDomain domain = MockData.game(id).domain;
    final int delta = ((p.overall - 74) / 8).round().clamp(-3, 3);
    _profile = _profile.withDelta(<CognitiveDomain, int>{
      domain: delta + 1,
      CognitiveDomain.attention: (delta * 0.5).round(),
    });

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
  List<GameId> get baselineRemaining => GameId.values
      .where((GameId g) => !_intake.baselineActivities.contains(g.name))
      .toList(growable: false);

  bool get baselineRunComplete => baselineRemaining.isEmpty;

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
  void markBaselineActivity(GameId id) {
    if (_intake.baselineActivities.contains(id.name)) return;
    _saveIntake(_intake.copyWith(
      baselineActivities: <String>{..._intake.baselineActivities, id.name},
    ));
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
  Future<void> signInAccount(String uid) async {
    if (_accountId == uid) return;
    // Only answers given *anonymously* can be adopted. Switching from one
    // account to another must never carry the first person's answers across.
    final bool wasAnonymous = _accountId == null;
    _accountId = uid;
    _persistSettings();

    final IntakeRecord? stored = await _assessment.intake(uid);
    final CognitiveBaseline? baseline = await _assessment.baseline(uid);

    // A first sign-in adopts anything already answered anonymously on this
    // device rather than throwing it away — someone who started the
    // questionnaire and only then created an account keeps their progress.
    if (wasAnonymous && stored == null && _intake.consentGiven) {
      final IntakeRecord adopted = _intake.copyWith(accountId: uid);
      _intake = adopted;
      await _write(() async {
        await _assessment.saveIntake(uid, adopted);
        if (_baseline != null) await _assessment.saveBaseline(uid, _baseline!);
      });
    } else {
      _intake = stored ?? IntakeRecord.empty;
      _baseline = baseline;
    }
    notifyListeners();
  }

  /// Unbinds the account. The stored assessment is left untouched — signing
  /// out is not the same as deleting someone's health record.
  Future<void> signOutAccount() async {
    if (_accountId == null) return;
    _accountId = null;
    _persistSettings();
    _intake = await _assessment.intake(_assessmentScope) ?? IntakeRecord.empty;
    _baseline = await _assessment.baseline(_assessmentScope);
    notifyListeners();
  }

  /// Clears the assessment so the intake can be walked from the beginning —
  /// used between demonstrations and by "start over" in the profile.
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

  int _todayEngagement = 78;
  int get todayEngagement => _todayEngagement;

  int _lastActiveMinutes = 12;
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

  void _persistSettings() {
    final AppSettings snapshot = AppSettings(
      textSize: _textSize,
      highContrast: _highContrast,
      reduceMotion: _reduceMotion,
      voicePrompts: _voicePrompts,
      offlineOverride: _connectivity.forcedOffline,
      lastRole: _role == AppRole.none ? null : _role.name,
      lastAccountId: _accountId,
    );
    _write(() => _settingsRepo.save(snapshot));
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
