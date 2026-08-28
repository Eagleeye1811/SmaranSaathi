import 'package:flutter/foundation.dart';

import '../core/services/app_state.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/http_sync_transport.dart';
import '../core/services/sync_manager.dart';
import '../data/local/hive_store.dart';
import '../data/repositories/hive_repositories.dart';

/// Set via `--dart-define=MM_SYNC_BASE_URL=http://10.0.2.2:8000` (Android
/// emulator) or `http://127.0.0.1:8000` (web/desktop/iOS simulator) to point
/// the app at a real backend. Empty (the default) keeps today's behaviour
/// byte-for-byte — [AppState]'s own default transport, [LoopbackTransport],
/// is used — so building without this flag is unaffected by Phase 3 existing
/// at all.
const String _syncBaseUrl = String.fromEnvironment('MM_SYNC_BASE_URL');

/// Builds the app's state with local persistence wired in.
///
/// If Hive cannot be opened — a locked profile directory, a browser with site
/// data disabled — the app falls back to an in-memory session rather than
/// refusing to start. A caregiver in a clinic with a misconfigured device
/// should still be able to run today's activities; they just will not survive
/// a restart, and [AppState.hydrated] reports that.
Future<AppState> bootstrapAppState({String? storagePath}) async {
  final SyncTransport? transport = _syncBaseUrl.isEmpty ? null : HttpSyncTransport(baseUrl: _syncBaseUrl);

  final HiveStore? store = await HiveStore.tryOpen(path: storagePath);

  if (store == null) {
    final AppState fallback = AppState(transport: transport);
    await fallback.hydrate();
    return fallback;
  }

  final AppState state = AppState(
    patients: HivePatientRepository(store),
    games: HiveGameRepository(store),
    analytics: HiveAnalyticsRepository(store),
    reminders: HiveReminderRepository(store),
    daily: HiveDailyRepository(store),
    settings: HiveSettingsRepository(store),
    sync: HiveSyncRepository(store),
    connectivity: _connectivityForPlatform(),
    transport: transport,
  );

  await state.hydrate();
  return state;
}

/// Real connectivity everywhere the plugin works. Tests and headless runs pass
/// their own service into [AppState] instead of going through here.
ConnectivityService _connectivityForPlatform() {
  try {
    return PlatformConnectivityService();
  } catch (error) {
    debugPrint('bootstrap: connectivity unavailable, assuming online ($error)');
    return ManualConnectivityService();
  }
}
