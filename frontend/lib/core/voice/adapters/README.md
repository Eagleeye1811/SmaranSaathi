# Speech plugin adapters

The voice layer is complete and tested, but it ships with the *unavailable*
engines wired in, because activating the real ones needs two lines in
`pubspec.yaml` — which this phase was told not to modify.

Everything else is done. Activation is three steps and touches no logic.

## 1. Add the packages

```yaml
dependencies:
  speech_to_text: ^7.0.0
  flutter_tts: ^4.2.0
```

Then `flutter pub get`.

## 2. Rename the adapters

```bash
mv speech_to_text_recognizer.dart.template speech_to_text_recognizer.dart
mv flutter_tts_synthesizer.dart.template   flutter_tts_synthesizer.dart
```

They are written against the interfaces in `../speech_engines.dart` and
compile as-is once the packages resolve. They are `.template` only so this
build analyses cleanly without the dependencies.

## 3. Pass them in

One call site, in `lib/features/patient/home/patient_home_screen.dart`:

```dart
const AskMitraButton(
  recognizer: SpeechToTextRecognizer(),
  synthesizer: FlutterTtsSynthesizer(),
)
```

Or set the defaults in `buildVoiceController` (`../voice_bootstrap.dart`) so
every future entry point gets them.

## Platform configuration

Already applied to this repo:

- `android/app/src/main/AndroidManifest.xml` — `RECORD_AUDIO` permission and
  the `<queries>` entries Android 11+ needs to see the speech and TTS engines.
- `ios/Runner/Info.plist` — `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription`.

Android also needs `minSdk 21` or higher; the project is already above that.
