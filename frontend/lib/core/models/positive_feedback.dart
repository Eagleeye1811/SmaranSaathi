import '../widgets/companion.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/content_labels.dart';
import 'game.dart';
import 'patient.dart';

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
    this.personalNote,
  });

  final FeedbackTier tier;
  final String headline;
  final String body;
  final String domainNote;
  final String nextSessionNote;
  final CompanionState companionState;
  final bool celebrate;

  /// One or two sentences that could only be about *this* person: what they
  /// have done with this activity before, and something the profile knows
  /// about their life.
  ///
  /// Null when there is nothing true to say — a brand-new profile with no
  /// details filled in and no history yet. The screen simply omits the card,
  /// because an empty compliment is worse than none.
  final String? personalNote;

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

  /// [patient] and [sessions] are what make the result personal.
  ///
  /// [sessions] is the full history, newest first, *including the session
  /// that has just been recorded* — `AppState.finishGame` inserts it at index
  /// 0 before this screen is pushed, so the engine drops the newest entry for
  /// this activity itself rather than the caller having to remember to.
  static PositiveFeedback build({
    required GameDefinition game,
    required GamePerformance performance,
    required AdaptiveDecision decision,
    required AppLocalizations l,
    Patient? patient,
    List<GameSession> sessions = const <GameSession>[],
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
      personalNote: patient == null
          ? null
          : _personalNote(
              game: game,
              gameName: game.localizedName(l),
              tier: tier,
              patient: patient,
              sessions: sessions,
            ),
    );
  }

  // ── Personalisation ──────────────────────────────────────────────────────
  //
  // Every branch below is positive or silent. Nothing here ever reports a
  // decline, not even gently: the screen a patient reads straight after a
  // hard session should not mention that it was a hard one. When there is
  // nothing encouraging and true to say, the sentence is dropped.

  static String? _personalNote({
    required GameDefinition game,
    required String gameName,
    required FeedbackTier tier,
    required Patient patient,
    required List<GameSession> sessions,
  }) {
    final List<String> parts = <String>[
      ?_historySentence(
          game: game, gameName: gameName, tier: tier, sessions: sessions),
      ?_lifeSentence(domain: game.domain, patient: patient),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// What they have done with this activity before — never a count of how
  /// well, only that they showed up and kept showing up.
  static String? _historySentence({
    required GameDefinition game,
    required String gameName,
    required FeedbackTier tier,
    required List<GameSession> sessions,
  }) {
    final List<GameSession> sameGame = sessions
        .where((GameSession s) => s.gameId == game.id)
        .toList(growable: false);
    // Index 0 is the session that has just been played; everything after it
    // is genuine history.
    final List<GameSession> prior =
        sameGame.length <= 1 ? const <GameSession>[] : sameGame.sublist(1);

    if (prior.isEmpty) {
      return 'That was your first time with $gameName, and you gave it a real go.';
    }

    final int running = _daysRunning(sessions);
    if (running >= 2) return 'That is ${_countWord(running)} running now.';

    final DateTime last = prior.first.playedAt;
    if (_isRealDate(last) && DateTime.now().difference(last).inDays >= 10) {
      return 'It has been a little while since $gameName. It is good to have '
          'you back with it.';
    }

    final FeedbackTier lastTier = feedbackTierFor(prior.first.performance.overall);
    // Enum order runs best-to-gentlest, so a lower index is a better session.
    if (tier.index < lastTier.index) {
      return 'That went even more smoothly than the last time you played it.';
    }
    if (tier == lastTier &&
        (tier == FeedbackTier.radiant || tier == FeedbackTier.warm)) {
      return 'You are keeping that up beautifully.';
    }
    return null;
  }

  /// Something only this person's profile knows, chosen to sit naturally
  /// beside the kind of thinking the activity asked for.
  static String? _lifeSentence({
    required CognitiveDomain? domain,
    required Patient patient,
  }) {
    String? on(String value, String Function(String) sentence) =>
        value.trim().isEmpty ? null : sentence(value.trim());

    final String? anchored = switch (domain) {
      CognitiveDomain.auditory =>
        on(patient.favouriteMusic, (String v) => '$v clearly still lives in your ear.'),
      CognitiveDomain.spatial =>
        on(patient.location, (String v) => 'You still know your way around $v.'),
      CognitiveDomain.procedural => on(patient.favouriteActivity,
          (String v) => 'The same steady hands you bring to $v.'),
      CognitiveDomain.reasoning || CognitiveDomain.attention => on(
          patient.occupation,
          (String v) => "A $v's eye for detail is still very much there."),
      CognitiveDomain.memory =>
        on(patient.tradition, (String v) => 'Memories of $v are in good keeping.'),
      null => null,
    };
    if (anchored != null) return anchored;

    // Nothing filled in for that domain — fall back to the person most likely
    // to be told about this anyway.
    final FamilyMember? relative = patient.primaryRelative;
    if (relative != null && relative.name.trim().isNotEmpty) {
      return '${relative.name.trim()} would be glad to hear how that went.';
    }
    return null;
  }

  /// Consecutive calendar days, counting back from today, on which *any*
  /// activity was played. Zero when today is missing, which makes the caller
  /// silent rather than wrong.
  static int _daysRunning(List<GameSession> sessions) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Set<int> daysAgo = <int>{};
    for (final GameSession s in sessions) {
      // A box written before `playedAt` existed reads back as the epoch.
      // Counting those would invent a streak, so they are skipped.
      if (!_isRealDate(s.playedAt)) continue;
      final DateTime d =
          DateTime(s.playedAt.year, s.playedAt.month, s.playedAt.day);
      daysAgo.add(today.difference(d).inDays);
    }

    if (!daysAgo.contains(0)) return 0;
    int run = 0;
    while (daysAgo.contains(run)) {
      run++;
    }
    return run;
  }

  static bool _isRealDate(DateTime at) => at.isAfter(DateTime(2000));

  /// Words, never digits — a number on this screen is the one thing the
  /// result is not allowed to become.
  static String _countWord(int days) => switch (days) {
        2 => 'two days',
        3 => 'three days',
        4 => 'four days',
        5 => 'five days',
        6 => 'six days',
        7 => 'a full week of days',
        _ => 'more than a week of days',
      };

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
