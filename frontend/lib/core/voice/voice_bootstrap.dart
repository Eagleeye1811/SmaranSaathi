import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/ai_context.dart';
import '../ai/ai_context_builder.dart';
import '../ai/ai_service.dart';
import '../ai/gemini_ai_service.dart';
import '../ai/resilient_ai_service.dart';
import '../services/app_state.dart';
import '../services/connectivity_service.dart';
import 'adapters/flutter_tts_synthesizer.dart';
import 'adapters/speech_to_text_recognizer.dart';
import 'speech_engines.dart';
import 'voice_assistant_controller.dart';
import 'voice_intake_controller.dart';
import 'voice_language.dart';

/// Exposes `AppState`'s connectivity to the AI layer without changing it.
///
/// `AppState` keeps its connectivity service private and only publishes the
/// `offline` flag. Rather than widen that API — the persistence and sync work
/// depends on it — this adapter reads the public flag and republishes it as a
/// [ConnectivityService].
class AppStateConnectivity implements ConnectivityService {
  AppStateConnectivity(this._state) {
    _last = !_state.offline;
    _state.addListener(_onStateChanged);
  }

  final AppState _state;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late bool _last;

  void _onStateChanged() {
    final bool now = !_state.offline;
    if (now == _last) return;
    _last = now;
    if (!_controller.isClosed) _controller.add(now);
  }

  @override
  bool get isOnline => !_state.offline;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<bool> refresh() async => isOnline;

  @override
  Future<void> dispose() async {
    _state.removeListener(_onStateChanged);
    await _controller.close();
  }
}

/// Builds the assistant the voice flow talks to.
///
/// This is the *existing* assistant from the AI phase — Gemini when reachable,
/// on-device otherwise. Voice does not introduce a second one.
AiService buildPatientAssistant(AppState state) => ResilientAiService(
      remote: GeminiAiService(),
      connectivity: AppStateConnectivity(state),
    );

/// Builds the controller that reads the intake aloud and takes spoken answers.
///
/// Same two engines as the assistant, so a device that can talk to Mitra can
/// answer the questionnaire — there is no second voice stack.
VoiceIntakeController buildVoiceIntakeController({
  required VoidCallback onAdvance,
  VoidCallback? onGoBack,
  SpeechRecognizer? recognizer,
  SpeechSynthesizer? synthesizer,
  VoiceLanguage language = VoiceLanguage.english,
}) {
  return VoiceIntakeController(
    recognizer: recognizer ?? SpeechToTextRecognizer(),
    synthesizer: synthesizer ?? FlutterTtsSynthesizer(),
    onAdvance: onAdvance,
    onGoBack: onGoBack,
    language: language,
  );
}

/// Builds the voice controller for a patient session.
///
/// [recognizer] and [synthesizer] default to the unavailable implementations,
/// because this build has no speech plugins — see `adapters/README.md`. Pass
/// the plugin-backed pair once `speech_to_text` and `flutter_tts` are added
/// and nothing else changes.
VoiceAssistantController buildVoiceController(
  AppState state, {
  AiService? assistant,
  SpeechRecognizer? recognizer,
  SpeechSynthesizer? synthesizer,
  VoiceLanguage? language,
  String? replyLanguage,
  bool autoSpeak = true,
}) {
  return VoiceAssistantController(
    assistant: assistant ?? buildPatientAssistant(state),
    recognizer: recognizer ?? SpeechToTextRecognizer(),
    synthesizer: synthesizer ?? FlutterTtsSynthesizer(),
    // Rebuilt per turn so the assistant always sees the app as it is now.
    contextBuilder: () => state.aiContext(replyLanguage: replyLanguage),
    // The interface language wins over the profile's: a patient who switched
    // the app to Hindi expects Mitra to answer in Hindi too.
    language: language ?? VoiceLanguageX.fromPatientLanguage(state.patient.language),
    autoSpeak: autoSpeak,
  );
}

/// Re-exported so callers need one import to build a context for a test.
typedef PatientContextBuilder = PatientAiContext Function();
