import '../models/daily.dart';
import 'ai_context.dart';
import 'ai_models.dart';

/// The AI layer's contract.
///
/// Deliberately narrow and provider-agnostic. Three implementations ship:
///
/// * `GeminiAiService`   — calls the model
/// * `OnDeviceAiService` — the same two answers computed locally, no network
/// * `ResilientAiService` — tries the model, falls back to the device
///
/// A future `BackendAiService` that reads insights from the FastAPI service
/// implements this same interface, so no screen changes when it arrives.
abstract class AiService {
  /// A caregiver-facing reading of recent activity performance.
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext context);

  /// One patient-facing answer, grounded strictly in [context].
  ///
  /// This is not a general chatbot: anything the context cannot support is
  /// answered with a gentle redirect rather than a guess.
  Future<AiResult<AssistantReply>> ask(String question, PatientAiContext context);

  /// Today's questions for this person, written from their own onboarding
  /// answers rather than picked from a fixed list.
  ///
  /// Grounded in [PatientAiContext.intake]: what they came worried about, what
  /// they still do unaided, who is around them. Every implementation must
  /// return something answerable with two or three large taps — the patient
  /// never types.
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext context);

  /// Whether this implementation can currently reach a model. Used to decide
  /// what to show while loading, not to gate the call.
  bool get isAvailable;

  void dispose();
}
