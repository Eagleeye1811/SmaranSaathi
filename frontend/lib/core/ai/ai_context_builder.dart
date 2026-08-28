import '../services/app_state.dart';
import 'ai_context.dart';

/// Assembles a [PatientAiContext] from the running app.
///
/// Written as an extension so the AI layer plugs in without editing
/// `AppState` — nothing in the existing state, persistence or sync code
/// changes to support AI.
///
/// Everything read here already comes from the repository layer, so when the
/// FastAPI backend replaces the local store the context is unchanged: it is
/// built from the same domain objects, whatever produced them.
extension AiContextBuilder on AppState {
  /// A snapshot of everything the AI layer is allowed to see.
  ///
  /// [now] is injectable so a test can pin the clock and assert on the
  /// resulting prompt. [replyLanguage] is the *interface* language, so the
  /// assistant answers in whatever the patient last selected rather than in
  /// whatever the profile was created with.
  PatientAiContext aiContext({DateTime? now, String? replyLanguage}) =>
      PatientAiContext(
        patient: patient,
        sessions: sessions,
        levels: levels,
        cognitiveProfile: cognitiveProfile,
        reminders: reminders,
        now: now ?? DateTime.now(),
        mood: mood,
        journal: journal,
        completedToday: completedToday,
        lastPlayed: lastPlayed,
        engagementToday: todayEngagement,
        replyLanguage: replyLanguage,
        intake: intake,
      );
}
