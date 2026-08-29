import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../speech_engines.dart';
import '../voice_models.dart';

/// `speech_to_text` behind the app's [SpeechRecognizer] interface.
///
/// Thin by design: it maps types and error codes, and holds no flow logic —
/// that lives in `VoiceAssistantController`, which is testable without a
/// microphone precisely because this class is the only plugin-aware part.
class SpeechToTextRecognizer implements SpeechRecognizer {
  SpeechToTextRecognizer({stt.SpeechToText? engine})
      : _engine = engine ?? stt.SpeechToText();

  final stt.SpeechToText _engine;
  bool _available = false;
  bool _initialised = false;

  /// Set when the plugin reports an error through its own callback, so the
  /// next permission check can tell a denial from a missing engine.
  SpeechRecognitionError? _lastError;

  @override
  Future<bool> initialize() async {
    if (_initialised) return _available;
    _initialised = true;
    _available = await _engine.initialize(
      onError: (SpeechRecognitionError e) => _lastError = e,
      onStatus: (_) {},
      // The plugin asks for permission during initialize; we want that
      // separated so the UI can explain itself first.
      debugLogging: false,
    );
    return _available;
  }

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _engine.isListening;

  @override
  Future<bool> hasPermission() async => await _engine.hasPermission;

  @override
  Future<SpeechPermissionOutcome> requestPermission() async {
    // `initialize` is what triggers the OS prompt in this plugin.
    final bool ok = await initialize();
    if (!ok) return SpeechPermissionOutcome.unavailable;

    // In speech_to_text v7, hasPermission is a Future<bool>.
    final bool permitted = await _engine.hasPermission;
    if (ok && permitted) return SpeechPermissionOutcome.granted;

    // `permanent` distinguishes "not now" from "never ask again".
    if (_lastError?.permanent ?? false) {
      return SpeechPermissionOutcome.permanentlyDenied;
    }
    return SpeechPermissionOutcome.denied;
  }

  @override
  Future<List<String>> supportedLocales() async {
    if (!await initialize()) return const <String>[];
    final List<stt.LocaleName> locales = await _engine.locales();
    return locales.map((stt.LocaleName l) => l.localeId).toList(growable: false);
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(SpeechResult result) onResult,
    required void Function(VoiceError error) onError,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    if (!await initialize()) {
      return onError(const VoiceError(VoiceErrorKind.speechUnavailable));
    }
    _lastError = null;

    await _engine.listen(
      localeId: localeId,
      onResult: (SpeechRecognitionResult r) => onResult(SpeechResult(
        text: r.recognizedWords,
        isFinal: r.finalResult,
        confidence: r.confidence,
      )),
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: stt.SpeechListenOptions(
        // Partial results drive the live transcript, which is the feedback
        // that tells an uncertain user the device is hearing them.
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );

    final SpeechRecognitionError? error = _lastError;
    if (error != null) onError(_map(error));
  }

  /// Maps the plugin's error strings onto our kinds.
  static VoiceError _map(SpeechRecognitionError e) => VoiceError(
        switch (e.errorMsg) {
          'error_speech_timeout' || 'error_no_match' => VoiceErrorKind.noSpeechDetected,
          'error_permission' => VoiceErrorKind.permissionDenied,
          'error_language_not_supported' => VoiceErrorKind.languageUnsupported,
          'error_network' || 'error_network_timeout' => VoiceErrorKind.recognitionFailed,
          _ => VoiceErrorKind.recognitionFailed,
        },
        detail: '${e.errorMsg} (permanent: ${e.permanent})',
      );

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> cancel() => _engine.cancel();

  @override
  void dispose() {
    // The plugin has no dispose; cancelling releases the microphone.
    _engine.cancel();
  }
}
