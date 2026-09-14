import 'package:hive_ce/hive.dart';

import '../../core/models/assessment.dart';
import '../../core/models/caregiver_note.dart';
import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/memory_fragment.dart';
import '../../core/models/monitoring.dart';
import '../../core/models/mood_drawing.dart';
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

  /// Where the most recently used profile is mirrored, so a launch with no
  /// account still finds the last person who used the device.
  static const String _key = 'active';

  @override
  Future<Patient?> current() async => _store.patients.get(_key);

  /// Falls back to a *blank* profile, never to the sample one. Returning
  /// `MockData.aama` here is what used to make a fresh install open on
  /// somebody else's name and family: nothing had been saved yet, so every
  /// read came back as her.
  @override
  Future<Patient> load(String id) async =>
      _store.patients.get(id) ?? _store.patients.get(_key) ?? MockData.emptyPatient;

  @override
  Future<Patient?> byId(String id) async => _store.patients.get(id);

  /// Written twice on purpose: under the profile's own id, which is what makes
  /// two accounts on one phone two separate people, and under `active`, which
  /// is what an anonymous launch reads.
  @override
  Future<void> save(Patient patient) async {
    await _store.patients.put(patient.id, patient);
    await _store.patients.put(_key, patient);
  }

  @override
  Future<List<DailyQuestion>> dailyQuestions(Patient patient) async =>
      MockData.dailyQuestions(patient);
}

class HiveGameRepository implements GameRepository {
  HiveGameRepository(this._store);

  final HiveStore _store;

  /// Every key is prefixed with the profile it belongs to, so two accounts
  /// sharing a phone keep two separate histories. A key with no prefix is
  /// from before accounts existed and belongs to the anonymous profile.
  static String _scoped(String patientId, String key) => '$patientId|$key';
  static bool _belongsTo(String patientId, String key) => key.startsWith('$patientId|');

  @override
  Future<List<GameDefinition>> catalogue() async => MockData.games;

  @override
  Future<Map<GameId, int>> levels(String patientId) async {
    final Box<int> box = _store.levels;
    if (box.isEmpty) return <GameId, int>{};
    return <GameId, int>{
      for (final GameId id in GameId.values)
        if (box.get(_scoped(patientId, id.name)) != null)
          id: box.get(_scoped(patientId, id.name))!,
    };
  }

  @override
  Future<void> saveLevel(String patientId, GameId id, int level) =>
      _store.levels.put(_scoped(patientId, id.name), level);

  /// Sessions are keyed newest-first by a descending millisecond stamp, so
  /// `box.values` comes back in display order without a sort on every read.
  @override
  Future<void> recordSession(String patientId, GameSession session) async {
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    await _store.sessions.put(
      _scoped(patientId, '${0x7FFFFFFFFFFFF - stamp}_${session.gameId.name}'),
      session,
    );
    await _store.levels.put(_scoped(patientId, session.gameId.name), session.level);
  }

  @override
  Future<List<GameSession>> history(String patientId) async {
    final List<String> keys = _store.sessions.keys
        .cast<String>()
        .where((String k) => _belongsTo(patientId, k))
        .toList()
      ..sort();
    return <GameSession>[
      for (final String k in keys)
        if (_store.sessions.get(k) != null) _store.sessions.get(k)!,
    ];
  }
}

class HiveAnalyticsRepository implements AnalyticsRepository {
  HiveAnalyticsRepository(this._store);

  final HiveStore _store;

  @override
  Future<CognitiveProfile> profile(String patientId) async =>
      _store.cognitiveProfile.get(patientId) ??
      const CognitiveProfile(
        scores: <CognitiveDomain, int>{},
        overall: 0,
        updated: 'No activities yet',
      );

  @override
  Future<void> saveProfile(String patientId, CognitiveProfile profile) =>
      _store.cognitiveProfile.put(patientId, profile);

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

  @override
  Future<void> save(Reminder reminder) async {
    await _store.reminders.put(reminder.id, reminder);
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

  /// Today's mood, answers and journal are as personal as anything in the app,
  /// so they are filed under the profile rather than under the device.
  static String _scoped(String patientId, String key) => '$patientId|$key';

  /// Clears the day's boxes when the stored snapshot belongs to a past day.
  Future<void> _rollOverIfNeeded(String patientId) async {
    final String today = dayStampFor(DateTime.now());
    if (_store.daily.get(_scoped(patientId, _kDay)) == today) return;
    await _store.journal.deleteAll(_store.journal.keys
        .where((dynamic k) => k is String && k.startsWith('$patientId|'))
        .toList(growable: false));
    await _store.daily.delete(_scoped(patientId, _kMood));
    await _store.daily.delete(_scoped(patientId, _kAnswered));
    await _store.daily.delete(_scoped(patientId, _kJourney));
    await _store.daily.delete(_scoped(patientId, _kCompleted));
    await _store.daily.delete(_scoped(patientId, _kEngagement));
    await _store.daily.put(_scoped(patientId, _kDay), today);
  }

  @override
  Future<DailySnapshot> load(String patientId) async {
    await _rollOverIfNeeded(patientId);
    final Box<dynamic> d = _store.daily;
    final String? moodName = d.get(_scoped(patientId, _kMood)) as String?;
    return DailySnapshot(
      mood: moodName == null
          ? null
          : MoodLevel.values.firstWhere(
              (MoodLevel m) => m.name == moodName,
              orElse: () => MoodLevel.okay,
            ),
      journal: <JournalEntry>[
        for (final dynamic k in _store.journal.keys)
          if (k is String && k.startsWith('$patientId|') && _store.journal.get(k) != null)
            _store.journal.get(k)!,
      ],
      answeredQuestions: _stringSet(d.get(_scoped(patientId, _kAnswered))),
      journeyDone: _stringSet(d.get(_scoped(patientId, _kJourney))),
      completedGameIds: _stringSet(d.get(_scoped(patientId, _kCompleted))),
      engagement: d.get(_scoped(patientId, _kEngagement)) as int? ?? 0,
      dayStamp: d.get(_scoped(patientId, _kDay)) as String?,
    );
  }

  Set<String> _stringSet(dynamic raw) =>
      (raw as List<dynamic>?)?.map((dynamic e) => e.toString()).toSet() ?? <String>{};

  Future<void> _addTo(String patientId, String key, String value) async {
    final String scoped = _scoped(patientId, key);
    final Set<String> set = _stringSet(_store.daily.get(scoped))..add(value);
    await _store.daily.put(scoped, set.toList(growable: false));
  }

  @override
  Future<void> saveMood(String patientId, MoodLevel mood) =>
      _store.daily.put(_scoped(patientId, _kMood), mood.name);

  @override
  Future<void> addJournalEntry(
      String patientId, JournalEntry entry, String questionId) async {
    // Keyed rather than appended, so one person's journal can be read and
    // cleared without touching anyone else's.
    await _store.journal.put(
      _scoped(patientId, '${DateTime.now().microsecondsSinceEpoch}'),
      entry,
    );
    await _addTo(patientId, _kAnswered, questionId);
  }

  @override
  Future<void> markJourneyStep(String patientId, String step) =>
      _addTo(patientId, _kJourney, step);

  @override
  Future<void> markGameCompleted(String patientId, GameId id) =>
      _addTo(patientId, _kCompleted, id.name);

  @override
  Future<void> saveEngagement(String patientId, int engagement) =>
      _store.daily.put(_scoped(patientId, _kEngagement), engagement);
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

class HiveMemoryFragmentRepository implements MemoryFragmentRepository {
  HiveMemoryFragmentRepository(this._store);

  final HiveStore _store;

  String _key(String patientId, String fragmentId) => 'memory:$patientId:$fragmentId';
  String _prefix(String patientId) => 'memory:$patientId:';

  @override
  Future<List<MemoryFragment>> all(String patientId) async {
    final String prefix = _prefix(patientId);
    final List<MemoryFragment> out = <MemoryFragment>[];
    for (final dynamic key in _store.memories.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final Object? raw = _store.memories.get(key);
      if (raw is! Map) continue;
      final MemoryFragment? fragment = MemoryFragment.fromJson(raw);
      if (fragment != null) out.add(fragment);
    }
    out.sort((MemoryFragment a, MemoryFragment b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  @override
  Future<MemoryFragment> add(String patientId, MemoryFragment fragment) async {
    await _store.memories.put(_key(patientId, fragment.id), fragment.toJson());
    return fragment;
  }

  @override
  Future<void> markResurfaced(String patientId, String fragmentId, DateTime at) async {
    final String key = _key(patientId, fragmentId);
    final Object? raw = _store.memories.get(key);
    if (raw is! Map) return;
    final MemoryFragment? existing = MemoryFragment.fromJson(raw);
    if (existing == null) return;
    final MemoryFragment updated = existing.copyWith(
      lastResurfacedAt: at,
      timesResurfaced: existing.timesResurfaced + 1,
    );
    await _store.memories.put(key, updated.toJson());
  }
}

/// Same `patientId|key` scoping as [HiveGameRepository], so two accounts on
/// one device keep separate drawings.
class HiveMoodDrawingRepository implements MoodDrawingRepository {
  HiveMoodDrawingRepository(this._store);

  final HiveStore _store;

  static String _scoped(String patientId, String id) => '$patientId|$id';
  static bool _belongsTo(String patientId, String key) => key.startsWith('$patientId|');

  @override
  Future<List<MoodDrawing>> all(String patientId) async {
    // Ids are microsecond timestamps, so a plain descending sort of the keys
    // is newest-first without reading every row to compare a field.
    final List<String> keys = _store.moodDrawings.keys
        .cast<String>()
        .where((String k) => _belongsTo(patientId, k))
        .toList()
      ..sort((String a, String b) => b.compareTo(a));
    return <MoodDrawing>[
      for (final String k in keys)
        if (_store.moodDrawings.get(k) != null) _store.moodDrawings.get(k)!,
    ];
  }

  @override
  Future<MoodDrawing> add(String patientId, MoodDrawing drawing) async {
    await _store.moodDrawings.put(_scoped(patientId, drawing.id), drawing);
    return drawing;
  }

  @override
  Future<void> addDoctorNote(
    String patientId,
    String drawingId,
    String note, {
    required String notedBy,
    required String notedAtIso,
  }) async {
    final String key = _scoped(patientId, drawingId);
    final MoodDrawing? existing = _store.moodDrawings.get(key);
    if (existing == null) return;
    await _store.moodDrawings.put(
      key,
      existing.copyWith(doctorNote: note, notedBy: notedBy, notedAtIso: notedAtIso),
    );
  }
}

class HiveCaregiverNoteRepository implements CaregiverNoteRepository {
  HiveCaregiverNoteRepository(this._store);

  final HiveStore _store;

  static String _scoped(String patientId, String id) => '$patientId|$id';
  static bool _belongsTo(String patientId, String key) => key.startsWith('$patientId|');

  @override
  Future<List<CaregiverConcernUpdate>> concernUpdates(String patientId) async {
    return <CaregiverConcernUpdate>[
      for (final String k in _store.caregiverConcerns.keys.cast<String>())
        if (_belongsTo(patientId, k)) _store.caregiverConcerns.get(k)!,
    ];
  }

  @override
  Future<CaregiverConcernUpdate> addConcernUpdate(
      String patientId, CaregiverConcernUpdate update) async {
    await _store.caregiverConcerns.put(_scoped(patientId, update.id), update);
    return update;
  }

  @override
  Future<List<CaregiverNoteEntry>> notes(String patientId) async {
    return <CaregiverNoteEntry>[
      for (final String k in _store.caregiverNotes.keys.cast<String>())
        if (_belongsTo(patientId, k)) _store.caregiverNotes.get(k)!,
    ];
  }

  @override
  Future<CaregiverNoteEntry> addNote(String patientId, CaregiverNoteEntry note) async {
    await _store.caregiverNotes.put(_scoped(patientId, note.id), note);
    return note;
  }

  @override
  Future<void> clearCycle(String patientId) async {
    final Iterable<String> concernKeys = _store.caregiverConcerns.keys
        .cast<String>()
        .where((String k) => _belongsTo(patientId, k));
    final Iterable<String> noteKeys =
        _store.caregiverNotes.keys.cast<String>().where((String k) => _belongsTo(patientId, k));
    await _store.caregiverConcerns.deleteAll(concernKeys);
    await _store.caregiverNotes.deleteAll(noteKeys);
  }

  // The cycle boundary is one small value with one owner, so it rides in the
  // generic settings box (same reasoning as `AppSettings.safeZoneJson`)
  // rather than getting its own box and adapter.
  static String _cycleStartKey(String patientId) => 'weeklyCycleStart_$patientId';

  @override
  Future<DateTime?> loadCycleStart(String patientId) async {
    final int? millis = _store.settings.get(_cycleStartKey(patientId)) as int?;
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  @override
  Future<void> saveCycleStart(String patientId, DateTime start) async {
    await _store.settings.put(_cycleStartKey(patientId), start.millisecondsSinceEpoch);
  }
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
      safeZoneJson: b.get('safeZone') as String?,
      localeCode: b.get('localeCode') as String?,
      patientUsername: b.get('patientUsername') as String?,
      pendingPairingRequestId: b.get('pendingPairingRequestId') as String?,
      accountRolesJson: b.get('accountRoles') as String?,
      registeredDoctorsJson: b.get('registeredDoctors') as String?,
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
      if (settings.safeZoneJson != null) 'safeZone': settings.safeZoneJson,
      if (settings.localeCode != null) 'localeCode': settings.localeCode,
      if (settings.patientUsername != null) 'patientUsername': settings.patientUsername,
      if (settings.pendingPairingRequestId != null)
        'pendingPairingRequestId': settings.pendingPairingRequestId,
      if (settings.accountRolesJson != null) 'accountRoles': settings.accountRolesJson,
      if (settings.registeredDoctorsJson != null)
        'registeredDoctors': settings.registeredDoctorsJson,
    });
    // `putAll` cannot express "remove this": a key left out of the map simply
    // keeps whatever it held. So every nullable setting has to be deleted
    // explicitly when it is null, or signing out leaves the old value behind
    // and the next launch reads it back as if nothing had happened.
    //
    // This is not hypothetical. `lastRole` was written but never deleted, so
    // a caregiver who logged out was still restored *as a caregiver* on the
    // next launch — straight past the greeting, the role picker and the
    // sign-in screen behind them.
    for (final MapEntry<String, Object?> nullable in <String, Object?>{
      'lastAccountId': settings.lastAccountId,
      'lastRole': settings.lastRole,
      'accountRoles': settings.accountRolesJson,
      'registeredDoctors': settings.registeredDoctorsJson,
      'patientUsername': settings.patientUsername,
      'pendingPairingRequestId': settings.pendingPairingRequestId,
      'safeZone': settings.safeZoneJson,
      'localeCode': settings.localeCode,
    }.entries) {
      if (nullable.value == null) await _store.settings.delete(nullable.key);
    }
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
