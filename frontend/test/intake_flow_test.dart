import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/models/assessment.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/widgets/ui_kit.dart';
import 'package:smaran_saathi/data/mock/mock_data.dart';
import 'package:smaran_saathi/features/intake/baseline_screens.dart';
import 'package:smaran_saathi/core/models/onboarding.dart';
import 'package:smaran_saathi/features/caregiver/caregiver_entry.dart';
import 'package:smaran_saathi/features/caregiver/caregiver_shell.dart';
import 'package:smaran_saathi/features/intake/intake_kit.dart';
import 'package:smaran_saathi/features/intake/onboarding_summary_screen.dart';
import 'package:smaran_saathi/features/intake/step_consent.dart';
import 'package:smaran_saathi/features/intake/step_patient_username.dart';
import 'package:smaran_saathi/features/intake/steps_everyday.dart';
import 'package:smaran_saathi/features/intake/steps_life.dart';
import 'package:smaran_saathi/features/intake/steps_person_health.dart';
import 'package:smaran_saathi/features/intake/steps_support_safety.dart';
import 'package:smaran_saathi/features/intake/intake_flow.dart';
import 'package:smaran_saathi/features/intake/welcome_screens.dart';
import 'package:smaran_saathi/features/patient/assistant/assistant_screen.dart';
import 'package:smaran_saathi/features/patient/health/care_plan_screen.dart';
import 'package:smaran_saathi/features/patient/health/cognitive_profile_screen.dart';
import 'package:smaran_saathi/features/patient/health/health_dashboard_screen.dart';
import 'package:smaran_saathi/features/patient/health/report_screen.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

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

/// Scrolls the [index]th match of [finder] into view and taps it.
///
/// Hand-rolled rather than `dragUntilVisible` for two reasons these screens
/// both hit: a lazily-built list means the target often does not exist yet, so
/// any finder narrowed with `.first` throws before the scroll starts; and
/// `dragUntilVisible` stops as soon as the widget is technically on screen,
/// which can leave it under the fixed action bar where the tap lands on the
/// bar instead and the answer is silently lost.
Future<void> tapAfterScroll(WidgetTester tester, Finder finder, {int index = 0}) async {
  final Finder list = find.byType(Scrollable).first;
  // Back to the top first, so the walk is always downwards and the order in
  // which a test taps things does not matter.
  await tester.drag(list, const Offset(0, 6000));
  await beat(tester);

  final double height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (int step = 0; step < 80; step++) {
    if (finder.evaluate().length > index) {
      final Finder one = finder.at(index);
      final double dy = tester.getCenter(one).dy;
      if (dy > 60 && dy < height - 190) {
        await tester.tap(one);
        await beat(tester);
        return;
      }
    }
    await tester.drag(list, const Offset(0, -120));
    await beat(tester);
  }
  fail('never reached a tappable match for $finder');
}

/// Taps the first [target] that sits below [anchor] on screen.
///
/// Screens that carry several questions repeat the same answer words — "Yes",
/// "No", "Not sure" — so an index into all matches is meaningless when the
/// list builds lazily and the two may never exist at once. Anchoring to the
/// question the answer belongs to says what the test actually means.
Future<void> tapUnder(WidgetTester tester, Finder anchor, Finder target) async {
  final Finder list = find.byType(Scrollable).first;
  await tester.drag(list, const Offset(0, 6000));
  await beat(tester);

  final double height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (int step = 0; step < 80; step++) {
    if (anchor.evaluate().isNotEmpty) {
      final double anchorY = tester.getCenter(anchor.at(0)).dy;
      for (final Element element in target.evaluate()) {
        final Finder one =
            find.byElementPredicate((Element candidate) => identical(candidate, element));
        final double dy = tester.getCenter(one).dy;
        if (dy > anchorY && dy > 60 && dy < height - 190) {
          await tester.tap(one);
          await beat(tester);
          return;
        }
      }
    }
    await tester.drag(list, const Offset(0, -120));
    await beat(tester);
  }
  fail('never reached a $target below $anchor');
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

        // Seeded so the screens that only appear once something was answered
        // — the condition question, the follow-ups, the wandering history —
        // are rendered too. A screen that is never exercised is a screen that
        // overflows in the field.
        state.saveOnboarding(const OnboardingRecord(
          helper: HelperRole.child,
          education: EducationLevel.secondary,
          diagnosisStatus: DiagnosisStatus.yes,
          diagnosedConditions: <DiagnosedCondition>{DiagnosedCondition.lewyBody},
          treatmentStatus: TreatmentStatus.yes,
          sedatingMedicines: <SedatingMedicineClass>{
            SedatingMedicineClass.sleepOrAnxiety,
          },
          difficulties: <DailyDifficulty>{
            DailyDifficulty.misplacingThings,
            DailyDifficulty.gettingLost,
            DailyDifficulty.managingMedicines,
          },
          topDifficulties: <DailyDifficulty>[
            DailyDifficulty.misplacingThings,
            DailyDifficulty.gettingLost,
            DailyDifficulty.managingMedicines,
          ],
          onset: OnsetWindow.oneToTwoYears,
          course: ProgressionPattern.graduallyWorse,
          safetyConcerns: <SafetyConcern>{SafetyConcern.gettingLostOutside},
          wanderingHistory: IncidentFrequency.moreThanOnce,
          enjoys: <EnjoyedActivity>{EnjoyedActivity.music},
          goals: <SupportGoal>[SupportGoal.safety],
        ));

        final List<(String, Widget)> steps = <(String, Widget)>[
          ('welcome', const WelcomeScreen()),
          ('consent', ConsentStep(onDone: () {})),
          ('person', PersonStep(onDone: () {})),
          ('health', HealthBackgroundStep(onDone: () {})),
          ('everyday', EverydayStep(onDone: () {})),
          ('probes', ProbesStep(onDone: () {})),
          ('example', RecentExampleStep(onDone: () {})),
          ('independence', IndependenceStep(onDone: () {})),
          ('behaviour', BehaviourStep(onDone: () {})),
          ('safety', DailySafetyStep(onDone: () {})),
          ('strengths', StrengthsStep(onDone: () {})),
          ('goals', GoalsStep(onDone: () {})),
          ('patient username', PatientUsernameStep(onDone: () {})),
          ('summary', OnboardingSummaryScreen(onFinish: () {})),
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
    expect(state.nextIntakeStep, IntakeStep.person);
  });

  testWidgets('the biggest-difficulty question offers only what was reported',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    await tester.pumpWidget(harness(EverydayStep(onDone: () {}), state: state));
    await beat(tester);

    // Nothing is reported yet, so there is nothing to rank.
    expect(find.text('Which of these affects daily life the most?'), findsNothing);

    await tapAfterScroll(tester, find.widgetWithText(ChoiceTile, 'Misplacing things'));

    await tester.dragUntilVisible(
      find.text('Which of these affects daily life the most?'),
      find.byType(Scrollable).first,
      const Offset(0, -160),
    );
    await beat(tester);
    // Now it can be ranked, and nothing has been ranked yet.
    expect(find.text('0 of 3 chosen'), findsOneWidget);
  });

  testWidgets('no more than three difficulties can be named as the biggest',
      (WidgetTester tester) async {
    tester.setSurface(kTablet);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    await tester.pumpWidget(harness(EverydayStep(onDone: () {}), state: state));
    await beat(tester);

    // Listed in the order they appear on screen, so the walk down the list
    // only ever scrolls one way.
    const List<String> reported = <String>[
      'Repeating questions or stories',
      'Forgetting appointments or plans',
      'Misplacing things',
      'Changes in sleep',
    ];

    // The checklist rows and the ranking chips carry the same labels, so both
    // are addressed by their widget type rather than by text alone.
    Future<void> tapTile(String label) =>
        tapAfterScroll(tester, find.widgetWithText(ChoiceTile, label));

    Future<void> tapChip(String label) =>
        tapAfterScroll(tester, find.widgetWithText(ChipChoice, label));

    for (final String label in reported) {
      await tapTile(label);
    }
    for (final String label in reported.take(3)) {
      await tapChip(label);
    }

    expect(find.text('3 of 3 chosen'), findsOneWidget);
    expect(state.intake.onboarding.topDifficulties, isEmpty,
        reason: 'nothing is filed until Continue');

    // The fourth is refused rather than silently replacing one of the three.
    await tapChip(reported[3]);
    expect(find.text('3 of 3 chosen'), findsOneWidget);
  });

  testWidgets('the follow-ups asked are the ones the named difficulties raise',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    state.saveOnboarding(const OnboardingRecord(
      difficulties: <DailyDifficulty>{
        DailyDifficulty.misplacingThings,
        DailyDifficulty.managingMoney,
      },
      // Money was reported but not named as biggest, so it is not followed up.
      topDifficulties: <DailyDifficulty>[DailyDifficulty.misplacingThings],
    ));

    bool done = false;
    await tester.pumpWidget(
      harness(ProbesStep(onDone: () => done = true), state: state),
    );
    await beat(tester);

    expect(find.text('What do they most often misplace?'), findsOneWidget);

    // Continue stays inert until every follow-up shown has an answer.
    await tester.tap(find.text('Continue'));
    await beat(tester);
    expect(done, isFalse);

    for (final String answer in <String>[
      'Keys',
      'Occasionally',
      'They find it themselves',
    ]) {
      await tapAfterScroll(tester, find.widgetWithText(ChipChoice, answer));
    }

    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(done, isTrue);
    // The measured frequency, not the "it was named biggest" estimate.
    expect(state.intake.symptoms.responses['mem_misplace'], SymptomFrequency.sometimes);
    expect(state.intake.onboarding.probeChoice('probe_misplace_after'),
        'findsItThemselves');
  });

  testWidgets('every activity has to be answered before support is filed',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    bool done = false;
    await tester.pumpWidget(
      harness(IndependenceStep(onDone: () => done = true), state: state),
    );
    await beat(tester);

    // Nothing is assumed: an unanswered activity is unanswered, not
    // "independent", so Continue is inert until all eight are said.
    expect(find.text('0 of 8 answered'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await beat(tester);
    expect(done, isFalse);

    // Each activity is answered inside its own card, so a stray tap on the
    // wrong row would leave one unanswered and the assertions below would
    // catch it.
    for (final String activity in <String>[
      'Eating',
      'Dressing',
      'Bathing and hygiene',
      'Using the toilet',
      'Taking medicines',
      'Cooking and household tasks',
      'Managing money and bills',
      'Going outside and travelling',
    ]) {
      final Finder card = find.widgetWithText(ScaleQuestion, activity);
      await tapAfterScroll(tester,
          find.descendant(of: card, matching: find.text('On their own')));
    }

    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(done, isTrue);
    expect(state.intake.onboarding.independenceDone, isTrue);
    expect(state.intake.function.independencePercent, 100);
  });

  testWidgets('wandering opens a follow-up, and only wandering does',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);

    bool done = false;
    await tester.pumpWidget(
      harness(DailySafetyStep(onDone: () => done = true), state: state),
    );
    await beat(tester);

    await tapAfterScroll(
        tester, find.widgetWithText(ChoiceTile, 'Falling or losing balance'));
    expect(find.text('Has this happened before?'), findsNothing);

    await tapAfterScroll(
        tester, find.widgetWithText(ChoiceTile, 'Getting lost while outside'));
    await tester.dragUntilVisible(
      find.text('Has this happened before?'),
      find.byType(Scrollable).first,
      const Offset(0, -160),
    );
    await beat(tester);

    // And the screen cannot be left until that follow-up is answered.
    await tester.tap(find.text('Continue'));
    await beat(tester);
    expect(done, isFalse);

    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'More than once'));
    await tester.tap(find.text('Continue'));
    await beat(tester);

    expect(done, isTrue);
    expect(state.intake.onboarding.hasWanderingRisk, isTrue);
  });

  testWidgets('a caregiver can walk the whole onboarding end to end',
      (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState state = AppState()..setRole(AppRole.patient);
    addTearDown(state.dispose);
    bool finished = false;

    await tester.pumpWidget(
      harness(IntakeFlowScreen(onFinished: () => finished = true), state: state),
    );
    await beat(tester);

    Future<void> next() async {
      await tester.tap(find.text('Continue'));
      await beat(tester, 400);
    }

    // 1 · consent
    await tapAfterScroll(
        tester, find.widgetWithText(ChoiceTile, 'I understand this is not a medical diagnosis'));
    await next();

    // 2 · about the person
    await tester.enterText(find.byType(TextField).first, 'Aruna Devi');
    await beat(tester);
    await tester.enterText(find.byType(TextField).at(1), '72');
    await beat(tester);
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'Up to class 10'));
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'Weaver'));
    await tapAfterScroll(tester, find.widgetWithText(ChoiceTile, 'Son or daughter'));
    // Naming yourself is only asked of someone answering for another person,
    // and the field only exists once they have said they are one — so it has
    // to be scrolled into existence before it can be typed into.
    final Finder nameLabel = find.text('And your name?');
    await tester.dragUntilVisible(
        nameLabel, find.byType(Scrollable).first, const Offset(0, -120));
    await beat(tester);
    await tester.enterText(find.byType(TextField).last, 'Priya');
    await beat(tester);
    await next();

    // 3 · health and care background
    expect(find.text('Health and care so far'), findsOneWidget);
    // "Not sure" and "No" each appear twice on this screen, so each answer is
    // anchored to the numbered question it belongs to.
    await tapUnder(tester, find.widgetWithText(QuestionLabel, '2'),
        find.widgetWithText(ChoiceTile, 'Not sure'));
    await tapAfterScroll(
        tester, find.widgetWithText(ChipChoice, 'Family, or a caregiver at home'));
    await tapUnder(tester, find.widgetWithText(QuestionLabel, '5'),
        find.widgetWithText(ChoiceTile, 'No'));
    await next();

    // 4 · everyday difficulties, the ranking, and how long
    expect(find.text('What has changed in everyday life?'), findsWidgets);
    await tapAfterScroll(
        tester, find.widgetWithText(ChoiceTile, 'Forgetting recent conversations'));
    await tapAfterScroll(tester, find.widgetWithText(ChoiceTile, 'Misplacing things'));
    await tapAfterScroll(
        tester, find.widgetWithText(ChipChoice, 'Misplacing things'));
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, '6–12 months'));
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'Gradually worse'));
    await next();

    // 5 · the follow-ups that difficulty raised
    expect(find.text('A little more about those'), findsOneWidget);
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'Keys'));
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'Sometimes'));
    await tapAfterScroll(
        tester, find.widgetWithText(ChipChoice, 'They become worried or upset'));
    await next();

    // 6 · a recent example, which may be skipped but is not here
    await tester.enterText(
        find.byType(TextField).first, 'She looked for her keys for an hour on Tuesday.');
    await beat(tester);
    await next();

    // 7 · independence
    for (final String activity in <String>[
      'Eating',
      'Dressing',
      'Bathing and hygiene',
      'Using the toilet',
      'Taking medicines',
      'Cooking and household tasks',
      'Managing money and bills',
      'Going outside and travelling',
    ]) {
      final Finder card = find.widgetWithText(ScaleQuestion, activity);
      await tapAfterScroll(tester,
          find.descendant(of: card, matching: find.text('Needs reminders')));
    }
    await next();

    // 8 · mood and behaviour
    await tapAfterScroll(
        tester, find.widgetWithText(ChoiceTile, 'More irritable or short-tempered'));
    await next();

    // 9 · safety
    await tapAfterScroll(
        tester, find.widgetWithText(ChoiceTile, 'Forgetting medicines'));
    await next();

    // 10 · what they enjoy
    await tapAfterScroll(tester, find.widgetWithText(ChipChoice, 'Music'));
    await next();

    // 11 · what to help with
    await tapAfterScroll(
        tester, find.widgetWithText(ChipChoice, 'Remembering important things'));
    await next();

    // 12 · a doctor, offered rather than required — nothing here has to be
    // answered for the questionnaire to end.
    expect(find.text('Is a doctor involved?'), findsOneWidget);
    await next();

    // 13 · how the patient will sign in, also offered rather than required
    expect(find.text('Give them a way to sign in'), findsOneWidget);
    await tester.tap(find.text('Continue without setting this up'));
    await beat(tester, 400);

    // 14 · the summary reads the answers back before it lets go
    expect(find.text('Thank you'), findsOneWidget);
    expect(find.text('Misplacing things'), findsWidgets);
    expect(find.textContaining('Answered by'), findsOneWidget);
    await tester.tap(find.text('Open SmaranSaathi'));
    await beat(tester, 400);

    expect(finished, isTrue);
    expect(tester.takeException(), isNull);

    // The record is complete, and the structures the report reads were
    // derived on the way through rather than collected again.
    final OnboardingRecord answers = state.intake.onboarding;
    expect(answers.isComplete, isTrue);
    expect(state.intake.isComplete, isTrue);
    expect(answers.topDifficulties, <DailyDifficulty>[DailyDifficulty.misplacingThings]);
    expect(state.intake.symptoms.responses['mem_misplace'], SymptomFrequency.sometimes);
    expect(state.intake.function.levels['fn_meds'], FunctionLevel.needsHelp);
    expect(state.intake.caregiver, isNotNull,
        reason: 'a daughter answered, so the report has corroboration');
    expect(state.patient.name, 'Aruna Devi');
    expect(state.patient.occupation, 'Weaver');
    // And the caregiver has a profile of their own, not a stand-in name.
    expect(state.caregiverName, 'Priya');
    expect(state.hasCaregiverProfile, isTrue);
    expect(state.hasPatientProfile, isTrue);
  });

  group('the caregiver is the one who onboards', () {
    testWidgets('an unanswered record opens the onboarding, not the dashboard',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      addTearDown(state.dispose);

      await tester.pumpWidget(harness(const CaregiverEntry(), state: state));
      await beat(tester, 600);

      expect(find.text('Before we begin'), findsOneWidget);
      expect(find.byType(CaregiverShell), findsNothing);
    });

    testWidgets('a finished record opens the dashboard instead',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = await monitoredState();
      state.setRole(AppRole.caregiver);
      addTearDown(state.dispose);

      await tester.pumpWidget(harness(const CaregiverEntry(), state: state));
      await beat(tester, 600);

      expect(find.byType(CaregiverShell), findsOneWidget);
      expect(find.text('Before we begin'), findsNothing);
    });

    testWidgets('a half-finished onboarding resumes where the caregiver stopped',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      addTearDown(state.dispose);

      state.giveConsent();
      state.saveOnboarding(const OnboardingRecord(
        helper: HelperRole.spouse,
        caregiverName: 'Bhaskar',
        education: EducationLevel.primary,
      ));

      await tester.pumpWidget(harness(const CaregiverEntry(), state: state));
      await beat(tester, 600);

      // Not back at consent, and not at a dashboard either.
      expect(find.text('Health and care so far'), findsOneWidget);
      expect(find.text('Step 3 of 14'), findsOneWidget);
    });
  });

  group('step 1 can be left', () {
    testWidgets('back on step 1 returns to the screen that opened the intake',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);

      // The real stack: the welcome screen pushes the intake, so step 1 has
      // somewhere to go back to.
      await tester.pumpWidget(harness(
        Builder(builder: (BuildContext context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => IntakeFlowScreen(onFinished: () {}),
                  ),
                ),
                child: const Text('I am the patient'),
              ),
            ),
          );
        }),
        state: state,
      ));
      await beat(tester);

      await tester.tap(find.text('I am the patient'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 14'), findsOneWidget);

      // The button someone stuck on the first question reaches for.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('I am the patient'), findsOneWidget);
      expect(find.text('Step 1 of 14'), findsNothing);
    });

    testWidgets('leaving loses nothing: it resumes where it stopped',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);

      // Consent already given, so the flow resumes past step 1 rather than
      // asking again — which is what makes leaving safe to offer.
      state.giveConsent();

      await tester.pumpWidget(
        harness(IntakeFlowScreen(onFinished: () {}), state: state),
      );
      await beat(tester, 400);
      await beat(tester, 400);

      expect(find.text('Step 2 of 14'), findsOneWidget);
      expect(state.intake.consentGiven, isTrue);
    });

    testWidgets('back is offered even when the intake is the root route',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);

      // Signing in lands a returning patient here as the *root*:
      // `WelcomeScreen.continueFrom` uses `Nav.rootTo`, so there is nothing
      // underneath to pop. The button still has to be there.
      await tester.pumpWidget(
        harness(IntakeFlowScreen(onFinished: () {}), state: state),
      );
      await beat(tester);

      expect(find.text('Step 1 of 14'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Nobody is signed in here, so there is nothing to confirm: it goes
      // straight to the welcome screen.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await beat(tester, 600);
      expect(find.text('Step 1 of 14'), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('a signed-in patient is asked before being logged out',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);
      // Started rather than awaited: `signInAccount` awaits repository reads,
      // and inside testWidgets' fake async those futures only complete while
      // the tester pumps. The uid is bound synchronously either way.
      unawaited(state.signInAccount('uid-1'));

      await tester.pumpWidget(
        harness(IntakeFlowScreen(onFinished: () {}), state: state),
      );
      await beat(tester, 400);
      await beat(tester, 400);

      // Declining leaves everything exactly as it was — a stray tap on the
      // back arrow must not be able to end someone's session.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await beat(tester, 600);
      expect(find.text('Go back and log out?'), findsOneWidget);

      await tester.tap(find.text('Stay here'));
      await beat(tester, 600);
      expect(find.text('Step 1 of 14'), findsOneWidget);
      expect(state.accountId, 'uid-1');

      // Accepting signs out and returns to the welcome screen.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await beat(tester, 600);
      await tester.tap(find.text('Go back and log out'));
      // Signing out awaits the repositories before the welcome screen is
      // routed to, and that route then fades in over ~380ms.
      for (int i = 0; i < 4; i++) {
        await beat(tester, 400);
      }
      await drainSync(tester, state);

      expect(state.accountId, isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Step 1 of 14'), findsNothing);
    });
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
    state.saveOnboarding(const OnboardingRecord(
      helper: HelperRole.myself,
      education: EducationLevel.graduate,
    ));

    await tester.pumpWidget(
      harness(IntakeFlowScreen(onFinished: () {}), state: state),
    );
    // Two beats: saving the answers queues sync operations, and the loopback
    // transport's delay has to elapse before the test ends or the binding
    // fails on a pending timer.
    await beat(tester, 400);
    await beat(tester, 400);

    // Straight to the health step, skipping consent and the person screen.
    expect(find.text('Health and care so far'), findsOneWidget);
    expect(find.text('Step 3 of 14'), findsOneWidget);
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
    expect(find.text('Day 1 of 4'), findsOneWidget);
    expect(find.text('0 of 7 activities across the 4 days'), findsOneWidget);
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

  // A plain `test`, not `testWidgets`: this one drains the outbox on the real
  // clock, and inside testWidgets' fake async those futures never complete.
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
    // A plain test, so the outbox drains on the real clock with no binding to
    // complain about pending timers — no beat-pumping needed here.
    await state.flush();

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
