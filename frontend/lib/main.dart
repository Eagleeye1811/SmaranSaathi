import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/services/app_state.dart';
import 'core/models/auth_user.dart';
import 'core/services/auth_service.dart';
import 'core/services/doctor_connection_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Lets plain `flutter run` — no --dart-define, no launch script — pick up
  // GEMINI_API_KEY and friends from frontend/.env (gitignored, bundled as an
  // asset so it loads on every platform including web). Missing or malformed
  // is not fatal: AiConfig.isConfigured is simply false and the app falls
  // back to the on-device assistant, the same graceful degradation every
  // other optional dependency here already gets.
  try {
    await dotenv.load(isOptional: true);
  } catch (error) {
    debugPrint('main: .env failed to load, AI features use the on-device fallback ($error)');
  }

  // Local storage is opened and the previous session restored before the first
  // frame, so no screen ever has to render an empty state it will immediately
  // replace.
  final AppState state = await bootstrapAppState();
  // Real sign-in when Firebase is actually configured for this platform and
  // build (Android today — see firebase_options.dart); `null` otherwise, in
  // which case SmaranSaathiApp opens straight to role selection exactly as
  // it always has.
  final AuthService? auth = await bootstrapAuth();

  // Firebase restores the previous session itself, but it does so
  // *asynchronously*: `currentUser` is often still null in the first moments
  // after `initializeApp`, which is what used to send a signed-in person back
  // to the welcome screen. So wait for the auth stream's first event — with a
  // short timeout, because an offline launch must still open the app, using
  // the session already on disk.
  // Only buildable once `auth` exists (see `bootstrapDoctorConnections`'s
  // doc comment for why it is not part of `bootstrapAppState` itself).
  final DoctorConnectionService? doctorConnections = bootstrapDoctorConnections(auth);
  if (doctorConnections != null) {
    state.attachDoctorConnections(doctorConnections);
  }

  // Before any sync or restore runs: from here on the backend can tell this
  // caller is a specific account rather than just "a copy of the app", and
  // holds it to that account's own record.
  if (auth != null) {
    state.attachAccountTokenProvider(auth.idToken);
  }

  final AuthUser? restored = await _restoreSession(auth);
  if (restored != null) {
    // Binding the account before the first frame is what lets the app open
    // straight onto that person's own dashboard instead of asking them to
    // sign in and answer the questionnaire all over again. The role claim
    // comes along so an account set up on another device still lands in the
    // right app rather than back on the role picker.
    await state.signInAccount(restored.uid, roleHint: restored.role);
  }

  runApp(SmaranSaathiApp(state: state, authService: auth));
}

/// The account Firebase has restored for this launch, or null if there is
/// none — and also null if it takes too long to say, which on a cold start
/// with no network it can. Never throws: a launch must not depend on a
/// sign-in service answering.
Future<AuthUser?> _restoreSession(AuthService? auth) async {
  if (auth == null) return null;
  final AuthUser? immediate = auth.currentUser;
  if (immediate != null) return immediate;
  try {
    // `firstWhere`, not `first`. On a cold start `authStateChanges` emits
    // `null` straight away and only then the user it has restored from disk —
    // so taking the first event meant taking the null, every single launch,
    // and concluding nobody was signed in. The account was never rebound, and
    // a person who had never logged out was shown the greeting and the
    // sign-in screen again.
    return await auth.authStateChanges
        .firstWhere((AuthUser? user) => user != null)
        .timeout(const Duration(seconds: 4), onTimeout: () => auth.currentUser);
  } catch (error) {
    // Nobody is signed in, or the service never answered. Either way the app
    // opens on whatever the local session says — it is offline-first, and a
    // launch must not wait on a network round trip.
    debugPrint('main: no previous session to restore ($error)');
    return auth.currentUser;
  }
}
