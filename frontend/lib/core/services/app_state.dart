import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/local/sync_operation.dart';
import '../../data/mock/mock_data.dart';
import '../../data/repositories/repositories.dart';
import '../models/clinical.dart';
import '../models/daily.dart';
import '../models/game.dart';
import '../models/patient.dart';
import '../models/settings.dart';
import 'adaptive_difficulty_service.dart';
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
    SettingsRepository? settings,
    SyncRepository? sync,
    ConnectivityService? connectivity,
    SyncTransport? transport,
  })  : _patients = patients ?? MockPatientRepository(),
        _games = games ?? MockGameRepository(),
        _analytics = analytics ?? MockAnalyticsRepository(),
        _reminderRepo = reminders ?? MockReminderRepository(),
        _daily = daily ?? MockDailyRepository(),
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
  final SettingsRepository _settingsRepo;
  final OverridableConnectivityService _connectivity;
  late final SyncManager _sync;

  static const AdaptiveDifficultyService adaptive = AdaptiveDifficultyService();
  static const PersonalizationService personalization = PersonalizationService();

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
