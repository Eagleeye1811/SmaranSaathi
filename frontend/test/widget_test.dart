import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:smaran_saathi/app/app.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/services/adaptive_difficulty_service.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/patient/patient_shell.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

/// Walks past the two-second splash.
///
/// Pumped in short steps rather than one long frame: the splash's timer and
/// the route transition it starts both need frames to land, and a single large
/// pump leaves the transition mid-flight.
Future<void> passSplash(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets('the splash hands over to the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmaranSaathiApp());
    await passSplash(tester);

    // What the product is, before anything is asked for.
    expect(find.text('Understand your\ncognitive health.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    // With no auth service configured the sign-in step is skipped and the
    // journey continues straight to the role picker.
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Welcome to SmaranSaathi'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Caregiver'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
  });

  testWidgets('selecting Patient starts the structured intake',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SmaranSaathiApp());
    await passSplash(tester);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Patient'));
    // The companion breathes forever, so the tree never "settles".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // A person with no completed assessment lands on consent, not on games.
    expect(find.text('Before we begin'), findsOneWidget);
    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.text('Your symptoms'), findsOneWidget);
  });

  testWidgets('the patient shell exposes the monitoring journey',
      (WidgetTester tester) async {
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PatientShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // The daily check-in now sits below the session card, so on a small test
    // surface it is not built until the list is scrolled.
    await tester.scrollUntilVisible(
      find.text('How are you feeling today?'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('How are you feeling today?'), findsOneWidget);
    // The four patient destinations are always labelled, never icon-only.
    for (final String label in <String>[
      'Home',
      'Activities',
      'Companion',
      'Profile',
    ]) {
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
