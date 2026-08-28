import 'package:flutter/foundation.dart';

/// Where the voice interaction currently is.
///
/// One linear flow — tap, listen, think, speak — so the patient always has
/// exactly one thing happening and one obvious way to stop it.
enum VoicePhase {
  /// Nothing running. The microphone button is the only affordance.
  idle,

  /// Asking the OS for microphone access.
  requestingPermission,

  /// The microphone is open and words are arriving.
  listening,

  /// Listening finished; the assistant is working out an answer.
  thinking,

  /// The answer is being read aloud.
  speaking,

  /// Something went wrong. [VoiceError] says what, in words a patient can read.
  error,
}

extension VoicePhaseX on VoicePhase {
  bool get isBusy => this != VoicePhase.idle && this != VoicePhase.error;

  /// Whether a cancel control should be offered.
  bool get isCancellable =>
      this == VoicePhase.listening ||
      this == VoicePhase.thinking ||
      this == VoicePhase.speaking;
}

/// Why a voice interaction could not complete.
///
/// Separated from `AiErrorKind` because the causes are different — a denied
/// microphone is not an AI problem — but handled the same way: a specific kind
/// with patient-facing wording, never a thrown exception.
enum VoiceErrorKind {
  /// The patient declined the microphone this time.
  permissionDenied,

  /// Declined permanently; only Settings can undo it.
  permissionPermanentlyDenied,

  /// No speech engine on this device.
  speechUnavailable,

  /// The microphone was open but nothing intelligible arrived.
  noSpeechDetected,

  /// The engine has no model for the chosen language.
  languageUnsupported,

  /// The engine failed mid-recognition.
  recognitionFailed,

  /// No text-to-speech voice available.
  ttsUnavailable,

  /// Speaking failed after it had started.
  ttsFailed,

  /// The assistant itself could not answer.
  assistantFailed,

  unknown,
}

extension VoiceErrorKindX on VoiceErrorKind {
  /// Patient-facing wording.
  ///
  /// Short, never technical, and never blaming — someone with memory
  /// difficulty reading "recognition error 7" learns only that they failed.
  String get message => switch (this) {
        VoiceErrorKind.permissionDenied =>
          'I need permission to use the microphone before I can listen.',
        VoiceErrorKind.permissionPermanentlyDenied =>
          'Microphone access is turned off. A caregiver can turn it back on in Settings.',
        VoiceErrorKind.speechUnavailable =>
          'This device cannot listen right now. You can still tap to choose.',
        VoiceErrorKind.noSpeechDetected => 'I did not quite catch that. Shall we try again?',
        VoiceErrorKind.languageUnsupported =>
          'This device cannot listen in that language yet.',
        VoiceErrorKind.recognitionFailed => 'Something interrupted my listening. Let us try again.',
        VoiceErrorKind.ttsUnavailable =>
          'I cannot speak aloud on this device, but you can read my answer.',
        VoiceErrorKind.ttsFailed => 'I could not finish speaking, but my answer is here.',
        VoiceErrorKind.assistantFailed => 'I could not work that out just now.',
        VoiceErrorKind.unknown => 'Something went wrong. Shall we try again?',
      };

  /// Whether the patient can simply tap the microphone again.
  bool get isRetryable => switch (this) {
        VoiceErrorKind.permissionPermanentlyDenied ||
        VoiceErrorKind.speechUnavailable ||
        VoiceErrorKind.languageUnsupported =>
          false,
        _ => true,
      };

  /// Errors that still leave a usable answer on screen — the reply is there,
  /// it just could not be spoken.
  bool get isSpeechOnly =>
      this == VoiceErrorKind.ttsUnavailable || this == VoiceErrorKind.ttsFailed;
}

@immutable
class VoiceError {
  const VoiceError(this.kind, {this.detail});

  final VoiceErrorKind kind;

  /// Developer-facing. Never rendered.
  final String? detail;

  String get message => kind.message;
  bool get isRetryable => kind.isRetryable;

  @override
  String toString() => 'VoiceError(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// A partial or final transcription.
@immutable
class SpeechResult {
  const SpeechResult({
    required this.text,
    required this.isFinal,
    this.confidence = 1.0,
  });

  final String text;

  /// Partial results stream in while the patient is still speaking; only the
  /// final one is sent to the assistant.
  final bool isFinal;

  /// 0–1. Engines that do not report confidence send 1.0.
  final double confidence;

  bool get isEmpty => text.trim().isEmpty;

  @override
  String toString() => 'SpeechResult("$text", final: $isFinal)';
}
