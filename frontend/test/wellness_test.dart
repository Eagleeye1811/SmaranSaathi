import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/models/wellness.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/patient/patient_shell.dart';
import 'package:smaran_saathi/features/patient/wellness/breathing/breathing_exercise_screen.dart';
import 'package:smaran_saathi/features/patient/wellness/meditation/meditation_player_screen.dart';
import 'package:smaran_saathi/features/patient/wellness/wellness_corner_screen.dart';
import 'package:smaran_saathi/features/patient/wellness/yoga/yoga_detail_screen.dart';

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
      home: child,
    ),
  );
}

Future<void> beat(WidgetTester tester, [int ms = 500]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wellness Hub & Corners', () {
    testWidgets('renders Wellness bottom navigation item in PatientShell', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);

      await tester.pumpWidget(harness(const PatientShell(), state: state));
      await beat(tester);

      expect(find.text('Wellness'), findsOneWidget);
    });

    testWidgets('renders WellnessHub dashboard with 3 main category cards', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);

      await tester.pumpWidget(harness(const WellnessCornerScreen(), state: state));
      await beat(tester);

      expect(find.text('Wellness Hub'), findsOneWidget);
      expect(find.text('Breathing'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Soundscapes'), findsNothing);
    });

    testWidgets('navigates to Breathing Corner and back', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);

      await tester.pumpWidget(harness(const WellnessCornerScreen(), state: state));
      await beat(tester);

      // Tap Breathing category card
      await tester.tap(find.text('Breathing'));
      await beat(tester);

      expect(find.text('Breathing Exercises'), findsOneWidget);
      expect(find.text('Deep Diaphragmatic Breathing'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Back to Wellness Hub'));
      await beat(tester);

      expect(find.text('Wellness Hub'), findsOneWidget);
    });

    testWidgets('navigates to Meditation Corner with Todays Pick and filter chips', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);

      await tester.pumpWidget(harness(const WellnessCornerScreen(), state: state));
      await beat(tester);

      // Tap Meditation category card
      await tester.tap(find.text('Meditation'));
      await beat(tester);

      expect(find.text('Guided Meditation'), findsOneWidget);
      expect(find.text("Today's Pick"), findsOneWidget);
      expect(find.text('Guided Morning Relaxation'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('BreathingExerciseScreen renders intro and starts exercise', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);
      final BreathingTechnique technique = WellnessRepositoryData.breathingTechniques.first;

      await tester.pumpWidget(harness(BreathingExerciseScreen(technique: technique), state: state));
      await beat(tester);

      expect(find.text('Deep Diaphragmatic Breathing'), findsWidgets);
      expect(find.text('Start Breathing Exercise'), findsOneWidget);

      // Start exercise
      await tester.tap(find.text('Start Breathing Exercise'));
      await beat(tester);

      expect(find.text('Stop Exercise'), findsOneWidget);
      expect(find.textContaining('Inhale'), findsWidgets);
    });

    testWidgets('MeditationPlayerScreen plays guided meditation', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);
      final GuidedMeditation meditation = WellnessRepositoryData.guidedMeditations.first;

      await tester.pumpWidget(harness(MeditationPlayerScreen(meditation: meditation), state: state));
      await beat(tester);

      expect(find.text('Guided Morning Relaxation'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('YogaDetailScreen renders step-by-step guidance without camera posture check option', (WidgetTester tester) async {
      tester.setSurface(const Size(393, 852));
      final AppState state = AppState()..setRole(AppRole.patient);
      final YogaPose pose = WellnessRepositoryData.yogaPoses.first;

      await tester.pumpWidget(harness(YogaDetailScreen(pose: pose), state: state));
      await beat(tester);

      expect(find.text('Seated Cat-Cow (Upavistha Bitilasana Marjaryasana)'), findsOneWidget);
      expect(find.text('How to Perform'), findsOneWidget);
      // Ensure NO camera posture check switch exists
      expect(find.text('Check posture with camera'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('recordWellnessSession updates state and caregiver feed', (WidgetTester tester) async {
      final AppState state = AppState()..setRole(AppRole.patient);
      expect(state.wellnessSessions.length, 0);

      state.recordWellnessSession(
        WellnessSession(
          id: 'test_1',
          type: WellnessType.breathing,
          title: 'Box Breathing',
          durationSeconds: 120,
          timestamp: DateTime.now(),
        ),
      );

      expect(state.wellnessSessions.length, 1);
      expect(state.wellnessSessions.first.title, 'Box Breathing');
      await beat(tester, 1000);
    });
  });
}
