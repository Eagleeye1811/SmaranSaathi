# Speech plugin adapters

**Status: activated.** `speech_to_text_recognizer.dart` and
`flutter_tts_synthesizer.dart` are the real, live implementations —
`speech_to_text` and `flutter_tts` are in `pubspec.yaml`, and
`buildVoiceController` (`../voice_bootstrap.dart`) defaults to these two
classes, so every entry point (`AskSaathiButton` included) gets real
microphone input and real speech output with no extra wiring.

(The `.template` files that used to sit alongside these before the packages
were added have been removed — they're no longer needed now that activation
is done.)

## Platform configuration

Already applied to this repo:

- `android/app/src/main/AndroidManifest.xml` — `RECORD_AUDIO` permission and
  the `<queries>` entries Android 11+ needs to see the speech and TTS engines.
- `ios/Runner/Info.plist` — `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription`.

Android also needs `minSdk 21` or higher; the project is already above that.
