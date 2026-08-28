import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/mock/mock_data.dart';
import '../../data/repositories/repositories.dart';
import '../models/clinical.dart';
import '../models/daily.dart';
import '../models/game.dart';
import '../models/patient.dart';
import 'adaptive_difficulty_service.dart';
import 'personalization_service.dart';

enum AppRole { none, patient, caregiver, doctor }

enum TextSizePreference { normal, large, extraLarge }

extension TextSizePreferenceX on TextSizePreference {
  String get label => switch (this) {
        TextSizePreference.normal => 'Normal',
        TextSizePreference.large => 'Large',
        TextSizePreference.extraLarge => 'Extra large',
      };

  double get scale => switch (this) {
        TextSizePreference.normal => 1.0,
        TextSizePreference.large => 1.14,
        TextSizePreference.extraLarge => 1.3,
      };
}

/// The single source of truth for the running demo.
///
/// Holds the personalised profile, session history, journal, reminders,
/// accessibility preferences and the simulated connectivity state, and keeps
/// every role's screens consistent with one another — a game finished in the
/// patient app immediately changes the caregiver dashboard and the clinician
/// trend.
class AppState extends ChangeNotifier {
  AppState({
    PatientRepository? patients,
    GameRepository? games,
    AnalyticsRepository? analytics,
    ReminderRepository? reminders,
  })  : _patients = patients ?? MockPatientRepository(),
        _games = games ?? MockGameRepository(),
        _analytics = analytics ?? MockAnalyticsRepository(),
        _reminderRepo = reminders ?? MockReminderRepository();

  final PatientRepository _patients;
  final GameRepository _games;
  final AnalyticsRepository _analytics;
  final ReminderRepository _reminderRepo;

  static const AdaptiveDifficultyService adaptive = AdaptiveDifficultyService();
  static const PersonalizationService personalization = PersonalizationService();

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

  void setRole(AppRole r) {
    _role = r;
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
    await _patients.save(_patient);
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
    _games.recordSession(_patient.id, session);

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
    if (_offline) _pendingSync += 1;

    _lastActiveMinutes = 0;
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
    if (_offline) _pendingSync += 1;
    notifyListeners();
  }

  void answerQuestion(DailyQuestion q, QuestionOption option) {
    _answered.add(q.id);
    _journal.add(JournalEntry(
      questionId: q.id,
      label: q.journalLabel,
      answer: option.label,
      positive: option.positive,
      time: _clockLabel(),
    ));
    _journeyDone.add('memory');
    _todayEngagement = math.min(99, _todayEngagement + (option.positive ? 2 : 1));
    _lastActiveMinutes = 0;
    if (_offline) _pendingSync += 1;
    notifyListeners();
  }

  void completeReflection() {
    _journeyDone.add('reflection');
    if (_offline) _pendingSync += 1;
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
    _reminders[i] = _reminders[i].copyWith(done: !_reminders[i].done);
    _reminderRepo.setDone(id, _reminders[i].done);
    if (_offline) _pendingSync += 1;
    _lastActiveMinutes = 0;
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
    notifyListeners();
  }

  bool _highContrast = false;
  bool get highContrast => _highContrast;
  set highContrast(bool v) {
    _highContrast = v;
    notifyListeners();
  }

  bool _reduceMotion = false;
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool v) {
    _reduceMotion = v;
    notifyListeners();
  }

  bool _voicePrompts = true;
  bool get voicePrompts => _voicePrompts;
  set voicePrompts(bool v) {
    _voicePrompts = v;
    notifyListeners();
  }

  // ── Connectivity (simulated) ───────────────────────────────────────────
  bool _offline = false;
  bool get offline => _offline;

  int _pendingSync = 0;
  int get pendingSync => _pendingSync;

  bool _syncing = false;
  bool get syncing => _syncing;

  void setOffline(bool value) {
    _offline = value;
    if (value) {
      // Activity generated before going offline is already safely on device.
      _pendingSync = math.max(_pendingSync, 3);
    }
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_offline || _pendingSync == 0) return;
    _syncing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    _pendingSync = 0;
    _syncing = false;
    notifyListeners();
  }

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
