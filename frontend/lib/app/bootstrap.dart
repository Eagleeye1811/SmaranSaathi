import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/services/app_state.dart';
import '../core/services/auth_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/firebase_auth_service.dart';
import '../core/services/http_sync_transport.dart';
import '../core/services/pairing_service.dart';
import '../core/services/sync_manager.dart';
import '../core/services/notification_service.dart';
import '../data/local/hive_store.dart';
import '../data/repositories/hive_repositories.dart';
import '../firebase_options.dart';

/// Override with `--dart-define=MM_SYNC_BASE_URL=...` when you want a
/// *different* backend than the deployed one below — e.g.
/// `http://10.0.2.2:8000` (Android emulator) or `http://127.0.0.1:8000`
/// (web/desktop/a physical device, after `adb reverse tcp:8000 tcp:8000`) to
/// point at a backend running on your own machine instead. The same URL
/// doubles as the backend base for [bootstrapAuth]'s `POST /api/v1/auth/role`
/// / `GET /api/v1/auth/me` calls.
const String _configuredSyncBaseUrl = String.fromEnvironment('MM_SYNC_BASE_URL');

/// The real, deployed backend (Render) — not a secret, just a public API
/// endpoint, so hardcoding it as the default is safe (unlike e.g.
/// GEMINI_API_KEY). This is what a plain `flutter run`/release build talks to
/// with zero flags; override with `MM_SYNC_BASE_URL` above for local dev
/// against your own machine instead.
const String _deployedSyncBaseUrl = 'https://smaransaathi-backend.onrender.com';

String get _syncBaseUrl => _configuredSyncBaseUrl.isNotEmpty ? _configuredSyncBaseUrl : _deployedSyncBaseUrl;

/// Builds the app's state with local persistence wired in.
///
/// If Hive cannot be opened — a locked profile directory, a browser with site
/// data disabled — the app falls back to an in-memory session rather than
/// refusing to start. A caregiver in a clinic with a misconfigured device
/// should still be able to run today's activities; they just will not survive
/// a restart, and [AppState.hydrated] reports that.
Future<AppState> bootstrapAppState({String? storagePath}) async {
  await LocalNotificationService.instance.initialize();
  final SyncTransport? transport = _syncBaseUrl.isEmpty ? null : HttpSyncTransport(baseUrl: _syncBaseUrl);
  // Same backend, same graceful degradation: with no URL there is no pairing,
  // and the app works on one device exactly as it did before.
  final PairingService? pairing =
      _syncBaseUrl.isEmpty ? null : PairingService(baseUrl: _syncBaseUrl);

  final HiveStore? store = await HiveStore.tryOpen(path: storagePath);

  if (store == null) {
    final AppState fallback = AppState(transport: transport, pairing: pairing);
    await fallback.hydrate();
    return fallback;
  }

  final AppState state = AppState(
    patients: HivePatientRepository(store),
    games: HiveGameRepository(store),
    analytics: HiveAnalyticsRepository(store),
    reminders: HiveReminderRepository(store),
    daily: HiveDailyRepository(store),
    assessment: HiveAssessmentRepository(store),
    memories: HiveMemoryFragmentRepository(store),
    moodDrawings: HiveMoodDrawingRepository(store),
    settings: HiveSettingsRepository(store),
    sync: HiveSyncRepository(store),
    connectivity: _connectivityForPlatform(),
    transport: transport,
    pairing: pairing,
  );

  await state.hydrate();
  return state;
}

/// Attempts real Firebase sign-in; returns `null` on any failure — no
/// platform config yet (web/iOS — see `firebase_options.dart`), no network
/// at first launch, anything. `null` means [SmaranSaathiApp] skips the
/// sign-in gate entirely and behaves exactly as it did before this existed,
/// the same graceful-degradation contract [bootstrapAppState] already makes
/// for Hive and connectivity.
Future<AuthService?> bootstrapAuth() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    debugPrint('bootstrap: Firebase unavailable, skipping the sign-in gate ($error)');
    return null;
  }
  // The backend URL is optional. Sign-in itself is pure Firebase and works
  // without it; only `declareRole`/`fetchMe` need a server, and both already
  // swallow a failed request. Requiring the URL here used to disable sign-in
  // entirely on a device with Firebase perfectly well configured.
  if (_syncBaseUrl.isEmpty) {
    debugPrint('bootstrap: no MM_SYNC_BASE_URL — sign-in is available, but the '
        'role claim will not be recorded server-side.');
  }
  return FirebaseAuthService(backendBaseUrl: _syncBaseUrl);
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
