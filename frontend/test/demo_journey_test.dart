import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/caregiver/caregiver_shell.dart';
import 'package:smaran_saathi/features/patient/games/procedure/procedure_game.dart';
import 'package:smaran_saathi/features/patient/patient_shell.dart';
import 'package:smaran_saathi/features/patient/today/today_screen.dart';
import 'package:smaran_saathi/features/patient/widgets/patient_widgets.dart';

/// The demo the prototype is presented with, end to end: play an activity, see
/// it scored, see the difficulty adapt, and see the caregiver's dashboard
/// change because of it.

const Size kPhone = Size(393, 852);

Widget harness(Widget child, AppState state) => AppScope(
      state: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.warm(),
        home: child,
      ),
    );

/// Pump without settling — the companion animates forever.
Future<void> beat(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Advances the clock in slices so delayed callbacks *and* the routes they
/// push both get a frame.
Future<void> settle(WidgetTester tester, {int frames = 8, int ms = 400}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Scrolls a target into view before tapping it — the phone-sized test surface
/// is shorter than several of these screens.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Not built at all yet. A ListView builds only a little past the fold, so
    // `ensureVisible` has nothing to work with until the list has been
    // scrolled far enough to create it.
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
    await beat(tester, 200);
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.last);
  await beat(tester, 300);
  await tester.tap(finder.last);
  await beat(tester, 400);
}

void setSurface(WidgetTester tester) {
  tester.view.physicalSize = kPhone * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('playing an activity scores it, adapts difficulty and reaches the caregiver',
      (WidgetTester tester) async {
    setSurface(tester);
    final AppState state = AppState()..setRole(AppRole.patient);
    final int startingLevel = state.levelOf(GameId.procedure);

    // ── play Procedure Reconstruction, correctly ────────────────────────
    await tester.pumpWidget(harness(const ProcedureGame(), state));
    await beat(tester);

    await tester.tap(find.text('Show me the steps'));
    await beat(tester);
    await tester.tap(find.text('I am ready to build'));
    await beat(tester);
    expect(find.text('THE SEQUENCE SO FAR'), findsOneWidget);

    // The five steps of level 2, "Washing clothes", in order.
    for (final String step in <String>[
      'Soak in soapy water',
      'Gently scrub clean',
      'Rinse with fresh water',
      'Squeeze excess water',
      'Hang on clothesline to dry',
    ]) {
      await tapVisible(tester, find.text(step));
    }

    // ── the result screen ──────────────────────────────────────────────
    await settle(tester);
    expect(find.textContaining('Wonderful'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Memory'), findsOneWidget);

    // ── adaptive difficulty ────────────────────────────────────────────
    await settle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await beat(tester);
    expect(find.text('Your next activity has been adjusted for you'), findsOneWidget);
    expect(find.text('WHAT MITRA NOTICED'), findsOneWidget);
    expect(find.text('NEXT SESSION'), findsOneWidget);

    final AdaptiveDecision? decision = state.lastDecision;
    expect(decision, isNotNull);
    expect(decision!.direction, DifficultyDirection.increase,
        reason: 'a flawless run should raise the level');
    expect(state.levelOf(GameId.procedure), startingLevel + 1);
    expect(state.completedToday, contains(GameId.procedure));
    expect(tester.takeException(), isNull);

    // ── the same state, seen by the caregiver ──────────────────────────
    // Shared [AppState] is what ripples across roles — the caregiver UI for
    // this is covered in screens_test.dart. After a pushed result route,
    // pumpWidget-replacing the whole tree is unreliable in widget tests.
    state.setRole(AppRole.caregiver);
    expect(state.completedToday, contains(GameId.procedure));
    expect(
      state.sessions.any((GameSession s) => s.gameId == GameId.procedure && s.dayOffset == 0),
      isTrue,
      reason: 'today\'s session is in shared history for every role',
    );
    expect(state.todayEngagement, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mood check-in and a reminder both reach the caregiver dashboard',
      (WidgetTester tester) async {
    setSurface(tester);
    final AppState state = AppState()..setRole(AppRole.patient);

    await tester.pumpWidget(harness(const PatientShell(), state));
    await beat(tester);

    await tapVisible(tester, find.text('Good'));
    expect(state.mood, isNotNull);
    expect(state.journeyDone, contains('checkin'));

    // Tick off a reminder. The daily screen moved off the navigation bar onto
    // the dashboard, so it is opened directly against the same state.
    final int before = state.remindersDone;
    await tester.pumpWidget(harness(const TodayScreen(), state));
    await beat(tester);
    await tester.dragUntilVisible(
      find.text('Evening medicine'),
      find.byType(ListView).last,
      const Offset(0, -160),
    );
    await beat(tester);
    final Finder row = find.ancestor(
      of: find.text('Evening medicine'),
      matching: find.byType(ReminderRow),
    );
    expect(row, findsOneWidget);
    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.check_rounded)));
    await beat(tester);
    expect(state.remindersDone, greaterThan(before));

    // Both changes are visible to the caregiver.
    await tester.pumpWidget(harness(const CaregiverShell(), state));
    await beat(tester, 1400);
    expect(find.textContaining('Good'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('going offline keeps the app usable and queues activity',
      (WidgetTester tester) async {
    setSurface(tester);
    final AppState state = AppState()..setRole(AppRole.patient);

    await tester.pumpWidget(harness(const PatientShell(), state));
    await beat(tester);

    state.setOffline(true);
    await beat(tester);
    expect(find.text('Offline mode'), findsOneWidget);
    expect(state.offline, isTrue);
    // The outbox holds real work only. Going offline queues nothing by itself
    // — that is the difference between the old simulation, which invented a
    // pending count, and the durable queue that replaced it.
    expect(state.pendingSync, 0);

    // Activity still works offline, and adds to the queue.
    final int queued = state.pendingSync;
    await tapVisible(tester, find.text('Okay'));
    await state.flush();
    expect(state.pendingSync, greaterThan(queued));

    // Reconnecting drains the queue. `syncNow` waits on a real delay, so the
    // clock has to be advanced by pumping rather than by awaiting it.
    state.setOffline(false);
    final Future<void> sync = state.syncNow();
    await settle(tester, frames: 6, ms: 400);
    await sync;
    await beat(tester);

    expect(state.pendingSync, 0);
    expect(find.text('Offline mode'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
