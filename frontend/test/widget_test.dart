import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/app/app.dart';
import 'package:memory_mitra/core/models/game.dart';
import 'package:memory_mitra/core/services/adaptive_difficulty_service.dart';

void main() {
  // The app opens on a brief branded splash before role selection — see
  // `features/auth/splash_screen.dart`. 1200ms clears its 1100ms timer.
  const Duration pastSplash = Duration(milliseconds: 1200);

  testWidgets('role selection is the entry point', (WidgetTester tester) async {
    await tester.pumpWidget(const MemoryMitraApp());
    await tester.pump();
    await tester.pump(pastSplash);
    await tester.pump();

    expect(find.text('Welcome to MemoryMitra'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Caregiver'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
  });

  testWidgets('selecting Patient opens the companion home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MemoryMitraApp());
    await tester.pump();
    await tester.pump(pastSplash);
    await tester.pump();

    await tester.tap(find.text('Patient'));
    // The companion breathes forever, so the tree never "settles".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('How are you feeling today?'), findsOneWidget);
    // The five patient destinations are always labelled, never icon-only.
    for (final String label in <String>['Home', 'Games', 'Memories', 'Today', 'Profile']) {
      expect(find.text(label), findsWidgets, reason: 'missing $label tab');
    }
  });

  group('AdaptiveDifficultyService', () {
    const AdaptiveDifficultyService service = AdaptiveDifficultyService();

    test('raises the level on high accuracy with few hints', () {
      final AdaptiveDecision d = service.evaluate(
        gameId: GameId.procedure,
        currentLevel: 2,
        performance: const GamePerformance(
          accuracy: 90,
          focus: 88,
          memory: 86,
          hintsUsed: 1,
          mistakes: 1,
          seconds: 40,
          completed: true,
        ),
      );
      expect(d.direction, DifficultyDirection.increase);
      expect(d.nextLevel, 3);
    });

    test('holds the level in the comfortable band', () {
      final AdaptiveDecision d = service.evaluate(
        gameId: GameId.weaves,
        currentLevel: 3,
        performance: const GamePerformance(
          accuracy: 72,
          focus: 70,
          memory: 68,
          hintsUsed: 2,
          mistakes: 3,
          seconds: 100,
          completed: true,
        ),
      );
      expect(d.direction, DifficultyDirection.maintain);
      expect(d.nextLevel, 3);
    });

    test('steps back when accuracy falls away', () {
      final AdaptiveDecision d = service.evaluate(
        gameId: GameId.memoryCards,
        currentLevel: 3,
        performance: const GamePerformance(
          accuracy: 41,
          focus: 50,
          memory: 45,
          hintsUsed: 3,
          mistakes: 8,
          seconds: 150,
          completed: true,
        ),
      );
      expect(d.direction, DifficultyDirection.decrease);
      expect(d.nextLevel, 2);
    });

    test('never drops below level 1 or rises above level 5', () {
      final AdaptiveDecision low = service.evaluate(
        gameId: GameId.melody,
        currentLevel: 1,
        performance: const GamePerformance(
          accuracy: 20,
          focus: 40,
          memory: 40,
          hintsUsed: 3,
          mistakes: 9,
          seconds: 90,
          completed: false,
        ),
      );
      expect(low.nextLevel, 1);

      final AdaptiveDecision high = service.evaluate(
        gameId: GameId.melody,
        currentLevel: 5,
        performance: const GamePerformance(
          accuracy: 98,
          focus: 95,
          memory: 95,
          hintsUsed: 0,
          mistakes: 0,
          seconds: 50,
          completed: true,
        ),
      );
      expect(high.nextLevel, 5);
    });
  });
}
