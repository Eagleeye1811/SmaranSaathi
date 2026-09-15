import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Where the current turn's results go. Null between turns, and detached
  /// the instant a turn is ended deliberately.
  void Function(SpeechResult result)? _sink;

  /// The most recent transcript, kept so a turn that ends without a final
  /// result still has something to hand back.
  String _heard = '';

  /// Whether this turn has already produced its one final result.
  bool _finalSent = false;

  @override
  Future<bool> initialize() async {
    if (_initialised) return _available;
    _available = await _engine.initialize(
      onError: (SpeechRecognitionError e) => _lastError = e,
      onStatus: _onStatus,
      debugLogging: false,
    );
    // Only a *successful* setup is remembered. The first attempt usually
    // fails for a reason that stops being true a second later: this plugin
    // raises the OS permission prompt from inside `initialize`, and reports
    // failure while the person is still deciding. Latching that answer meant
    // one tap on the microphone poisoned voice for the rest of the session —
    // granting permission changed nothing, because nothing ever asked the
    // engine again.
    if (_available) _initialised = true;
    return _available;
  }

  /// Treats the engine going quiet as the end of the sentence.
  ///
  /// This is what lets someone simply stop talking instead of reaching for a
  /// button. A final result is *supposed* to arrive when the recogniser
  /// detects a pause, but on a good number of Android builds the end of a
  /// turn is announced only as a status change and no final result ever
  /// follows — the partials just stop. Every caller was then left waiting
  /// forever on a turn the engine had already finished.
  ///
  /// Only fires for a turn the engine ended by itself: [stop] and [cancel]
  /// detach the sink first, because those callers resolve the turn
  /// themselves and a second ending would run the whole flow twice.
  void _onStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    final void Function(SpeechResult result)? sink = _sink;
    if (sink == null || _finalSent) return;
    _finalSent = true;
    _sink = null;
    sink(SpeechResult(text: _heard, isFinal: true));
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
    final List<String> list =
        locales.map((stt.LocaleName l) => l.localeId).toList(growable: true);
    // On Web (and platforms where speech_to_text only returns the default locale):
    // Web Speech API in Chromium connects to Google Cloud Speech which natively supports
    // Hindi, Assamese, and English recognition regardless of whether locales() enumerated them.
    if (kIsWeb || list.isEmpty || (list.length == 1 && list.first.toLowerCase().startsWith('en'))) {
      if (!list.any((String s) => s.toLowerCase().startsWith('hi'))) {
        list.add('hi_IN');
      }
      if (!list.any((String s) => s.toLowerCase().startsWith('as'))) {
        list.add('as_IN');
      }
      if (!list.any((String s) => s.toLowerCase().startsWith('en'))) {
        list.add('en_IN');
      }
    }
    return list;
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
    _sink = onResult;
    _heard = '';
    _finalSent = false;

    await _engine.listen(
      onResult: (SpeechRecognitionResult r) {
        _heard = r.recognizedWords;
        final void Function(SpeechResult result)? sink = _sink;
        if (sink == null) return;
        if (r.finalResult) {
          _finalSent = true;
          _sink = null;
        }
        sink(SpeechResult(
          text: r.recognizedWords,
          isFinal: r.finalResult,
          confidence: r.confidence,
        ));
      },
      // All of these belong in the options object; passing them as top-level
      // arguments is deprecated in speech_to_text 7.
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        // Partial results drive the live transcript, which is the feedback
        // that tells an uncertain user the device is hearing them — and they
        // are also the text a turn falls back on when the engine ends
        // without a final result.
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
  Future<void> stop() {
    // Detached first: the caller is ending this turn and will act on what it
    // already has, so the engine's own ending must not run the flow again.
    _sink = null;
    return _engine.stop();
  }

  @override
  Future<void> cancel() {
    _sink = null;
    return _engine.cancel();
  }

  @override
  void dispose() {
    _sink = null;
    // The plugin has no dispose; cancelling releases the microphone.
    _engine.cancel();
  }
}
