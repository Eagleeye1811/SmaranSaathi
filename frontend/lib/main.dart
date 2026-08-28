import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/services/app_state.dart';
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
  // which case MemoryMitraApp opens straight to role selection exactly as
  // it always has.
  final AuthService? auth = await bootstrapAuth();
  runApp(MemoryMitraApp(state: state, authService: auth));
}
