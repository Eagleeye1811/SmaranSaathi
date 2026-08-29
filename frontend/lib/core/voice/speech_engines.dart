import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_models.dart';

/// Speech-to-text, abstracted away from any one plugin.
///
/// Shaped to sit thinly over `speech_to_text`, but nothing above this line
/// knows that — which is what lets the whole voice flow be tested without a
/// microphone, an emulator or a platform channel.
abstract class SpeechRecognizer {
  /// Prepares the engine. Returns false when the device has none.
  ///
  /// Safe to call repeatedly; implementations cache the result.
  Future<bool> initialize();

  bool get isAvailable;
  bool get isListening;

  /// Whether microphone permission is already granted.
  Future<bool> hasPermission();

  /// Asks the OS. Returns false if declined.
  ///
  /// [SpeechPermissionOutcome] distinguishes a plain refusal from a permanent
  /// one, because only the second needs sending the caregiver to Settings.
  Future<SpeechPermissionOutcome> requestPermission();

  /// Locale ids the engine can recognise, e.g. `['en_IN', 'hi_IN']`.
  Future<List<String>> supportedLocales();

  /// Opens the microphone.
  ///
  /// [onResult] fires for partial results as well as the final one, so the
  /// patient sees their words appearing as they speak — important feedback
  /// when you are not sure whether a device heard you.
  ///
  /// [pauseFor] is how long a silence ends the turn; [listenFor] caps the whole
  /// utterance. Both default generously: an elderly speaker searching for a
  /// word should not be cut off mid-sentence.
  Future<void> listen({
    required String localeId,
    required void Function(SpeechResult result) onResult,
    required void Function(VoiceError error) onError,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 4),
  });

  /// Ends the turn and keeps what was heard.
  Future<void> stop();

  /// Ends the turn and discards it.
  Future<void> cancel();

  void dispose();
}

/// The result of asking for microphone access.
enum SpeechPermissionOutcome {
  granted,

  /// Refused this time; asking again is allowed.
  denied,

  /// Refused permanently, or blocked by policy. Only Settings can change it.
  permanentlyDenied,

  /// The device has no speech engine, so permission is moot.
  unavailable,
}

/// Text-to-speech, abstracted away from any one plugin.
///
/// Shaped to sit thinly over `flutter_tts`.
abstract class SpeechSynthesizer {
  /// Prepares the engine. Returns false when no voice is available.
  Future<bool> initialize();

  bool get isAvailable;
  bool get isSpeaking;

  /// Locale ids the engine can speak, e.g. `['en-IN', 'hi-IN']`.
  Future<List<String>> supportedLanguages();

  /// Speaks [text], completing when the utterance finishes.
  ///
  /// [rate] is deliberately below the platform default for this product: the
  /// listener may have difficulty processing quick speech, and a rushed
  /// companion reads as an impatient one.
  Future<void> speak(
    String text, {
    required String localeId,
    double rate = 0.45,
    double pitch = 1.0,
  });

  /// Stops immediately, mid-word if necessary.
  Future<void> stop();

  void dispose();
}

// ─────────────────────────────────────────────────────────────────────────
// Fakes — used by the tests, and by any build without the plugins.
// ─────────────────────────────────────────────────────────────────────────

/// A recognizer that is never available.
///
/// The default in a build without `speech_to_text`, so the app degrades to
/// tap-only rather than failing to compile or crashing on first use.
class UnavailableSpeechRecognizer implements SpeechRecognizer {
  const UnavailableSpeechRecognizer();

  @override
  Future<bool> initialize() async => false;

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<SpeechPermissionOutcome> requestPermission() async =>
      SpeechPermissionOutcome.unavailable;

  @override
  Future<List<String>> supportedLocales() async => const <String>[];

  @override
  Future<void> listen({
    required String localeId,
    required void Function(SpeechResult result) onResult,
    required void Function(VoiceError error) onError,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 4),
  }) async =>
      onError(const VoiceError(VoiceErrorKind.speechUnavailable,
          detail: 'no speech_to_text plugin in this build'));

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

/// A synthesizer that silently does nothing but reports itself unavailable, so
/// the answer is still shown on screen to be read.
class UnavailableSpeechSynthesizer implements SpeechSynthesizer {
  const UnavailableSpeechSynthesizer();

  @override
  Future<bool> initialize() async => false;

  @override
  bool get isAvailable => false;

  @override
  bool get isSpeaking => false;

  @override
  Future<List<String>> supportedLanguages() async => const <String>[];

  @override
  Future<void> speak(String text,
      {required String localeId, double rate = 0.45, double pitch = 1.0}) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// A scriptable recognizer for tests.
@visibleForTesting
class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({
    this.locales = const <String>['en_IN', 'hi_IN'],
    this.permission = SpeechPermissionOutcome.granted,
    this.available = true,
    this.alreadyGranted = false,
  });

  List<String> locales;
  SpeechPermissionOutcome permission;
  bool available;
  bool alreadyGranted;

  /// Utterances to emit on the next `listen`, in order. A `null` entry raises
  /// [errorToRaise] instead, for exercising mid-recognition failure.
  List<SpeechResult> script = const <SpeechResult>[];
  VoiceError? errorToRaise;

  bool _listening = false;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastLocaleId;
  bool disposed = false;

  void Function(SpeechResult)? _onResult;
  void Function(VoiceError)? _onError;

  @override
  Future<bool> initialize() async => available;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> hasPermission() async => alreadyGranted;

  @override
  Future<SpeechPermissionOutcome> requestPermission() async => permission;

  @override
  Future<List<String>> supportedLocales() async => locales;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(SpeechResult result) onResult,
    required void Function(VoiceError error) onError,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    listenCount++;
    lastLocaleId = localeId;
    _listening = true;
    _onResult = onResult;
    _onError = onError;

    if (errorToRaise != null) {
      _listening = false;
      onError(errorToRaise!);
      return;
    }
    for (final SpeechResult r in script) {
      if (!_listening) return;
      onResult(r);
      if (r.isFinal) _listening = false;
    }
  }

  /// Emits a result after `listen` has returned, for driving a flow by hand.
  void emit(SpeechResult result) {
    _onResult?.call(result);
    if (result.isFinal) _listening = false;
  }

  void emitError(VoiceError error) {
    _listening = false;
    _onError?.call(error);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _listening = false;
  }

  @override
  void dispose() => disposed = true;
}

/// A scriptable synthesizer for tests.
@visibleForTesting
class FakeSpeechSynthesizer implements SpeechSynthesizer {
  FakeSpeechSynthesizer({
    this.languages = const <String>['en-IN', 'hi-IN'],
    this.available = true,
    this.failOnSpeak = false,
  });

  List<String> languages;
  bool available;
  bool failOnSpeak;

  /// Held open so a test can assert on the speaking state before it finishes.
  Completer<void>? gate;

  final List<String> spoken = <String>[];
  String? lastLocaleId;
  double? lastRate;
  int stopCount = 0;
  bool _speaking = false;
  bool disposed = false;

  @override
  Future<bool> initialize() async => available;

  @override
  bool get isAvailable => available;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<List<String>> supportedLanguages() async => languages;

  @override
  Future<void> speak(String text,
      {required String localeId, double rate = 0.45, double pitch = 1.0}) async {
    if (failOnSpeak) throw StateError('tts failed');
    spoken.add(text);
    lastLocaleId = localeId;
    lastRate = rate;
    _speaking = true;
    if (gate != null) await gate!.future;
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _speaking = false;
    if (gate != null && !gate!.isCompleted) gate!.complete();
  }

  @override
  void dispose() => disposed = true;
}
