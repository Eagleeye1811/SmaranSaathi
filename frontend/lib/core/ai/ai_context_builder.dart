import '../services/app_state.dart';
import 'ai_context.dart';
import 'ai_models.dart';

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
  /// whatever the profile was created with. [turns] is this session's own
  /// transcript, newest last — the caller (the chat screen) owns it, since
  /// `AppState` only holds what survives a restart.
  PatientAiContext aiContext({
    DateTime? now,
    String? replyLanguage,
    List<ConversationTurn> turns = const <ConversationTurn>[],
  }) =>
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
        // Capped: enough for the model to stay coherent within the session
        // without the prompt growing unbounded across a long conversation.
        recentTurns: turns.length <= 8 ? turns : turns.sublist(turns.length - 8),
        memoryInvitesRemainingToday: memoryInvitesRemainingToday,
        memoryResurfaceCandidate: memoryResurfaceCandidate,
        totalSharedMemories: memoryFragments.length,
        // Most-recently-shared first, capped: the model should know the
        // whole backlog exists, but an unbounded list would grow the prompt
        // without limit over months of use — recent stories are also simply
        // more likely to come up again in conversation than old ones.
        knownMemories: memoryFragments.length <= 20
            ? memoryFragments.reversed.toList(growable: false)
            : memoryFragments.reversed.take(20).toList(growable: false),
      );
}
