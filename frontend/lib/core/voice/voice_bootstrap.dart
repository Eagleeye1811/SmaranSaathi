import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/ai_context.dart';
import '../ai/ai_context_builder.dart';
import '../ai/ai_service.dart';
import '../ai/gemini_ai_service.dart';
import '../ai/llama_on_device_ai_service.dart';
import '../ai/model_download_service.dart';
import '../ai/resilient_ai_service.dart';
import '../services/app_state.dart';
import '../services/connectivity_service.dart';
import 'adapters/flutter_tts_synthesizer.dart';
import 'adapters/speech_to_text_recognizer.dart';
import 'speech_engines.dart';
import 'voice_assistant_controller.dart';
import 'voice_intake_controller.dart';
import 'voice_language.dart';
import 'voice_nav_intent.dart';
import 'voice_navigation_controller.dart';

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
/// Three tiers — Gemini when reachable, the fine-tuned on-device LLM when it
/// has been downloaded, rule-based templates otherwise/always as the floor.
/// Voice does not introduce a second one; every screen shares this same
/// fallback chain via [ResilientAiService].
AiService buildPatientAssistant(AppState state) => ResilientAiService(
      remote: GeminiAiService(),
      connectivity: AppStateConnectivity(state),
      llamaOnDevice: LlamaOnDeviceAiService(
        modelDownload: ModelDownloadService.fromEnvironment(),
      ),
    );

/// Builds the controller that reads the intake aloud and takes spoken answers.
///
/// Same two engines as the assistant, so a device that can Talk to Saathi can
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
  final String activeCode = replyLanguage ?? state.localeCode ?? 'en';
  final VoiceLanguage effectiveLanguage = language ??
      switch (activeCode) {
        'hi' => VoiceLanguage.hindi,
        'as' => VoiceLanguage.assamese,
        _ => VoiceLanguage.english,
      };

  return VoiceAssistantController(
    assistant: assistant ?? buildPatientAssistant(state),
    recognizer: recognizer ?? SpeechToTextRecognizer(),
    synthesizer: synthesizer ?? FlutterTtsSynthesizer(),
    // Rebuilt per turn so the assistant always sees the app as it is now.
    contextBuilder: () => state.aiContext(
      replyLanguage: state.localeCode ?? activeCode,
    ),
    // The interface language wins over the profile's: a patient who switched
    // the app to Hindi expects Mitra to answer in Hindi too.
    language: effectiveLanguage,
    autoSpeak: autoSpeak,
  );
}

/// Re-exported so callers need one import to build a context for a test.
typedef PatientContextBuilder = PatientAiContext Function();

/// Builds the controller behind spoken navigation.
///
/// Same two engines as the assistant and the intake, so there is one speech
/// stack in the app rather than three. No [AiService] is involved: navigation
/// is a closed vocabulary matched on-device, which is why it keeps working
/// with no network at all.
VoiceNavigationController buildVoiceNavController({
  required VoiceNavHandler onNavigate,
  VoiceNavBack? onBack,
  Set<VoiceDestination> destinations = const <VoiceDestination>{},
  SpeechRecognizer? recognizer,
  SpeechSynthesizer? synthesizer,
  VoiceLanguage? language,
  bool speakAloud = true,
}) {
  return VoiceNavigationController(
    recognizer: recognizer ?? SpeechToTextRecognizer(),
    synthesizer: synthesizer ?? FlutterTtsSynthesizer(),
    onNavigate: onNavigate,
    onBack: onBack,
    destinations: destinations,
    language: language ?? VoiceLanguage.english,
    speakAloud: speakAloud,
  );
}
