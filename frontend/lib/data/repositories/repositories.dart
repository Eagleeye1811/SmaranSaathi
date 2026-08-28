import '../../core/models/assessment.dart';
import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/memory_fragment.dart';
import '../../core/models/monitoring.dart';
import '../../core/models/patient.dart';
import '../../core/models/settings.dart';
import '../local/sync_operation.dart';
import '../mock/mock_data.dart';

/// Repository contracts.
///
/// Every screen talks to these interfaces, never to [MockData] or to Hive
/// directly, so swapping in Firebase or a FastAPI client later means writing
/// new implementations and changing one line in `AppState`.
///
/// Two implementations ship today: the in-memory `Mock*` set (used by tests
/// and by the pure-demo build) and the `Hive*` set in `hive_repositories.dart`
/// which persists to disk.

abstract class PatientRepository {
  Future<Patient> load(String id);
  Future<void> save(Patient patient);
  Future<List<DailyQuestion>> dailyQuestions(Patient patient);

  /// Null when no profile has ever been saved — the caller then falls back to
  /// the seeded demo patient.
  Future<Patient?> current();

  /// The profile stored under exactly this id, or null.
  ///
  /// Distinct from [load], which falls back: two accounts sharing a device
  /// must never inherit each other's name and age, so a caller that is
  /// deciding "does this account have a profile yet" needs an honest null.
  Future<Patient?> byId(String id);
}

abstract class GameRepository {
  Future<List<GameDefinition>> catalogue();
  Future<Map<GameId, int>> levels(String patientId);
  Future<void> saveLevel(String patientId, GameId id, int level);
  Future<void> recordSession(String patientId, GameSession session);
  Future<List<GameSession>> history(String patientId);
}

abstract class AnalyticsRepository {
  Future<CognitiveProfile> profile(String patientId);
  Future<void> saveProfile(String patientId, CognitiveProfile profile);
  Future<List<SeriesPoint>> weeklyEngagement(String patientId);
  Future<List<SeriesPoint>> weeklyGames(String patientId);
  Future<List<SeriesPoint>> weeklyAdherence(String patientId);
  Future<List<ClinicPatient>> caseload();
  Future<List<DoctorAlert>> alerts();
}

abstract class ReminderRepository {
  Future<List<Reminder>> today(String patientId);
  Future<void> setDone(String reminderId, bool done);

  /// Writes the day's reminder list if none is stored yet. Existing rows —
  /// including their done state — are left alone.
  Future<void> seedIfEmpty(List<Reminder> reminders);
}

/// Mood, journal and the "today's journey" progress strip.
abstract class DailyRepository {
  Future<DailySnapshot> load(String patientId);
  Future<void> saveMood(String patientId, MoodLevel mood);
  Future<void> addJournalEntry(String patientId, JournalEntry entry, String questionId);
  Future<void> markJourneyStep(String patientId, String step);
  Future<void> markGameCompleted(String patientId, GameId id);
  Future<void> saveEngagement(String patientId, int engagement);
}

/// The structured intake and the cognitive baseline.
///
/// Both are stored as JSON maps rather than typed rows: the questionnaire is
/// expected to keep changing, and a map absorbs a new field without a schema
/// step. `null` from either getter means "never answered", which the intake
/// flow treats as "start at the beginning".
abstract class AssessmentRepository {
  Future<IntakeRecord?> intake(String patientId);
  Future<void> saveIntake(String patientId, IntakeRecord record);
  Future<CognitiveBaseline?> baseline(String patientId);
  Future<void> saveBaseline(String patientId, CognitiveBaseline baseline);
}

/// The "Memory Home" companion's long-term store — every real life-story
/// fragment the patient has shared with Mitra, across every session. This is
/// what makes the spaced-repetition recall possible at all: without it,
/// "remember what she told me last week" has nothing to read from.
abstract class MemoryFragmentRepository {
  Future<List<MemoryFragment>> all(String patientId);
  Future<MemoryFragment> add(String patientId, MemoryFragment fragment);
  Future<void> markResurfaced(String patientId, String fragmentId, DateTime at);
}

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// The durable outbox behind offline-first operation.
abstract class SyncRepository {
  Future<void> enqueue(PendingOperation operation);

  /// Operations still waiting to reach the server (pending or previously failed).
  Future<List<PendingOperation>> pending();

  /// Everything in the queue, including already-synced rows, newest first.
  Future<List<PendingOperation>> all();

  Future<void> update(PendingOperation operation);

  /// Drops rows that have been confirmed synced, keeping the box bounded.
  Future<void> purgeSynced();
}

// ─────────────────────────────────────────────────────────────────────────
// Mock implementations — all local, all offline, all instant.
// ─────────────────────────────────────────────────────────────────────────

/// Small helper so mock calls feel like real async work without slowing the
/// demo down.
Future<T> _settle<T>(T value) =>
    Future<T>.delayed(const Duration(milliseconds: 120), () => value);

class MockPatientRepository implements PatientRepository {
  final Map<String, Patient> _byId = <String, Patient>{};
  Patient _patient = MockData.aama;
  bool _saved = false;

  @override
  Future<Patient> load(String id) => _settle(_byId[id] ?? _patient);

  @override
  Future<Patient?> current() async => _saved ? _patient : null;

  @override
  Future<Patient?> byId(String id) => _settle(_byId[id]);

  @override
  Future<void> save(Patient patient) async {
    _byId[patient.id] = patient;
    _patient = patient;
    _saved = true;
  }

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
  Future<void> saveLevel(String patientId, GameId id, int level) async =>
      _levels[id] = level;

  @override
  Future<void> recordSession(String patientId, GameSession session) async {
    _history.insert(0, session);
    _levels[session.gameId] = session.level;
  }

  @override
  Future<List<GameSession>> history(String patientId) => _settle(_history);
}

class MockAnalyticsRepository implements AnalyticsRepository {
  CognitiveProfile _profile = MockData.aamaProfile();

  @override
  Future<CognitiveProfile> profile(String patientId) => _settle(_profile);

  @override
  Future<void> saveProfile(String patientId, CognitiveProfile profile) async =>
      _profile = profile;

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
  Future<void> seedIfEmpty(List<Reminder> reminders) async {}

  @override
  Future<void> setDone(String reminderId, bool done) async {
    final int i = _reminders.indexWhere((Reminder r) => r.id == reminderId);
    if (i >= 0) _reminders[i] = _reminders[i].copyWith(done: done);
  }
}

class MockDailyRepository implements DailyRepository {
  DailySnapshot _snapshot = DailySnapshot.empty;

  @override
  Future<DailySnapshot> load(String patientId) async => _snapshot;

  @override
  Future<void> saveMood(String patientId, MoodLevel mood) async =>
      _snapshot = _copy(mood: mood);

  @override
  Future<void> addJournalEntry(
      String patientId, JournalEntry entry, String questionId) async {
    _snapshot = _copy(
      journal: <JournalEntry>[..._snapshot.journal, entry],
      answered: <String>{..._snapshot.answeredQuestions, questionId},
    );
  }

  @override
  Future<void> markJourneyStep(String patientId, String step) async =>
      _snapshot = _copy(journey: <String>{..._snapshot.journeyDone, step});

  @override
  Future<void> markGameCompleted(String patientId, GameId id) async =>
      _snapshot = _copy(completed: <String>{..._snapshot.completedGameIds, id.name});

  @override
  Future<void> saveEngagement(String patientId, int engagement) async =>
      _snapshot = _copy(engagement: engagement);

  DailySnapshot _copy({
    MoodLevel? mood,
    List<JournalEntry>? journal,
    Set<String>? answered,
    Set<String>? journey,
    Set<String>? completed,
    int? engagement,
  }) {
    return DailySnapshot(
      mood: mood ?? _snapshot.mood,
      journal: journal ?? _snapshot.journal,
      answeredQuestions: answered ?? _snapshot.answeredQuestions,
      journeyDone: journey ?? _snapshot.journeyDone,
      engagement: engagement ?? _snapshot.engagement,
      completedGameIds: completed ?? _snapshot.completedGameIds,
      dayStamp: _snapshot.dayStamp,
    );
  }
}

class MockAssessmentRepository implements AssessmentRepository {
  IntakeRecord? _intake;
  CognitiveBaseline? _baseline;

  @override
  Future<IntakeRecord?> intake(String patientId) async => _intake;

  @override
  Future<void> saveIntake(String patientId, IntakeRecord record) async => _intake = record;

  @override
  Future<CognitiveBaseline?> baseline(String patientId) async => _baseline;

  @override
  Future<void> saveBaseline(String patientId, CognitiveBaseline baseline) async =>
      _baseline = baseline;
}

class MockMemoryFragmentRepository implements MemoryFragmentRepository {
  final List<MemoryFragment> _fragments = <MemoryFragment>[];

  @override
  Future<List<MemoryFragment>> all(String patientId) async => List<MemoryFragment>.of(_fragments);

  @override
  Future<MemoryFragment> add(String patientId, MemoryFragment fragment) async {
    _fragments.add(fragment);
    return fragment;
  }

  @override
  Future<void> markResurfaced(String patientId, String fragmentId, DateTime at) async {
    final int i = _fragments.indexWhere((MemoryFragment f) => f.id == fragmentId);
    if (i < 0) return;
    _fragments[i] = _fragments[i].copyWith(
      lastResurfacedAt: at,
      timesResurfaced: _fragments[i].timesResurfaced + 1,
    );
  }
}

class MockSettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}

/// In-memory outbox. Behaves exactly like the Hive one, but forgets on restart
/// — which is precisely what the persistent implementation exists to fix.
class MockSyncRepository implements SyncRepository {
  final List<PendingOperation> _queue = <PendingOperation>[];

  @override
  Future<void> enqueue(PendingOperation operation) async => _queue.add(operation);

  @override
  Future<List<PendingOperation>> pending() async =>
      _queue.where((PendingOperation o) => o.isPending).toList();

  @override
  Future<List<PendingOperation>> all() async =>
      _queue.reversed.toList(growable: false);

  @override
  Future<void> update(PendingOperation operation) async {
    final int i = _queue.indexWhere((PendingOperation o) => o.id == operation.id);
    if (i >= 0) _queue[i] = operation;
  }

  @override
  Future<void> purgeSynced() async =>
      _queue.removeWhere((PendingOperation o) => o.status == SyncStatus.synced);
}
