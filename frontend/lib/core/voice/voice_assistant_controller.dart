import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/ai_context.dart';
import '../ai/ai_models.dart';
import '../ai/ai_service.dart';
import 'speech_engines.dart';
import 'voice_language.dart';
import 'voice_models.dart';

/// Drives the whole voice interaction:
///
/// ```
/// tap → permission → listen → transcribe → AiService.ask → speak
/// ```
///
/// It owns no AI logic of its own. The assistant is the existing
/// [AiService] built in the previous phase — this class only moves audio in
/// and out of it, which is why there is still exactly one assistant.
///
/// A `ChangeNotifier`, matching the app's existing state pattern, so the sheet
/// can rebuild on each phase without a state-management package.
class VoiceAssistantController extends ChangeNotifier {
  VoiceAssistantController({
    required AiService assistant,
    required SpeechRecognizer recognizer,
    required SpeechSynthesizer synthesizer,
    required PatientAiContext Function() contextBuilder,
    VoiceLanguage language = VoiceLanguage.english,
    this.autoSpeak = true,
  })  : _assistant = assistant,
        _recognizer = recognizer,
        _synthesizer = synthesizer,
        _contextBuilder = contextBuilder,
        _language = language;

  final AiService _assistant;
  final SpeechRecognizer _recognizer;
  final SpeechSynthesizer _synthesizer;

  /// Rebuilt per turn, so the assistant always sees the state of the app *now*
  /// — a reminder ticked off mid-conversation is reflected in the next answer.
  final PatientAiContext Function() _contextBuilder;

  /// Whether answers are read aloud automatically. A caregiver may turn this
  /// off for a patient who prefers to read, without losing voice input.
  final bool autoSpeak;

  VoicePhase _phase = VoicePhase.idle;
  VoiceError? _error;
  String _heard = '';
  AssistantReply? _reply;
  VoiceLanguage _language;
  ResolvedVoiceLanguage? _resolvedInput;
  ResolvedVoiceLanguage? _resolvedOutput;
  bool _initialised = false;
  bool _disposed = false;

  /// Guards against a stale turn finishing after the patient has cancelled and
  /// started another — the older turn's results are dropped.
  int _turn = 0;

  // ── What the UI reads ──────────────────────────────────────────────────

  VoicePhase get phase => _phase;
  VoiceError? get error => _error;

  /// What has been heard so far, updating live while the patient speaks.
  String get recognizedText => _heard;

  /// The assistant's answer, once there is one.
  AssistantReply? get reply => _reply;

  VoiceLanguage get language => _language;

  /// Set when the device could not provide the requested language and the
  /// flow stepped down to another. The sheet says so plainly.
  ResolvedVoiceLanguage? get resolvedInputLanguage => _resolvedInput;
  ResolvedVoiceLanguage? get resolvedOutputLanguage => _resolvedOutput;

  bool get isListening => _phase == VoicePhase.listening;
  bool get isThinking => _phase == VoicePhase.thinking;
  bool get isSpeaking => _phase == VoicePhase.speaking;
  bool get isBusy => _phase.isBusy;

  /// True when the microphone is usable at all — false hides the mic button
  /// rather than offering something that cannot work.
  bool get canListen => _recognizer.isAvailable;

  bool get canSpeak => _synthesizer.isAvailable;

  // ── Setup ──────────────────────────────────────────────────────────────

  /// Prepares both engines and works out which languages this device can
  /// actually manage. Safe to call more than once.
  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    const VoiceLanguageResolver resolver = VoiceLanguageResolver();

    if (await _recognizer.initialize()) {
      _resolvedInput = resolver.resolve(_language, await _recognizer.supportedLocales());
    } else {
      _resolvedInput =
          ResolvedVoiceLanguage(requested: _language, resolved: null, localeId: null);
    }

    if (await _synthesizer.initialize()) {
      _resolvedOutput =
          resolver.resolve(_language, await _synthesizer.supportedLanguages());
    } else {
      _resolvedOutput =
          ResolvedVoiceLanguage(requested: _language, resolved: null, localeId: null);
    }

    _notify();
  }

  /// Switches language and re-resolves against the device.
  Future<void> setLanguage(VoiceLanguage value) async {
    if (_language == value) return;
    await cancel();
    _language = value;
    _initialised = false;
    await initialize();
  }

  // ── The flow ───────────────────────────────────────────────────────────

  /// Starts a turn: permission, then listening.
  Future<void> startListening() async {
    if (isBusy) return;
    await initialize();

    final int turn = ++_turn;
    _error = null;
    _heard = '';
    _reply = null;

    // ── permission ──────────────────────────────────────────────────────
    if (!await _recognizer.hasPermission()) {
      _set(VoicePhase.requestingPermission);
      final SpeechPermissionOutcome outcome = await _recognizer.requestPermission();
      if (_stale(turn)) return;

      switch (outcome) {
        case SpeechPermissionOutcome.granted:
          break;
        case SpeechPermissionOutcome.denied:
          return _fail(VoiceErrorKind.permissionDenied);
        case SpeechPermissionOutcome.permanentlyDenied:
          return _fail(VoiceErrorKind.permissionPermanentlyDenied);
        case SpeechPermissionOutcome.unavailable:
          return _fail(VoiceErrorKind.speechUnavailable);
      }
    }

    // ── language ────────────────────────────────────────────────────────
    final ResolvedVoiceLanguage? input = _resolvedInput;
    if (input == null || !input.isSupported) {
      return _fail(VoiceErrorKind.languageUnsupported,
          detail: 'no recognizer locale for ${_language.name}');
    }

    // ── listen ──────────────────────────────────────────────────────────
    _set(VoicePhase.listening);
    try {
      await _recognizer.listen(
        localeId: input.localeId!,
        onResult: (SpeechResult result) {
          if (_stale(turn) || _phase != VoicePhase.listening) return;
          _heard = result.text;
          _notify();
          if (result.isFinal) unawaited(_answer(turn));
        },
        onError: (VoiceError error) {
          if (_stale(turn)) return;
          _fail(error.kind, detail: error.detail);
        },
      );
    } catch (e) {
      if (_stale(turn)) return;
      _fail(VoiceErrorKind.recognitionFailed, detail: e.toString());
    }
  }

  /// Ends listening early and answers whatever was heard.
  ///
  /// The patient's "I'm done talking" control — distinct from [cancel], which
  /// throws the turn away.
  Future<void> stopListening() async {
    if (_phase != VoicePhase.listening) return;
    final int turn = _turn;
    await _recognizer.stop();
    if (_stale(turn)) return;
    await _answer(turn);
  }

  /// Sends [question] straight to the assistant, skipping the microphone.
  ///
  /// Backs the suggested follow-up chips, so a patient who cannot or would
  /// rather not speak still reaches the same assistant and still hears the
  /// answer read aloud.
  Future<void> askDirectly(String question) async {
    if (isBusy) await cancel();
    // A first-class entry point: the follow-up chips can be the very first
    // thing a patient touches, so the engines may not be resolved yet.
    await initialize();
    final int turn = ++_turn;
    _error = null;
    _reply = null;
    _heard = question;
    await _answer(turn);
  }

  /// Transcription → assistant → speech.
  Future<void> _answer(int turn) async {
    if (_stale(turn)) return;

    if (_heard.trim().isEmpty) {
      return _fail(VoiceErrorKind.noSpeechDetected);
    }

    _set(VoicePhase.thinking);
    final AiResult<AssistantReply> result =
        await _assistant.ask(_heard, _contextBuilder());
    if (_stale(turn)) return;

    final AssistantReply? reply = result.valueOrNull;
    if (reply == null) {
      return _fail(VoiceErrorKind.assistantFailed,
          detail: result.failureOrNull?.toString());
    }

    _reply = reply;
    if (!autoSpeak) {
      _set(VoicePhase.idle);
      return;
    }
    await _speak(reply.text, turn);
  }

  /// Reads the current answer again. Offered because someone with memory
  /// difficulty will often want it twice, and asking again would cost another
  /// model call.
  Future<void> replay() async {
    final AssistantReply? reply = _reply;
    if (reply == null || isBusy) return;
    await initialize();
    await _speak(reply.text, ++_turn);
  }

  Future<void> _speak(String text, int turn) async {
    final ResolvedVoiceLanguage? output = _resolvedOutput;
    if (output == null || !output.isSupported) {
      // The answer is on screen; only the audio is missing, so this is a
      // notice rather than a failure — the reply survives.
      _error = const VoiceError(VoiceErrorKind.ttsUnavailable);
      _set(VoicePhase.idle);
      return;
    }

    _set(VoicePhase.speaking);
    try {
      await _synthesizer.speak(text, localeId: output.localeId!);
      if (_stale(turn)) return;
      _set(VoicePhase.idle);
    } catch (e) {
      if (_stale(turn)) return;
      _error = VoiceError(VoiceErrorKind.ttsFailed, detail: e.toString());
      _set(VoicePhase.idle);
    }
  }

  /// Stops the reading without losing the answer.
  Future<void> stopSpeaking() async {
    if (_phase != VoicePhase.speaking) return;
    _turn++; // orphan the in-flight utterance
    await _synthesizer.stop();
    _set(VoicePhase.idle);
  }

  /// Abandons the turn entirely and returns to rest.
  Future<void> cancel() async {
    _turn++;
    if (_recognizer.isListening) await _recognizer.cancel();
    if (_synthesizer.isSpeaking) await _synthesizer.stop();
    _heard = '';
    _error = null;
    _set(VoicePhase.idle);
  }

  /// Clears an error so the mic button returns.
  void dismissError() {
    if (_error == null) return;
    _error = null;
    if (_phase == VoicePhase.error) _phase = VoicePhase.idle;
    _notify();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  bool _stale(int turn) => _disposed || turn != _turn;

  void _set(VoicePhase phase) {
    _phase = phase;
    _notify();
  }

  void _fail(VoiceErrorKind kind, {String? detail}) {
    _error = VoiceError(kind, detail: detail);
    _phase = VoicePhase.error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recognizer.dispose();
    _synthesizer.dispose();
    super.dispose();
  }
}
