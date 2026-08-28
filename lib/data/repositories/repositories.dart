import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/patient.dart';
import '../mock/mock_data.dart';

/// Repository contracts.
///
/// Every screen talks to these interfaces, never to [MockData] directly, so
/// swapping in Firebase or a FastAPI client later means writing new
/// implementations and changing one line in `AppState`.

abstract class PatientRepository {
  Future<Patient> load(String id);
  Future<void> save(Patient patient);
  Future<List<DailyQuestion>> dailyQuestions(Patient patient);
}

abstract class GameRepository {
  Future<List<GameDefinition>> catalogue();
  Future<Map<GameId, int>> levels(String patientId);
  Future<void> recordSession(String patientId, GameSession session);
  Future<List<GameSession>> history(String patientId);
}

abstract class AnalyticsRepository {
  Future<CognitiveProfile> profile(String patientId);
  Future<List<SeriesPoint>> weeklyEngagement(String patientId);
  Future<List<SeriesPoint>> weeklyGames(String patientId);
  Future<List<SeriesPoint>> weeklyAdherence(String patientId);
  Future<List<ClinicPatient>> caseload();
  Future<List<DoctorAlert>> alerts();
}

abstract class ReminderRepository {
  Future<List<Reminder>> today(String patientId);
  Future<void> setDone(String reminderId, bool done);
}

// ─────────────────────────────────────────────────────────────────────────
// Mock implementations — all local, all offline, all instant.
// ─────────────────────────────────────────────────────────────────────────

/// Small helper so mock calls feel like real async work without slowing the
/// demo down.
Future<T> _settle<T>(T value) =>
    Future<T>.delayed(const Duration(milliseconds: 120), () => value);

class MockPatientRepository implements PatientRepository {
  Patient _patient = MockData.aama;

  @override
  Future<Patient> load(String id) => _settle(_patient);

  @override
  Future<void> save(Patient patient) async => _patient = patient;

  @override
  Future<List<DailyQuestion>> dailyQuestions(Patient patient) =>
      _settle(MockData.dailyQuestions(patient));
}

class MockGameRepository implements GameRepository {
  final Map<GameId, int> _levels = Map<GameId, int>.from(MockData.startingLevels);
  final List<GameSession> _history = MockData.history();

  @override
  Future<List<GameDefinition>> catalogue() => _settle(MockData.games);

  @override
  Future<Map<GameId, int>> levels(String patientId) => _settle(_levels);

  @override
  Future<void> recordSession(String patientId, GameSession session) async {
    _history.insert(0, session);
    _levels[session.gameId] = session.level;
  }

  @override
  Future<List<GameSession>> history(String patientId) => _settle(_history);
}

class MockAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<CognitiveProfile> profile(String patientId) => _settle(MockData.aamaProfile());

  @override
  Future<List<SeriesPoint>> weeklyEngagement(String patientId) =>
      _settle(MockData.series(MockData.weeklyEngagement));

  @override
  Future<List<SeriesPoint>> weeklyGames(String patientId) =>
      _settle(MockData.series(MockData.weeklyGames));

  @override
  Future<List<SeriesPoint>> weeklyAdherence(String patientId) =>
      _settle(MockData.series(MockData.weeklyAdherence));

  @override
  Future<List<ClinicPatient>> caseload() => _settle(MockData.caseload());

  @override
  Future<List<DoctorAlert>> alerts() => _settle(MockData.alerts());
}

class MockReminderRepository implements ReminderRepository {
  final List<Reminder> _reminders = MockData.reminders();

  @override
  Future<List<Reminder>> today(String patientId) => _settle(_reminders);

  @override
  Future<void> setDone(String reminderId, bool done) async {
    final int i = _reminders.indexWhere((Reminder r) => r.id == reminderId);
    if (i >= 0) _reminders[i] = _reminders[i].copyWith(done: done);
  }
}
