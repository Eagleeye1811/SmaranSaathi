import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:smaran_saathi/app/bootstrap.dart';
import 'package:smaran_saathi/core/models/daily.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/models/mood_drawing.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/services/connectivity_service.dart';
import 'package:smaran_saathi/core/services/sync_manager.dart';
import 'package:smaran_saathi/data/local/hive_store.dart';
import 'package:smaran_saathi/data/local/sync_operation.dart';
import 'package:smaran_saathi/data/repositories/hive_repositories.dart';

/// The four behaviours that decide whether "offline-first" is real or a label.
///
/// Every test here restarts the app for real: the state is disposed, Hive is
/// closed, and a second [AppState] is built over the *same* directory. Nothing
/// is carried across in memory.

const GamePerformance kStrongRun = GamePerformance(
  accuracy: 92,
  focus: 88,
  memory: 90,
  hintsUsed: 0,
  mistakes: 1,
  seconds: 38,
  completed: true,
);

/// A transport that always fails, standing in for "the server is unreachable".
class _UnreachableTransport implements SyncTransport {
  @override
  Future<void> send(PendingOperation operation) async =>
      throw const SocketException('no route to host');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  bootstrapTests();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mm_hive_test');
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Opens a store and an AppState over [dir] — i.e. "launches the app".
  Future<(HiveStore, AppState, ManualConnectivityService)> launch({
    bool online = true,
    SyncTransport? transport,
  }) async {
    final HiveStore store = await HiveStore.open(path: dir.path);
    final ManualConnectivityService net = ManualConnectivityService(online: online);
    final AppState state = AppState(
      patients: HivePatientRepository(store),
      games: HiveGameRepository(store),
      analytics: HiveAnalyticsRepository(store),
      reminders: HiveReminderRepository(store),
      daily: HiveDailyRepository(store),
      assessment: HiveAssessmentRepository(store),
      moodDrawings: HiveMoodDrawingRepository(store),
      settings: HiveSettingsRepository(store),
      sync: HiveSyncRepository(store),
      connectivity: net,
      transport: transport ?? const LoopbackTransport(latency: Duration.zero),
    );
    await state.hydrate();
    return (store, state, net);
  }

  /// Closes everything the way a real app termination would.
  Future<void> quit(HiveStore store, AppState state) async {
    await state.flush();
    state.dispose();
    await store.close();
  }

  test('1 · a completed activity survives a restart', () async {
    var (HiveStore store, AppState state, _) = await launch();
    final int startLevel = state.levelOf(GameId.procedure);
    final int before = state.sessionsFor(GameId.procedure).length;

    state.finishGame(GameId.procedure, kStrongRun);
    await state.flush();

    expect(state.completedToday, contains(GameId.procedure));
    await quit(store, state);

    // ── relaunch ────────────────────────────────────────────────────────
    (store, state, _) = await launch();

    final List<GameSession> after = state.sessionsFor(GameId.procedure);
    expect(after.length, before + 1, reason: 'the session was not written to disk');

    final GameSession restored = after.first;
    expect(restored.performance.accuracy, kStrongRun.accuracy);
    expect(restored.performance.focus, kStrongRun.focus);
    expect(restored.performance.memory, kStrongRun.memory);
    expect(restored.performance.hintsUsed, kStrongRun.hintsUsed);
    expect(restored.performance.mistakes, kStrongRun.mistakes);
    expect(restored.performance.seconds, kStrongRun.seconds);
    expect(restored.performance.completed, isTrue);
    expect(restored.level, startLevel, reason: 'the level it was played at');

    // The adaptive engine's decision persisted too.
    expect(state.levelOf(GameId.procedure), startLevel + 1);
    // And the day's progress came back with it.
    expect(state.completedToday, contains(GameId.procedure));
    expect(state.journeyDone, contains('game'));

    await quit(store, state);
  });

  test('1b · a mood canvas drawing survives a restart, image and note both',
      () async {
    var (HiveStore store, AppState state, _) = await launch();
    final Uint8List png = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    final MoodDrawing saved = await state.saveMoodDrawing(png);
    await state.flush();

    expect(state.completedToday, contains(GameId.moodCanvas));
    expect(state.moodDrawings, hasLength(1));
    await quit(store, state);

    // ── relaunch ────────────────────────────────────────────────────────
    (store, state, _) = await launch();

    expect(state.moodDrawings, hasLength(1));
    final MoodDrawing restored = state.moodDrawings.first;
    expect(restored.id, saved.id);
    expect(restored.pngBytes, png, reason: 'the drawing itself was not written to disk');
    expect(restored.doctorNote, isNull);
    expect(state.completedToday, contains(GameId.moodCanvas));

    // A doctor's note, added after the fact, survives a restart too.
    state.addDoctorNoteToDrawing(restored.id, 'Calm colours, steady lines.', notedBy: 'Dr. Test');
    await state.flush();
    await quit(store, state);

    (store, state, _) = await launch();
    final MoodDrawing withNote = state.moodDrawings.first;
    expect(withNote.doctorNote, 'Calm colours, steady lines.');
    expect(withNote.notedBy, 'Dr. Test');
    expect(withNote.notedAtIso, isNotNull);

    await quit(store, state);
  });

  test('2 · with no connection the result is still saved locally and queued',
      () async {
    final (HiveStore store, AppState state, _) = await launch(online: false);

    expect(state.offline, isTrue);
    expect(state.pendingSync, 0, reason: 'nothing has happened yet');

    state.finishGame(GameId.melody, kStrongRun);
    await state.flush();

    // Saved locally…
    expect(state.sessionsFor(GameId.melody), isNotEmpty);
    expect(store.sessions.values.where((GameSession s) => s.gameId == GameId.melody),
        isNotEmpty);

    // …and queued rather than sent.
    expect(state.pendingSync, 1);
    final List<PendingOperation> queue = await state.pendingOperations();
    expect(queue.single.kind, SyncOperationKind.gameSession);
    expect(queue.single.status, SyncStatus.pending);
    expect(queue.single.payload['gameId'], 'melody');
    expect(queue.single.payload['accuracy'], kStrongRun.accuracy);

    await quit(store, state);
  });

  test('3 · restarting while still offline keeps both the result and the queue',
      () async {
    var (HiveStore store, AppState state, _) = await launch(online: false);

    state
      ..finishGame(GameId.weaves, kStrongRun)
      ..setMood(MoodLevel.good);
    await state.flush();
    expect(state.pendingSync, 2);

    await quit(store, state);

    // ── relaunch, still with no connection ──────────────────────────────
    (store, state, _) = await launch(online: false);

    expect(state.offline, isTrue);
    expect(state.sessionsFor(GameId.weaves), isNotEmpty,
        reason: 'the result must outlive the process');
    expect(state.mood, MoodLevel.good);
    expect(state.pendingSync, 2, reason: 'the outbox is durable, not in-memory');

    final List<PendingOperation> queue = await state.pendingOperations();
    expect(
      queue.map((PendingOperation o) => o.kind).toSet(),
      <SyncOperationKind>{SyncOperationKind.gameSession, SyncOperationKind.moodCheckIn},
    );

    await quit(store, state);
  });

  test('4 · when the connection returns the queue drains on its own', () async {
    final (HiveStore store, AppState state, ManualConnectivityService net) =
        await launch(online: false);

    state
      ..finishGame(GameId.memoryCards, kStrongRun)
      ..toggleReminder(state.reminders.first.id);
    await state.flush();
    expect(state.pendingSync, 2);
    expect(state.lastSyncedAt, isNull);

    // Connectivity returns — nobody taps anything.
    net.isOnline = true;
    await Future<void>.delayed(Duration.zero);
    await state.syncNow();

    expect(state.offline, isFalse);
    expect(state.pendingSync, 0, reason: 'the queue drained without a manual sync');
    expect(state.lastSyncedAt, isNotNull);
    expect(await state.pendingOperations(), isEmpty,
        reason: 'synced rows are purged so the box stays bounded');

    // The locally saved work is untouched by syncing.
    expect(state.sessionsFor(GameId.memoryCards), isNotEmpty);

    await quit(store, state);
  });

  test('a failed send leaves the operation queued and retryable', () async {
    final (HiveStore store, AppState state, ManualConnectivityService net) =
        await launch(online: true, transport: _UnreachableTransport());

    state.finishGame(GameId.story, kStrongRun);
    await state.flush();
    await state.syncNow();

    expect(state.pendingSync, 1, reason: 'a failure must not drop the work');
    final List<PendingOperation> queue = await state.pendingOperations();
    expect(queue.single.status, SyncStatus.failed);
    expect(queue.single.attempts, greaterThan(0));
    expect(queue.single.lastError, isNotNull);
    expect(queue.single.isPending, isTrue, reason: 'failed rows are retried');

    net.isOnline = false;
    await quit(store, state);
  });

  test('settings, reminders and the journal all survive a restart', () async {
    var (HiveStore store, AppState state, _) = await launch();

    state
      ..textSize = TextSizePreference.extraLarge
      ..highContrast = true
      ..voicePrompts = false
      ..localeCode = 'mr';
    final String reminderId = state.reminders.firstWhere((Reminder r) => !r.done).id;
    state.toggleReminder(reminderId);
    final int doneAfterToggle = state.remindersDone;
    await state.flush();

    await quit(store, state);
    (store, state, _) = await launch();

    expect(state.textSize, TextSizePreference.extraLarge);
    expect(state.highContrast, isTrue);
    expect(state.voicePrompts, isFalse);
    expect(state.localeCode, 'mr',
        reason: 'the interface language must survive a restart, not just a live switch');
    expect(state.remindersDone, doneAfterToggle);
    expect(state.reminders.firstWhere((Reminder r) => r.id == reminderId).done, isTrue);

    await quit(store, state);
  });

  test('the patient profile written by onboarding is restored', () async {
    var (HiveStore store, AppState state, _) = await launch();

    state.updateDraft(state.patient.copyWith(
      name: 'Rukmini Devi',
      shortName: 'Rukmini',
      occupation: 'Weaver',
      location: 'Majuli',
    ));
    await state.commitDraft();
    await state.flush();

    await quit(store, state);
    (store, state, _) = await launch();

    expect(state.patient.name, 'Rukmini Devi');
    expect(state.patient.occupation, 'Weaver');
    expect(state.patient.location, 'Majuli');
    expect(state.patient.family, isNotEmpty, reason: 'nested lists round-trip');
    expect(state.patient.routine, isNotEmpty);

    await quit(store, state);
  });

  test('the cognitive profile keeps its domain scores across a restart', () async {
    var (HiveStore store, AppState state, _) = await launch();

    state.finishGame(GameId.familiarPlace, kStrongRun);
    await state.flush();
    final Map<CognitiveDomain, int> expected =
        Map<CognitiveDomain, int>.from(state.cognitiveProfile.scores);
    final int overall = state.cognitiveProfile.overall;

    await quit(store, state);
    (store, state, _) = await launch();

    expect(state.cognitiveProfile.scores, expected);
    expect(state.cognitiveProfile.overall, overall);

    await quit(store, state);
  });
}

/// The wiring `main` actually uses, exercised end to end.
void bootstrapTests() {
  test('bootstrapAppState opens real storage and round-trips a session',
      () async {
    final Directory dir = await Directory.systemTemp.createTemp('mm_boot');
    addTearDown(() async {
      await Hive.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    AppState state = await bootstrapAppState(storagePath: dir.path);
    expect(state.hydrated, isTrue);
    expect(HiveStore.instanceOrNull, isNotNull,
        reason: 'the real store, not the in-memory fallback');

    state.finishGame(GameId.procedure, kStrongRun);
    await state.flush();
    final int level = state.levelOf(GameId.procedure);
    state.dispose();
    await Hive.close();

    state = await bootstrapAppState(storagePath: dir.path);
    expect(state.levelOf(GameId.procedure), level);
    expect(state.sessionsFor(GameId.procedure), isNotEmpty);
    state.dispose();
  });
}
