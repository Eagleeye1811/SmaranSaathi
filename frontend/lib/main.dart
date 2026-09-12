import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/services/app_state.dart';
import 'core/models/auth_user.dart';
import 'core/services/auth_service.dart';

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
    return await auth.authStateChanges.first
        .timeout(const Duration(seconds: 3), onTimeout: () => auth.currentUser);
  } catch (error) {
    debugPrint('main: could not restore the previous session ($error)');
    return auth.currentUser;
  }
}
