import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/app/theme/app_theme.dart';
import 'package:memory_mitra/core/models/assessment.dart';
import 'package:memory_mitra/core/models/game.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/core/widgets/ui_kit.dart';
import 'package:memory_mitra/data/mock/mock_data.dart';
import 'package:memory_mitra/features/intake/baseline_screens.dart';
import 'package:memory_mitra/features/intake/intake_flow.dart';
import 'package:memory_mitra/features/intake/steps_consent_profile.dart';
import 'package:memory_mitra/features/intake/steps_medical_caregiver.dart';
import 'package:memory_mitra/features/intake/steps_reason_safety.dart';
import 'package:memory_mitra/features/intake/steps_symptoms_function.dart';
import 'package:memory_mitra/features/intake/welcome_screens.dart';
import 'package:memory_mitra/features/patient/assistant/assistant_screen.dart';
import 'package:memory_mitra/features/patient/health/care_plan_screen.dart';
import 'package:memory_mitra/features/patient/health/cognitive_profile_screen.dart';
import 'package:memory_mitra/features/patient/health/health_dashboard_screen.dart';
import 'package:memory_mitra/features/patient/health/report_screen.dart';
import 'package:memory_mitra/l10n/app_localizations.dart';

/// Layout and behaviour cover for the monitoring journey.
///
/// Every screen the intake and the health surfaces add is rendered at four
/// device sizes and scrolled to the bottom, because `flutter_test` turns a
/// layout overflow into a failure and a questionnaire is exactly the kind of
/// screen that breaks on a narrow phone at large type.

const Size kPhoneSmall = Size(360, 690);
const Size kPhone = Size(393, 852);
const Size kPhoneLarge = Size(430, 932);
const Size kTablet = Size(834, 1112);

extension _Sizing on WidgetTester {
  void setSurface(Size size) {
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }
}

Widget harness(Widget child, {AppState? state}) {
  return AppScope(
    state: state ?? AppState(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.warm(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<void> beat(WidgetTester tester, [int ms = 500]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Pumps until the sync queue is actually empty, rather than guessing a fixed
/// wait: `SyncManager` drains queued operations one at a time (~180ms each via
/// `LoopbackTransport`), so a run with more queued operations than another
/// needs proportionally more real time, not a fixed number of beats.
Future<void> drainSync(WidgetTester tester, AppState state, {int maxBeats = 20}) async {
  for (int i = 0; i < maxBeats && state.pendingSync > 0; i++) {
    await beat(tester, 200);
  }
}

/// The plain-`test()` equivalent of [drainSync] — no `WidgetTester` exists in
/// that context (that is the point: it keeps the widget binding, and its
/// pending-timer assertion, out of the way), so this polls with a real delay
/// instead of pumping one.
Future<void> drainSyncPlain(AppState state, {int maxBeats = 20}) async {
  for (int i = 0; i < maxBeats && state.pendingSync > 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// Drags the screen's scrollable to the bottom so every card is laid out.
Future<void> scrollThrough(WidgetTester tester) async {
  final Finder list = find.byType(Scrollable).first;
  for (int i = 0; i < 4; i++) {
    await tester.drag(list, const Offset(0, -600));
    await beat(tester, 200);
  }
}

/// A state whose baseline has been captured, so the health screens have
/// something real to draw.
Future<AppState> monitoredState() async {
  final AppState state = AppState()..setRole(AppRole.patient);
  await state.loadDemoJourney(now: DateTime(2026, 8, 28));
  return state;
}

void main() {
  group('every intake step lays out on every handset', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('large phone', kPhoneLarge),
      ('tablet', kTablet),
    ]) {
      testWidgets('· $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.patient);
        addTearDown(state.dispose);

        final List<(String, Widget)> steps = <(String, Widget)>[
          ('welcome', const WelcomeScreen()),
          ('consent', ConsentStep(onDone: () {})),
          ('profile', ProfileStep(onDone: () {})),
          ('reason', ReasonStep(onDone: () {})),
          ('safety', SafetyStep(onDone: () {})),
          ('symptoms', SymptomStep(onDone: () {})),
          ('function', FunctionStep(onDone: () {})),
          ('medical', MedicalStep(onDone: () {})),
          ('caregiver', CaregiverStep(onDone: () {})),
          ('baseline intro', BaselineIntroScreen(onBegin: () {})),
        ];

        for (final (String label, Widget screen) in steps) {
          await tester.pumpWidget(harness(screen, state: state));
          await beat(tester);
          await scrollThrough(tester);
          expect(tester.takeException(), isNull, reason: '$label broke on $name');
        }
      });
    }
  });

  group('every health screen lays out on every handset', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('tablet', kTablet),
    ]) {
      testWidgets('· $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = await monitoredState();
        addTearDown(state.dispose);

        final List<(String, Widget)> screens = <(String, Widget)>[
          ('dashboard', const HealthDashboardScreen()),
          ('cognitive profile', const CognitiveProfileScreen()),
          ('first-time profile', CognitiveProfileScreen(firstTime: true, onContinue: () {})),
          ('report', const ReportScreen()),
          ('care plan', const CarePlanScreen()),
          ('assistant', const AssistantScreen()),
        ];

        for (final (String label, Widget screen) in screens) {
          await tester.pumpWidget(harness(screen, state: state));
          await beat(tester);
          await scrollThrough(tester);
          expect(tester.takeException(), isNull, reason: '$label broke on $name');
        }
      });
    }
  });

  testWidgets('consent gates the intake until it is understood',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);
    bool advanced = false;

    await tester.pumpWidget(
      harness(ConsentStep(onDone: () => advanced = true), state: state),
    );
    await beat(tester);

    // Continue does nothing until the statement is acknowledged.
    await tester.tap(find.text('Continue'));
    await beat(tester);
    expect(advanced, isFalse);
    expect(state.intake.consentGiven, isFalse);

    await tester.dragUntilVisible(
      find.textContaining('not a medical diagnosis'),
      find.byType(Scrollable).first,
      const Offset(0, -160),
    );
    await beat(tester);
    await tester.tap(find.textContaining('not a medical diagnosis').last);
    await beat(tester);
    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(advanced, isTrue);
    expect(state.intake.consentGiven, isTrue);
    expect(state.nextIntakeStep, IntakeStep.profile);
  });

  testWidgets('one answer covers a group with nothing to report',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    await tester.pumpWidget(harness(SymptomStep(onDone: () {}), state: state));
    await beat(tester);

    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('Step 5 of 8'), findsOneWidget);

    // "Next group" stays inert until the group has been answered at all.
    await tester.tap(find.text('Next group'));
    await beat(tester);
    expect(find.text('Memory'), findsOneWidget);

    // One tap on the stem question answers for everything the group lists.
    await tester.tap(find.text('Never').first);
    await beat(tester);
    await tester.tap(find.text('Next group'));
    await beat(tester);

    expect(find.text('Attention & thinking'), findsOneWidget);
    expect(state.intake.symptoms.isDomainComplete(SymptomDomain.memory), isTrue);
    expect(state.intake.symptoms.severity(SymptomDomain.memory), 0);
  });

  testWidgets('a group with something happening opens up for detail',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    await tester.pumpWidget(harness(SymptomStep(onDone: () {}), state: state));
    await beat(tester);

    final SymptomItem first = SymptomCatalogue.of(SymptomDomain.memory).first;
    // Before the stem is answered, the individual questions are not shown.
    expect(find.text(first.text), findsNothing);

    await tester.tap(find.text('Sometimes').first);
    await beat(tester);

    // Now they are, pre-filled with what was just said.
    await tester.dragUntilVisible(
      find.text(first.text),
      find.byType(Scrollable).first,
      const Offset(0, -140),
    );
    await beat(tester);
    expect(find.text(first.text), findsOneWidget);
    expect(state.intake.symptoms.isDomainComplete(SymptomDomain.memory), isFalse,
        reason: 'nothing is saved until the group is left');

    await tester.tap(find.text('Next group'));
    await beat(tester);
    expect(state.intake.symptoms.isDomainComplete(SymptomDomain.memory), isTrue);
    expect(state.intake.symptoms.severity(SymptomDomain.memory), closeTo(33.3, 0.5));
  });

  testWidgets('everyday activities start ticked, so independence needs no taps',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    bool done = false;
    await tester.pumpWidget(
      harness(FunctionStep(onDone: () => done = true), state: state),
    );
    await beat(tester);

    // Continue is live immediately: the person managing everything answers
    // this screen without touching it.
    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(done, isTrue);
    expect(state.intake.function.isComplete, isTrue);
    expect(state.intake.function.independencePercent, 100);
    expect(state.intake.function.needingHelp, isEmpty);
  });

  testWidgets('unticking an activity asks how much help, and only then',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    await tester.pumpWidget(harness(FunctionStep(onDone: () {}), state: state));
    await beat(tester);

    expect(find.text('A little'), findsNothing);

    final FunctionalItem item = FunctionCatalogue.items.first;
    await tester.tap(find.text(item.label));
    await beat(tester);

    expect(find.text('A little'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('A lot'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await beat(tester);
    await tester.tap(find.text('A lot'));
    await beat(tester);

    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(state.intake.function.levels[item.id], FunctionLevel.dependent);
    expect(state.intake.function.needingHelp, hasLength(1));
    expect(state.intake.function.independencePercent, lessThan(100));
  });

  testWidgets('the flow resumes at the first unanswered step',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    state.giveConsent();
    state.saveIntakeProfile(
      name: 'Rahul Sharma',
      age: 67,
      language: 'Hindi',
      occupation: 'Teacher',
      completedBy: CompletedBy.patient,
    );

    await tester.pumpWidget(
      harness(IntakeFlowScreen(onFinished: () {}), state: state),
    );
    // Two beats: saving the answers queues sync operations, and the loopback
    // transport's delay has to elapse before the test ends or the binding
    // fails on a pending timer.
    await beat(tester, 400);
    await beat(tester, 400);

    // Straight to the concerns step, skipping consent and the profile.
    expect(find.text('What brings you here?'), findsOneWidget);
    expect(find.text('Step 3 of 8'), findsOneWidget);
  });

  testWidgets('a daily session shows only that day\'s two activities',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      harness(BaselineSessionScreen(onComplete: () {}), state: state),
    );
    await beat(tester);
    expect(find.text('Day 1 of 3'), findsOneWidget);
    expect(find.text('0 of 6 activities across the three days'), findsOneWidget);
    // Only the two planned for day one, not all six.
    for (final GameId id in AppState.baselinePlan.first) {
      expect(find.text(MockData.game(id).name), findsOneWidget);
    }
    for (final GameId id in AppState.baselinePlan[1]) {
      expect(find.text(MockData.game(id).name), findsNothing);
    }

    // Finishing the pair closes the day and stamps it, so the next session
    // waits for tomorrow rather than for the next tap.
    for (final GameId id in AppState.baselinePlan.first) {
      state.markBaselineActivity(id, now: DateTime(2026, 6, 1));
    }
    await beat(tester);
    expect(state.baselineDayIndex, 1);
    expect(state.canStartBaselineSession(now: DateTime(2026, 6, 1)), isFalse);
    expect(state.canStartBaselineSession(now: DateTime(2026, 6, 2)), isTrue);

    // …unless the person says they have time now, which the demo needs.
    state.unlockNextBaselineDay();
    expect(state.canStartBaselineSession(now: DateTime(2026, 6, 1)), isTrue);
  });

  test('the three days cover all six activities and capture the baseline',
      () async {
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    expect(state.baselineReady, isFalse);
    for (int day = 0; day < AppState.baselinePlan.length; day++) {
      for (final GameId id in AppState.baselinePlan[day]) {
        state.markBaselineActivity(id, now: DateTime(2026, 6, 1 + day));
      }
    }
    expect(state.baselineRunComplete, isTrue);
    expect(state.baselineDayIndex, AppState.baselinePlan.length);

    await state.captureBaseline(now: DateTime(2026, 6, 3));
    expect(state.baseline, isNotNull);
    expect(state.baselineReady, isTrue);
    expect(state.intakeComplete, isTrue);
  });

  test('finishing the questionnaire opens the app without a baseline',
      () async {
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    expect(state.intake.isComplete, isFalse);
    state.completeIntakeQuestionnaire(now: DateTime(2026, 6, 1));
    // The dashboard gate is the questionnaire; the profile is three days away.
    expect(state.intake.isComplete, isTrue);
    expect(state.baselineReady, isFalse);
    expect(state.baselineDayIndex, 0);
  });

  testWidgets('the assistant answers a quick action from the record',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = await monitoredState();
    addTearDown(state.dispose);

    await tester.pumpWidget(harness(const AssistantScreen(), state: state));
    await beat(tester);

    await tester.tap(find.text('Explain my results'));
    await beat(tester);

    // Grounded in this person's own numbers, and carrying the caveat.
    expect(find.textContaining('not a diagnosis'), findsWidgets);
    expect(find.textContaining('baseline'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a red-flag answer warns in place without stopping the intake',
      (WidgetTester tester) async {
    tester.setSurface(kPhoneSmall);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);
    bool advanced = false;

    await tester.pumpWidget(
      harness(SafetyStep(onDone: () => advanced = true), state: state),
    );
    await beat(tester);

    // No warning until something is actually reported.
    expect(find.text('This may need a doctor, not an app'), findsNothing);

    // "Yes" to the sudden-onset question is the red flag.
    await tester.tap(find.text('Yes').first);
    await beat(tester);

    expect(find.text('This may need a doctor, not an app'), findsOneWidget);
    expect(find.text('Consult a doctor'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the warning must not overflow');

    // The advice is available, and closing it returns to the questionnaire.
    await tester.tap(find.text('Consult a doctor'));
    await beat(tester);
    expect(find.text('Please seek medical attention'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await beat(tester);
    expect(find.text('Please seek medical attention'), findsNothing);

    // Answer the rest; the journey continues rather than being taken over.
    for (final String question in <String>[
      'Does alertness or confusion change markedly through the day — clear at times, very confused at others?',
      'Any recent sudden weakness, difficulty speaking, fainting, seizure or severe headache?',
    ]) {
      await tester.dragUntilVisible(
        find.text(question),
        find.byType(Scrollable).first,
        const Offset(0, -160),
      );
      await beat(tester, 150);
      final Finder card = find.ancestor(of: find.text(question), matching: find.byType(MmCard));
      await tester.tap(find.descendant(of: card, matching: find.text('No')));
      await beat(tester, 150);
    }
    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(advanced, isTrue);
    expect(state.intake.safety.requiresUrgentReview, isTrue);
  });

  // Plain test: this exercises AppState alone, and the sync outbox keeps its
  // own real timers, which the widget binding would flag as pending.
  test('the baseline is built from the activities just played', () async {
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    // Nothing is invented for a new person: no sample fortnight, no scores.
    expect(state.sessions, isEmpty);
    expect(state.cognitiveProfile.scores, isEmpty);
    expect(state.monitoring.hasBaseline, isFalse);

    for (final GameId id in GameId.values) {
      state.finishGame(
        id,
        const GamePerformance(
          accuracy: 52,
          focus: 52,
          memory: 52,
          hintsUsed: 2,
          mistakes: 4,
          seconds: 150,
          completed: true,
          attempts: 10,
          correct: 5,
          responseMillis: 15000,
        ),
      );
      state.markBaselineActivity(id);
    }
    await state.captureBaseline(now: DateTime(2026, 8, 29));
    // Let the queued sync drain, or the binding fails on a pending timer.
    // Six activities each queue an operation, and SyncManager drains them
    // one at a time (~180ms via LoopbackTransport) — a fixed couple of beats
    // isn't reliably enough real time for all of them, so poll instead.
    await drainSyncPlain(state);

    final double? memoryBaseline = state.baseline?.scoreFor(CognitiveDomain.memory);
    expect(memoryBaseline, isNotNull);
    expect(memoryBaseline, closeTo(52, 0.5),
        reason: 'the baseline must come from the activities the person played');
    expect(state.cognitiveProfile.scores, isNotEmpty);
  });

  testWidgets('a failed capture leaves the button usable instead of bricking it',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = _ThrowingAppState();
    addTearDown(state.dispose);
    for (final GameId id in GameId.values) {
      state.markBaselineActivity(id);
    }

    bool completed = false;
    await tester.pumpWidget(
      harness(BaselineSessionScreen(onComplete: () => completed = true), state: state),
    );
    await beat(tester);

    await tester.tap(find.text('See my profile'));
    await beat(tester, 400);

    expect(completed, isFalse);
    expect(find.textContaining('could not be built'), findsOneWidget);
    // And it can be retried rather than being a dead end.
    expect(
      tester.widget<BigButton>(find.byType(BigButton).last).onPressed,
      isNotNull,
    );
  });
}

/// An `AppState` whose baseline capture fails, standing in for a full disk or
/// a locked box at the worst possible moment.
class _ThrowingAppState extends AppState {
  @override
  Future<void> captureBaseline({DateTime? now}) async =>
      throw StateError('storage unavailable');
}
