import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/patient.dart';
import 'adapters.dart';
import 'sync_operation.dart';

/// Owns Hive's lifecycle: adapter registration, box names, opening and closing.
///
/// Nothing above the repository layer talks to this class, and no screen ever
/// imports Hive. A repository receives an already-open [HiveStore] and reads
/// its boxes through the typed getters below.
class HiveStore {
  HiveStore._();

  /// Boxes. Names are part of the on-disk contract — do not rename.
  static const String patientsBox = 'mm_patients';
  static const String sessionsBox = 'mm_sessions';
  static const String levelsBox = 'mm_levels';
  static const String profileBox = 'mm_cognitive_profile';
  static const String journalBox = 'mm_journal';
  static const String dailyBox = 'mm_daily';
  static const String remindersBox = 'mm_reminders';
  static const String settingsBox = 'mm_settings';
  static const String syncQueueBox = 'mm_sync_queue';

  /// The structured intake and the cognitive baseline. Stored as plain JSON
  /// maps rather than through a typed adapter: the assessment models change
  /// shape as the questionnaire is refined, and a map tolerates a new field
  /// where a fixed adapter would need a new type id every time.
  static const String assessmentBox = 'mm_assessment';

  static bool _adaptersRegistered = false;
  static HiveStore? _instance;

  /// The open store, or null when the app is running purely in memory.
  static HiveStore? get instanceOrNull => _instance;

  bool _open = false;
  bool get isOpen => _open;

  /// Registers every adapter exactly once. Safe to call repeatedly — Hive
  /// throws on a duplicate type id, and tests open and close the store often.
  static void registerAdapters() {
    if (_adaptersRegistered) return;
    Hive
      ..registerAdapter(FamilyMemberAdapter())
      ..registerAdapter(MemoryAssetAdapter())
      ..registerAdapter(LifeMemoryAdapter())
      ..registerAdapter(RoutineItemAdapter())
      ..registerAdapter(PatientAdapter())
      ..registerAdapter(GamePerformanceAdapter())
      ..registerAdapter(GameSessionAdapter())
      ..registerAdapter(CognitiveProfileAdapter())
      ..registerAdapter(JournalEntryAdapter())
      ..registerAdapter(ReminderAdapter())
      ..registerAdapter(PendingOperationAdapter())
      ..registerAdapter(EnumAdapter<MemoryAssetKind>(
          HiveTypeIds.memoryAssetKind, MemoryAssetKind.values, MemoryAssetKind.object))
      ..registerAdapter(EnumAdapter<RoutineKind>(
          HiveTypeIds.routineKind, RoutineKind.values, RoutineKind.activity))
      ..registerAdapter(
          EnumAdapter<GameId>(HiveTypeIds.gameId, GameId.values, GameId.procedure))
      ..registerAdapter(EnumAdapter<CognitiveDomain>(
          HiveTypeIds.cognitiveDomain, CognitiveDomain.values, CognitiveDomain.memory))
      ..registerAdapter(
          EnumAdapter<MoodLevel>(HiveTypeIds.moodLevel, MoodLevel.values, MoodLevel.okay))
      ..registerAdapter(EnumAdapter<ReminderKind>(
          HiveTypeIds.reminderKind, ReminderKind.values, ReminderKind.routine))
      ..registerAdapter(EnumAdapter<SyncOperationKind>(HiveTypeIds.syncOperationKind,
          SyncOperationKind.values, SyncOperationKind.unknown))
      ..registerAdapter(EnumAdapter<SyncStatus>(
          HiveTypeIds.syncStatus, SyncStatus.values, SyncStatus.pending));
    _adaptersRegistered = true;
  }

  /// Opens every box the app uses.
  ///
  /// [path] is for tests and headless tools — pass a temp directory. In the
  /// app leave it null so `Hive.initFlutter` picks the platform's documents
  /// directory (and IndexedDB on the web, where a path is meaningless).
  static Future<HiveStore> open({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }
    registerAdapters();

    final HiveStore store = HiveStore._();
    await Future.wait<void>(<Future<void>>[
      Hive.openBox<Patient>(patientsBox),
      Hive.openBox<GameSession>(sessionsBox),
      Hive.openBox<int>(levelsBox),
      Hive.openBox<CognitiveProfile>(profileBox),
      Hive.openBox<JournalEntry>(journalBox),
      Hive.openBox<dynamic>(dailyBox),
      Hive.openBox<Reminder>(remindersBox),
      Hive.openBox<dynamic>(settingsBox),
      Hive.openBox<PendingOperation>(syncQueueBox),
      Hive.openBox<dynamic>(assessmentBox),
    ]);
    store._open = true;
    _instance = store;
    return store;
  }

  /// Opens the store, returning null instead of throwing if the platform
  /// refuses (a locked directory, a browser with storage disabled). The app
  /// then runs in memory rather than refusing to start.
  static Future<HiveStore?> tryOpen({String? path}) async {
    try {
      return await open(path: path);
    } catch (error, stack) {
      debugPrint('HiveStore: local storage unavailable, running in memory ($error)');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Box<Patient> get patients => Hive.box<Patient>(patientsBox);
  Box<GameSession> get sessions => Hive.box<GameSession>(sessionsBox);
  Box<int> get levels => Hive.box<int>(levelsBox);
  Box<CognitiveProfile> get cognitiveProfile => Hive.box<CognitiveProfile>(profileBox);
  Box<JournalEntry> get journal => Hive.box<JournalEntry>(journalBox);
  Box<dynamic> get daily => Hive.box<dynamic>(dailyBox);
  Box<Reminder> get reminders => Hive.box<Reminder>(remindersBox);
  Box<dynamic> get settings => Hive.box<dynamic>(settingsBox);
  Box<PendingOperation> get syncQueue => Hive.box<PendingOperation>(syncQueueBox);
  Box<dynamic> get assessment => Hive.box<dynamic>(assessmentBox);

  Future<void> close() async {
    _open = false;
    if (identical(_instance, this)) _instance = null;
    await Hive.close();
  }

  /// Wipes every box. Used by the "reset demo" action and by tests.
  Future<void> clear() async {
    await Future.wait<void>(<Future<void>>[
      patients.clear(),
      sessions.clear(),
      levels.clear(),
      cognitiveProfile.clear(),
      journal.clear(),
      daily.clear(),
      reminders.clear(),
      settings.clear(),
      syncQueue.clear(),
      assessment.clear(),
    ]);
  }
}
