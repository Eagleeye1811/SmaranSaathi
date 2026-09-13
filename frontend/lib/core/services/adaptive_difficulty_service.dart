import '../models/game.dart';

/// Simulated adaptive-difficulty engine.
///
/// In production this would be a model served from the backend. Here it is a
/// transparent rule set over the same signals a real model would consume —
/// accuracy, hints, mistakes, pace and completion — so the behaviour shown in
/// the demo is exactly the behaviour the real engine would need to reproduce.
class AdaptiveDifficultyService {
  const AdaptiveDifficultyService();

  static const int maxLevel = 5;
  static const int minLevel = 1;

  /// Expected completion time in seconds at a given level, used to judge pace.
  static int expectedSeconds(GameId id, int level) {
    final int base = switch (id) {
      GameId.procedure => 40,
      GameId.story => 110,
      GameId.familiarPlace => 120,
      GameId.melody => 45,
      GameId.weaves => 70,
      GameId.memoryCards => 70,
      GameId.villageMarket => 90,
      // Never actually consulted — Mood Canvas doesn't go through evaluate().
      GameId.moodCanvas => 60,
    };
    return base + (level - 1) * (base * 0.28).round();
  }

  AdaptiveDecision evaluate({
    required GameId gameId,
    required int currentLevel,
    required GamePerformance performance,
  }) {
    final double accuracy = performance.accuracy;
    final int hints = performance.hintsUsed;
    final int expected = expectedSeconds(gameId, currentLevel);
    final double pace = performance.seconds / expected;

    final List<String> signals = <String>[
      'Accuracy ${accuracy.round()}%',
      'Hints used $hints',
      'Mistakes ${performance.mistakes}',
      pace <= 0.85
          ? 'Faster than usual'
          : pace >= 1.35
              ? 'Slower than usual'
              : 'Steady pace',
      performance.completed ? 'Activity completed' : 'Activity left unfinished',
    ];

    DifficultyDirection direction;
    String reason;

    if (!performance.completed) {
      direction = DifficultyDirection.decrease;
      reason = 'The activity was not finished, so the next one will be shorter and gentler.';
    } else if (accuracy > 85 && hints <= 1) {
      direction = DifficultyDirection.increase;
      reason =
          'High accuracy with almost no hints: ${performance.accuracy.round()}% at level $currentLevel. '
          'The next session adds a step and reduces on-screen assistance.';
    } else if (accuracy >= 60) {
      direction = DifficultyDirection.maintain;
      reason =
          'Accuracy of ${accuracy.round()}% sits in the comfortable range. Level $currentLevel is '
          'still the right amount of challenge, so the content changes but the difficulty does not.';
    } else {
      direction = DifficultyDirection.decrease;
      reason =
          'Accuracy fell to ${accuracy.round()}% with $hints hint${hints == 1 ? '' : 's'}. '
          'The next session steps back so the activity stays encouraging.';
    }

    // Pace is a secondary signal: a very slow but accurate session holds level.
    if (direction == DifficultyDirection.increase && pace > 1.6) {
      direction = DifficultyDirection.maintain;
      reason =
          'Accuracy was excellent but the session took noticeably longer than usual, so the level '
          'is held steady rather than raised.';
      signals.add('Pace held the level steady');
    }

    final int nextLevel = switch (direction) {
      DifficultyDirection.increase => (currentLevel + 1).clamp(minLevel, maxLevel),
      DifficultyDirection.decrease => (currentLevel - 1).clamp(minLevel, maxLevel),
      DifficultyDirection.maintain => currentLevel,
    };

    return AdaptiveDecision(
      direction: direction,
      nextLevel: nextLevel,
      reason: reason,
      signals: signals,
    );
  }

  /// Short description of what a level means, shown in the caregiver view.
  static String levelDescription(GameId id, int level) {
    switch (id) {
      case GameId.procedure:
        return switch (level) {
          1 => '4 steps, pictures and words',
          2 => '5 steps, pictures and words',
          3 => '6 steps, pictures and words',
          4 => '6 steps, less visual assistance',
          _ => 'Personal procedure from her own life',
        };
      case GameId.story:
        return switch (level) {
          1 => 'Short story, three choices',
          2 => 'Story recall and everyday reasoning',
          3 => 'Longer story, four choices',
          _ => 'Personal photograph, open storytelling',
        };
      case GameId.familiarPlace:
        return switch (level) {
          1 => '3 objects, 3 rooms, 3 hints',
          2 => '3 objects, 4 rooms, 2 hints',
          3 => '4 objects, 4 rooms, 2 hints',
          _ => '4 objects, 5 rooms, 1 hint',
        };
      case GameId.melody:
        return switch (level) {
          1 => '2 sounds',
          2 => '3 sounds',
          3 => '4 sounds',
          4 => '4 sounds, faster',
          _ => '5 sounds, longer sequence',
        };
      case GameId.weaves:
        return switch (level) {
          1 => 'Match an identical motif',
          2 => 'Complete one missing tile',
          3 => 'Pattern hides before rebuilding',
          _ => 'Short preview, then rebuild from memory',
        };
      case GameId.memoryCards:
        return switch (level) {
          1 => '4 pairs',
          2 => '6 pairs',
          3 => '8 pairs',
          _ => '12 pairs',
        };
      case GameId.villageMarket:
        return switch (level) {
          1 => 'A calm first walk through the market',
          2 => 'A short list to keep in mind',
          3 => 'Market day, with a chance of rain',
          4 => 'Market day, watching the coin purse',
          _ => 'A full morning at the market, remembering it all',
        };
      // Never actually shown — Mood Canvas's GameShell has no level indicator.
      case GameId.moodCanvas:
        return 'Free drawing';
    }
  }
}
