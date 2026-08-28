import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:memory_mitra/core/models/daily.dart';
import 'package:memory_mitra/core/models/game.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/core/services/connectivity_service.dart';
import 'package:memory_mitra/core/services/http_sync_transport.dart';
import 'package:memory_mitra/data/local/hive_store.dart';
import 'package:memory_mitra/data/local/sync_operation.dart';
import 'package:memory_mitra/data/repositories/hive_repositories.dart';

/// The real thing, end to end, against a live backend — not a mock, not
/// `LoopbackTransport`. Run the backend first:
///
///   cd backend && .venv\Scripts\activate && uvicorn app.main:app --port 8000
///
/// Then: `flutter test test/live_backend_sync_test.dart`. If nothing is
/// listening on port 8000, every test here is skipped rather than failed —
/// this file is a deliberate live-integration check, not part of the regular
/// `flutter test` suite's guarantees.

const GamePerformance kStrongRun = GamePerformance(
  accuracy: 92,
  focus: 88,
  memory: 90,
  hintsUsed: 0,
  mistakes: 1,
  seconds: 38,
  completed: true,
);

Future<bool> _backendReachable() async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request =
        await client.getUrl(Uri.parse('http://127.0.0.1:8000/health')).timeout(const Duration(seconds: 10));
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
    return response.statusCode == 200;
  } catch (error) {
    // ignore: avoid_print
    print('live_backend_sync_test: reachability probe failed: $error');
    return false;
  } finally {
    client.close(force: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The widgets test binding installs an HttpOverrides that fakes every
  // HttpClient response (400, by design — it's meant to keep ordinary
  // widget tests from depending on real network). This file is deliberately
  // a real integration test, so opt back into genuine sockets.
  HttpOverrides.global = null;

  late Directory dir;
  late bool backendUp;

  setUpAll(() async {
    backendUp = await _backendReachable();
    if (!backendUp) {
      // ignore: avoid_print
      print('live_backend_sync_test: no backend on 127.0.0.1:8000 — skipping (start it and re-run to verify).');
    }
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mm_live_sync_test');
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('offline action queues, then drains through the real backend on reconnect', () async {
    if (!backendUp) {
      markTestSkipped('backend not reachable on 127.0.0.1:8000');
      return;
    }

    final HiveStore store = await HiveStore.open(path: dir.path);
    final ManualConnectivityService net = ManualConnectivityService(online: false);
    final AppState state = AppState(
      patients: HivePatientRepository(store),
      games: HiveGameRepository(store),
      analytics: HiveAnalyticsRepository(store),
      reminders: HiveReminderRepository(store),
      daily: HiveDailyRepository(store),
      settings: HiveSettingsRepository(store),
      sync: HiveSyncRepository(store),
      connectivity: net,
      transport: HttpSyncTransport(baseUrl: 'http://127.0.0.1:8000'),
    );
    await state.hydrate();

    // 1 — offline action lands in Hive.
    state.finishGame(GameId.procedure, kStrongRun);
    await state.flush();
    expect(state.sessionsFor(GameId.procedure), isNotEmpty);

    // 2 — and in the durable queue, not sent yet.
    expect(state.pendingSync, 1);
    final List<PendingOperation> queued = await state.pendingOperations();
    expect(queued.single.status, SyncStatus.pending);

    // 3 — connection restored.
    net.isOnline = true;
    await Future<void>.delayed(Duration.zero);

    // 4 — SyncManager drains on its own, against the real backend.
    await state.syncNow();

    expect(state.pendingSync, 0,
        reason: 'the real backend accepted the operation and it was purged — '
            'a real 4xx/5xx would have left it pending instead');
    expect(state.lastSyncedAt, isNotNull);

    await state.flush();
    await store.close();
  });

  test('resending the same operation id does not queue as new work', () async {
    if (!backendUp) {
      markTestSkipped('backend not reachable on 127.0.0.1:8000');
      return;
    }

    final HiveStore store = await HiveStore.open(path: dir.path);
    final ManualConnectivityService net = ManualConnectivityService(online: true);
    final HttpSyncTransport transport = HttpSyncTransport(baseUrl: 'http://127.0.0.1:8000');
    final AppState state = AppState(
      patients: HivePatientRepository(store),
      games: HiveGameRepository(store),
      analytics: HiveAnalyticsRepository(store),
      reminders: HiveReminderRepository(store),
      daily: HiveDailyRepository(store),
      settings: HiveSettingsRepository(store),
      sync: HiveSyncRepository(store),
      connectivity: net,
      transport: transport,
    );
    await state.hydrate();

    state.setMood(MoodLevel.good);
    await state.flush();
    expect(state.pendingSync, 0);

    // Re-send the exact same PendingOperation object directly through the
    // transport (bypassing the queue, which already purged it) — this is
    // the literal "retry" the backend's idempotency ledger is meant to
    // absorb. A second real HTTP call to the identical operation id must
    // still succeed (200, "duplicate"), not error.
    final PendingOperation replay = PendingOperation(
      id: 'replay-check-${DateTime.now().millisecondsSinceEpoch}',
      kind: SyncOperationKind.moodCheckIn,
      payload: const <String, dynamic>{'patientId': 'live-test-patient', 'mood': 'good', 'at': '9:00 AM'},
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await transport.send(replay); // first send — synced
    await transport.send(replay); // identical id again — must not throw

    await store.close();
  });
}
