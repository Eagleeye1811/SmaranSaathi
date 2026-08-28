import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Local storage is opened and the previous session restored before the first
  // frame, so no screen ever has to render an empty state it will immediately
  // replace.
  final AppState state = await bootstrapAppState();
  runApp(MemoryMitraApp(state: state));
}
