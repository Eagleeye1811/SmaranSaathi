import 'package:hive_ce/hive.dart';

import '../../core/models/assessment.dart';
import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/monitoring.dart';
import '../../core/models/patient.dart';
import '../../core/models/settings.dart';
import '../local/hive_store.dart';
import '../local/sync_operation.dart';
import '../mock/mock_data.dart';
import 'repositories.dart';

/// Hive-backed repositories.
///
/// These are the only classes in the app that touch a `Box`. Screens go
/// through `AppState`, `AppState` goes through the repository contract, and
/// the contract lands here.
///
/// Content that is authored rather than produced — the activity catalogue, the
/// question bank, the synthetic clinician caseload — still comes from
/// [MockData]. Only what the *user generates* is persisted.

/// `yyyy-mm-dd` for the day a snapshot belongs to.
String dayStampFor(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

class HivePatientRepository implements PatientRepository {
  HivePatientRepository(this._store);

  final HiveStore _store;
  static const String _key = 'active';

  @override
  Future<Patient?> current() async => _store.patients.get(_key);

  @override
  Future<Patient> load(String id) async => _store.patients.get(_key) ?? MockData.aama;

  @override
  Future<void> save(Patient patient) => _store.patients.put(_key, patient);

  @override
  Future<List<DailyQuestion>> dailyQuestions(Patient patient) async =>
      MockData.dailyQuestions(patient);
}

class HiveGameRepository implements GameRepository {
  HiveGameRepository(this._store);

  final HiveStore _store;

  @override
  Future<List<GameDefinition>> catalogue() async => MockData.games;

  @override
  Future<Map<GameId, int>> levels(String patientId) async {
    final Box<int> box = _store.levels;
    if (box.isEmpty) return <GameId, int>{};
    return <GameId, int>{
      for (final GameId id in GameId.values)
        if (box.get(id.name) != null) id: box.get(id.name)!,
    };
  }

  @override
  Future<void> saveLevel(String patientId, GameId id, int level) =>
      _store.levels.put(id.name, level);

  /// Sessions are keyed newest-first by a descending millisecond stamp, so
  /// `box.values` comes back in display order without a sort on every read.
  @override
  Future<void> recordSession(String patientId, GameSession session) async {
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    await _store.sessions.put('${0x7FFFFFFFFFFFF - stamp}_${session.gameId.name}', session);
    await _store.levels.put(session.gameId.name, session.level);
  }

  @override
  Future<List<GameSession>> history(String patientId) async {
    final List<String> keys = _store.sessions.keys.cast<String>().toList()..sort();
    return <GameSession>[
      for (final String k in keys)
        if (_store.sessions.get(k) != null) _store.sessions.get(k)!,
    ];
  }
}

class HiveAnalyticsRepository implements AnalyticsRepository {
  HiveAnalyticsRepository(this._store);

  final HiveStore _store;
  static const String _key = 'active';

  @override
  Future<CognitiveProfile> profile(String patientId) async =>
      _store.cognitiveProfile.get(_key) ?? MockData.aamaProfile();

  @override
  Future<void> saveProfile(String patientId, CognitiveProfile profile) =>
      _store.cognitiveProfile.put(_key, profile);

  // The weekly series and the clinician caseload are synthetic demo data with
  // no user-generated component, so they are not persisted.
  @override
  Future<List<SeriesPoint>> weeklyEngagement(String patientId) async =>
      MockData.series(MockData.weeklyEngagement);

  @override
  Future<List<SeriesPoint>> weeklyGames(String patientId) async =>
      MockData.series(MockData.weeklyGames);

  @override
  Future<List<SeriesPoint>> weeklyAdherence(String patientId) async =>
      MockData.series(MockData.weeklyAdherence);

  @override
  Future<List<ClinicPatient>> caseload() async => MockData.caseload();

  @override
  Future<List<DoctorAlert>> alerts() async => MockData.alerts();
}

class HiveReminderRepository implements ReminderRepository {
  HiveReminderRepository(this._store);

  final HiveStore _store;

  @override
  Future<void> seedIfEmpty(List<Reminder> reminders) async {
    final Box<Reminder> box = _store.reminders;
    // A stored day older than today means yesterday's ticks must not carry
    // over: the schedule is rewritten, the done flags start clean.
    final String today = dayStampFor(DateTime.now());
    final String? storedDay = _store.daily.get('reminders_day') as String?;
    if (box.isEmpty || storedDay != today) {
      await box.clear();
      await box.putAll(<String, Reminder>{
        for (final Reminder r in reminders) r.id: r,
      });
      await _store.daily.put('reminders_day', today);
    }
  }

  @override
  Future<List<Reminder>> today(String patientId) async {
    final List<Reminder> list = _store.reminders.values.toList();
    list.sort((Reminder a, Reminder b) =>
        a.minutesFromMidnight.compareTo(b.minutesFromMidnight));
    return list;
  }

  @override
  Future<void> setDone(String reminderId, bool done) async {
    final Reminder? existing = _store.reminders.get(reminderId);
    if (existing == null) return;
    await _store.reminders.put(reminderId, existing.copyWith(done: done));
  }
}

class HiveDailyRepository implements DailyRepository {
  HiveDailyRepository(this._store);

  final HiveStore _store;

  static const String _kDay = 'day';
  static const String _kMood = 'mood';
  static const String _kAnswered = 'answered';
  static const String _kJourney = 'journey';
  static const String _kCompleted = 'completed';
  static const String _kEngagement = 'engagement';

  /// Clears the day's boxes when the stored snapshot belongs to a past day.
  Future<void> _rollOverIfNeeded() async {
    final String today = dayStampFor(DateTime.now());
    if (_store.daily.get(_kDay) == today) return;
    await _store.journal.clear();
    await _store.daily.delete(_kMood);
    await _store.daily.delete(_kAnswered);
    await _store.daily.delete(_kJourney);
    await _store.daily.delete(_kCompleted);
    await _store.daily.delete(_kEngagement);
    await _store.daily.put(_kDay, today);
  }

  @override
  Future<DailySnapshot> load(String patientId) async {
    await _rollOverIfNeeded();
    final Box<dynamic> d = _store.daily;
    final String? moodName = d.get(_kMood) as String?;
    return DailySnapshot(
      mood: moodName == null
          ? null
          : MoodLevel.values.firstWhere(
              (MoodLevel m) => m.name == moodName,
              orElse: () => MoodLevel.okay,
            ),
      journal: _store.journal.values.toList(growable: false),
      answeredQuestions: _stringSet(d.get(_kAnswered)),
      journeyDone: _stringSet(d.get(_kJourney)),
      completedGameIds: _stringSet(d.get(_kCompleted)),
      engagement: d.get(_kEngagement) as int? ?? 78,
      dayStamp: d.get(_kDay) as String?,
    );
  }

  Set<String> _stringSet(dynamic raw) =>
      (raw as List<dynamic>?)?.map((dynamic e) => e.toString()).toSet() ?? <String>{};

  Future<void> _addTo(String key, String value) async {
    final Set<String> set = _stringSet(_store.daily.get(key))..add(value);
    await _store.daily.put(key, set.toList(growable: false));
  }

  @override
  Future<void> saveMood(String patientId, MoodLevel mood) =>
      _store.daily.put(_kMood, mood.name);

  @override
  Future<void> addJournalEntry(
      String patientId, JournalEntry entry, String questionId) async {
    await _store.journal.add(entry);
    await _addTo(_kAnswered, questionId);
  }

  @override
  Future<void> markJourneyStep(String patientId, String step) => _addTo(_kJourney, step);

  @override
  Future<void> markGameCompleted(String patientId, GameId id) =>
      _addTo(_kCompleted, id.name);

  @override
  Future<void> saveEngagement(String patientId, int engagement) =>
      _store.daily.put(_kEngagement, engagement);
}

class HiveAssessmentRepository implements AssessmentRepository {
  HiveAssessmentRepository(this._store);

  final HiveStore _store;

  String _intakeKey(String patientId) => 'intake:$patientId';
  String _baselineKey(String patientId) => 'baseline:$patientId';

  @override
  Future<IntakeRecord?> intake(String patientId) async {
    final Object? raw = _store.assessment.get(_intakeKey(patientId));
    if (raw is! Map) return null;
    return IntakeRecord.fromJson(raw);
  }

  @override
  Future<void> saveIntake(String patientId, IntakeRecord record) =>
      _store.assessment.put(_intakeKey(patientId), record.toJson());

  @override
  Future<CognitiveBaseline?> baseline(String patientId) async {
    final Object? raw = _store.assessment.get(_baselineKey(patientId));
    if (raw is! Map) return null;
    return CognitiveBaseline.fromJson(raw);
  }

  @override
  Future<void> saveBaseline(String patientId, CognitiveBaseline baseline) =>
      _store.assessment.put(_baselineKey(patientId), baseline.toJson());
}

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(this._store);

  final HiveStore _store;

  @override
  Future<AppSettings> load() async {
    final Box<dynamic> b = _store.settings;
    final String? size = b.get('textSize') as String?;
    return AppSettings(
      textSize: TextSizePreference.values.firstWhere(
        (TextSizePreference t) => t.name == size,
        orElse: () => TextSizePreference.large,
      ),
      highContrast: b.get('highContrast') as bool? ?? false,
      reduceMotion: b.get('reduceMotion') as bool? ?? false,
      voicePrompts: b.get('voicePrompts') as bool? ?? true,
      offlineOverride: b.get('offlineOverride') as bool? ?? false,
      lastRole: b.get('lastRole') as String?,
      lastAccountId: b.get('lastAccountId') as String?,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _store.settings.putAll(<String, dynamic>{
      'textSize': settings.textSize.name,
      'highContrast': settings.highContrast,
      'reduceMotion': settings.reduceMotion,
      'voicePrompts': settings.voicePrompts,
      'offlineOverride': settings.offlineOverride,
      if (settings.lastRole != null) 'lastRole': settings.lastRole,
      if (settings.lastAccountId != null) 'lastAccountId': settings.lastAccountId,
    });
    // A null account means "signed out", which has to *remove* the key —
    // skipping the write would leave the previous uid in the box and reopen
    // someone else's assessment on the next launch.
    if (settings.lastAccountId == null) await _store.settings.delete('lastAccountId');
  }
}

class HiveSyncRepository implements SyncRepository {
  HiveSyncRepository(this._store);

  final HiveStore _store;

  @override
  Future<void> enqueue(PendingOperation operation) =>
      _store.syncQueue.put(operation.id, operation);

  @override
  Future<List<PendingOperation>> pending() async {
    final List<PendingOperation> list =
        _store.syncQueue.values.where((PendingOperation o) => o.isPending).toList();
    list.sort((PendingOperation a, PendingOperation b) =>
        a.createdAtMillis.compareTo(b.createdAtMillis));
    return list;
  }

  @override
  Future<List<PendingOperation>> all() async {
    final List<PendingOperation> list = _store.syncQueue.values.toList();
    list.sort((PendingOperation a, PendingOperation b) =>
        b.createdAtMillis.compareTo(a.createdAtMillis));
    return list;
  }

  @override
  Future<void> update(PendingOperation operation) =>
      _store.syncQueue.put(operation.id, operation);

  @override
  Future<void> purgeSynced() async {
    final List<dynamic> done = _store.syncQueue.keys
        .where((dynamic k) => _store.syncQueue.get(k)?.status == SyncStatus.synced)
        .toList();
    await _store.syncQueue.deleteAll(done);
  }
}
