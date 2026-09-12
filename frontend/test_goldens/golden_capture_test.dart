import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/auth/role_selection_screen.dart';
import 'package:smaran_saathi/features/caregiver/caregiver_shell.dart';
import 'package:smaran_saathi/features/caregiver/onboarding/patient_onboarding_flow.dart';
import 'package:smaran_saathi/features/doctor/doctor_shell.dart';
import 'package:smaran_saathi/features/doctor/patients/patient_detail_screen.dart';
import 'package:smaran_saathi/features/patient/games/familiar_place/familiar_place_game.dart';
import 'package:smaran_saathi/features/patient/games/melody/melody_game.dart';
import 'package:smaran_saathi/features/patient/games/memory_cards/memory_cards_game.dart';
import 'package:smaran_saathi/features/patient/games/procedure/procedure_game.dart';
import 'package:smaran_saathi/features/patient/games/story/story_game.dart';
import 'package:smaran_saathi/features/patient/games/weaves/weaves_game.dart';
import 'package:smaran_saathi/features/intake/baseline_screens.dart';
import 'package:smaran_saathi/features/intake/steps_consent_profile.dart';
import 'package:smaran_saathi/features/intake/steps_medical_caregiver.dart';
import 'package:smaran_saathi/features/intake/steps_reason_safety.dart';
import 'package:smaran_saathi/features/intake/steps_symptoms_function.dart';
import 'package:smaran_saathi/features/intake/welcome_screens.dart';
import 'package:smaran_saathi/features/patient/assistant/assistant_screen.dart';
import 'package:smaran_saathi/features/patient/health/care_plan_screen.dart';
import 'package:smaran_saathi/features/patient/health/cognitive_profile_screen.dart';
import 'package:smaran_saathi/features/patient/health/report_screen.dart';
import 'package:smaran_saathi/features/patient/memories/memory_wallet_screen.dart';
import 'package:smaran_saathi/features/patient/patient_shell.dart';
import 'package:smaran_saathi/features/patient/today/today_screen.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

/// Renders every important screen to `test_goldens/goldens/` so the visual
/// design can be reviewed without a device:
///
///     flutter test test_goldens --update-goldens
///
/// It lives outside `test/` so `flutter test` never runs it — these are
/// design-review captures, not pass/fail assertions.

const Size kPhone = Size(393, 852);
const Size kTabletLandscape = Size(1112, 834);

Future<void> loadFont() async {
  final Uint8List bytes = File('assets/fonts/Nunito.ttf').readAsBytesSync();
  final FontLoader loader = FontLoader('Nunito')
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Widget harness(Widget child, {AppState? state, bool clinic = false}) {
  return AppScope(
    state: state ?? AppState(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: clinic ? AppTheme.clinic() : AppTheme.warm(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// A state carrying the twelve-week demonstration history, so the monitoring
/// screens capture with real trends rather than an empty profile.
Future<AppState> monitoredState() async {
  final AppState state = AppState()..setRole(AppRole.patient);
  await state.loadDemoJourney(now: DateTime(2026, 8, 28));
  return state;
}

Future<void> beat(WidgetTester tester, [int ms = 1400]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 600));
}

extension _Sizing on WidgetTester {
  void setSurface(Size size) {
    view.physicalSize = size * 2;
    view.devicePixelRatio = 2;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }
}

Future<void> shoot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(loadFont);

  testWidgets('01 role selection', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const RoleSelectionScreen()));
    await beat(tester);
    await shoot(tester, '01_role_selection');
  });

  testWidgets('02 patient home', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.patient);
    await tester.pumpWidget(harness(const PatientShell(), state: s));
    await beat(tester);
    await shoot(tester, '02_patient_home');

    await tester.tap(find.text('Good').first);
    await beat(tester);
    await shoot(tester, '03_patient_home_mood');
  });

  testWidgets('04 patient tabs', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.patient);
    await tester.pumpWidget(harness(const PatientShell(), state: s));
    await beat(tester);

    await tester.tap(find.text('Activities').last);
    await beat(tester);
    await shoot(tester, '04_game_hub');

    await tester.tap(find.text('Profile').last);
    await beat(tester);
    await shoot(tester, '07_patient_profile');
  });

  // The memory wallet and the daily screen moved off the navigation bar onto
  // the dashboard, so they are captured directly.
  testWidgets('05 warm surfaces', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.patient);

    await tester.pumpWidget(harness(const MemoryWalletScreen(), state: s));
    await beat(tester);
    await shoot(tester, '05_memory_wallet');

    await tester.pumpWidget(harness(const TodayScreen(), state: s));
    await beat(tester);
    await shoot(tester, '06_today');
  });

  testWidgets('08 procedure game', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const ProcedureGame()));
    await beat(tester);
    await shoot(tester, '08_procedure_intro');

    await tester.tap(find.text('Show me the steps'));
    await beat(tester);
    await shoot(tester, '09_procedure_watch');

    for (int i = 0; i < 6; i++) {
      final Finder next = find.text('Next step');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await beat(tester, 400);
    }
    await tester.tap(find.text('I am ready'));
    await beat(tester);
    await shoot(tester, '10_procedure_rebuild');
  });

  testWidgets('11 story game', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const StoryGame()));
    await beat(tester);
    await shoot(tester, '11_story');

    await tester.tap(find.text('She shared the vegetables with her neighbour.'));
    await beat(tester, 1600);
    await shoot(tester, '12_story_evaluation');
  });

  testWidgets('13 familiar place', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const FamiliarPlaceGame()));
    await beat(tester);
    await shoot(tester, '13_place_memorise');

    await tester.tap(find.text('I will remember them'));
    await beat(tester);
    await shoot(tester, '14_place_explore');
  });

  testWidgets('15 familiar place tablet landscape', (WidgetTester tester) async {
    tester.setSurface(kTabletLandscape);
    await tester.pumpWidget(harness(const FamiliarPlaceGame()));
    await beat(tester);
    await tester.tap(find.text('I will remember them'));
    await beat(tester);
    await shoot(tester, '15_place_tablet');
  });

  testWidgets('16 melody', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const MelodyGame()));
    await beat(tester);
    await shoot(tester, '16_melody');
  });

  testWidgets('17 weaves', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const WeavesGame()));
    await beat(tester, 2000);
    await shoot(tester, '17_weaves_preview');
    await beat(tester, 6000);
    await shoot(tester, '18_weaves_choose');
  });

  testWidgets('19 memory cards', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(harness(const MemoryCardsGame()));
    await beat(tester);
    await shoot(tester, '19_memory_cards');
  });

  testWidgets('20 caregiver', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.caregiver);
    await tester.pumpWidget(harness(const CaregiverShell(), state: s));
    await beat(tester);
    await shoot(tester, '20_caregiver_dashboard');

    await tester.tap(find.text('Patient').last);
    await beat(tester);
    await shoot(tester, '21_memory_profile');

    await tester.tap(find.text('Activity').last);
    await beat(tester);
    await shoot(tester, '22_caregiver_activity');

    await tester.tap(find.text('Reminders').last);
    await beat(tester);
    await shoot(tester, '23_caregiver_reminders');
  });

  testWidgets('24 onboarding', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.caregiver);
    await tester.pumpWidget(harness(const PatientOnboardingFlow(), state: s));
    await beat(tester);
    await shoot(tester, '24_onboarding_step1');

    await tester.tap(find.text('Continue'));
    await beat(tester);
    await shoot(tester, '25_onboarding_family');
  });

  testWidgets('26 doctor', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.doctor);
    await tester.pumpWidget(harness(const DoctorShell(), state: s, clinic: true));
    await beat(tester);
    await shoot(tester, '26_doctor_overview');

    await tester.tap(find.text('Patients').last);
    await beat(tester);
    await shoot(tester, '27_doctor_patients');

    await tester.tap(find.text('Analytics').last);
    await beat(tester);
    await shoot(tester, '28_doctor_analytics');

    await tester.tap(find.text('Alerts').last);
    await beat(tester);
    await shoot(tester, '29_doctor_alerts');
  });

  testWidgets('30 patient record', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    await tester.pumpWidget(
      harness(const PatientDetailScreen(patientId: 'p_aama'), clinic: true),
    );
    await beat(tester);
    await shoot(tester, '30_patient_record');
  });

  // ── The monitoring journey ─────────────────────────────────────────────

  testWidgets('31 welcome and intake', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.patient);

    await tester.pumpWidget(harness(const WelcomeScreen(), state: s));
    await beat(tester);
    await shoot(tester, '31_welcome');

    await tester.pumpWidget(harness(ConsentStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '32_consent');

    await tester.pumpWidget(harness(ProfileStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '33_profile');

    await tester.pumpWidget(harness(ReasonStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '34_reason');

    await tester.pumpWidget(harness(SafetyStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '35_safety');
  });

  testWidgets('36 assessment steps', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = AppState()..setRole(AppRole.patient);

    await tester.pumpWidget(harness(SymptomStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '36_symptoms');

    await tester.pumpWidget(harness(FunctionStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '37_function');

    await tester.pumpWidget(harness(MedicalStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '38_medical');

    await tester.pumpWidget(harness(CaregiverStep(onDone: () {}), state: s));
    await beat(tester);
    await shoot(tester, '39_caregiver');

    await tester.pumpWidget(harness(BaselineIntroScreen(onBegin: () {}), state: s));
    await beat(tester);
    await shoot(tester, '40_baseline_intro');
  });

  testWidgets('41 monitoring surfaces', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = await monitoredState();

    await tester.pumpWidget(harness(const PatientShell(), state: s));
    await beat(tester);
    await shoot(tester, '41_health_dashboard');

    await tester.pumpWidget(harness(const CognitiveProfileScreen(), state: s));
    await beat(tester);
    await shoot(tester, '42_cognitive_profile');

    await tester.pumpWidget(harness(const ReportScreen(), state: s));
    await beat(tester);
    await shoot(tester, '44_doctor_report');

    await tester.pumpWidget(harness(const CarePlanScreen(), state: s));
    await beat(tester);
    await shoot(tester, '45_care_plan');
  });

  testWidgets('46 companion', (WidgetTester tester) async {
    tester.setSurface(kPhone);
    final AppState s = await monitoredState();

    await tester.pumpWidget(harness(const AssistantScreen(), state: s));
    await beat(tester);
    await shoot(tester, '46_companion');

    await tester.tap(find.text('Explain my results'));
    await beat(tester);
    await shoot(tester, '47_companion_answer');
  });
}
