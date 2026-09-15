import '../widgets/companion.dart';
import '../../l10n/app_localizations.dart';
import 'game.dart';

/// How well a session went, in the only vocabulary a patient ever sees.
///
/// Deliberately four tiers, not a percentage — a tier can only ever move
/// between four warm labels, never render a number a bad day could turn into
/// a visible drop.
enum FeedbackTier { radiant, warm, steady, gentle }

FeedbackTier feedbackTierFor(int overall) {
  if (overall >= 85) return FeedbackTier.radiant;
  if (overall >= 70) return FeedbackTier.warm;
  if (overall >= 55) return FeedbackTier.steady;
  return FeedbackTier.gentle;
}

/// A complete, positive-only description of one finished session.
///
/// No field here is, or is derived from display of, a raw number — that is
/// the actual guardrail (not just a styling convention): a screen built on
/// this class cannot accidentally show a score, because there isn't one to
/// show.
class PositiveFeedback {
  const PositiveFeedback({
    required this.tier,
    required this.headline,
    required this.body,
    required this.domainNote,
    required this.nextSessionNote,
    required this.companionState,
    required this.celebrate,
  });

  final FeedbackTier tier;
  final String headline;
  final String body;
  final String domainNote;
  final String nextSessionNote;
  final CompanionState companionState;
  final bool celebrate;

  /// Ring fill is decorative, tied to the tier rather than the score, so it
  /// still reads as "how did this go" without smuggling a percentage back in.
  double get ringValue => switch (tier) {
        FeedbackTier.radiant => 1.0,
        FeedbackTier.warm => 0.8,
        FeedbackTier.steady => 0.6,
        FeedbackTier.gentle => 0.4,
      };
}

class PositiveFeedbackEngine {
  const PositiveFeedbackEngine._();

  static PositiveFeedback build({
    required GameDefinition game,
    required GamePerformance performance,
    required AdaptiveDecision decision,
    required AppLocalizations l,
  }) {
    final FeedbackTier tier = feedbackTierFor(performance.overall);

    final String headline = switch (tier) {
      FeedbackTier.radiant => l.resultWonderful,
      FeedbackTier.warm => l.resultVeryWellDone,
      FeedbackTier.steady => l.resultNicelyDone,
      FeedbackTier.gentle => l.resultThankYouForTrying,
    };

    final String body = switch (tier) {
      FeedbackTier.radiant => l.resultPraiseHigh,
      FeedbackTier.warm => l.resultPraiseMid,
      FeedbackTier.steady => l.resultPraiseSteady,
      FeedbackTier.gentle => l.resultPraiseIncomplete,
    };

    final CompanionState companionState =
        tier == FeedbackTier.radiant || tier == FeedbackTier.warm
            ? CompanionState.celebrating
            : CompanionState.encouraging;

    return PositiveFeedback(
      tier: tier,
      headline: headline,
      body: body,
      domainNote: _domainNote(game.domain),
      nextSessionNote: decision.direction.patientMessage,
      companionState: companionState,
      celebrate: tier == FeedbackTier.radiant || tier == FeedbackTier.warm,
    );
  }

  /// One warm, non-numeric line about what kind of thinking the activity
  /// asked for — plain hardcoded copy, matching the precedent already set by
  /// `DifficultyDirectionX.patientMessage` (`game.dart`), which isn't routed
  /// through localization either.
  static String _domainNote(CognitiveDomain? domain) => switch (domain) {
        CognitiveDomain.memory => 'You gave your memory a good, gentle workout today.',
        CognitiveDomain.attention => 'You stayed with it and kept your focus steady.',
        CognitiveDomain.reasoning => 'You thought your way through that story nicely.',
        CognitiveDomain.spatial => 'You found your way around really well.',
        CognitiveDomain.auditory => 'You listened closely and it showed.',
        CognitiveDomain.procedural => 'You worked through the steps in good order.',
        null => 'Thank you for spending this time together.',
      };
}
