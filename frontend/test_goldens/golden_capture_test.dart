import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/app/theme/app_theme.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/features/auth/role_selection_screen.dart';
import 'package:memory_mitra/features/caregiver/caregiver_shell.dart';
import 'package:memory_mitra/features/caregiver/onboarding/patient_onboarding_flow.dart';
import 'package:memory_mitra/features/doctor/doctor_shell.dart';
import 'package:memory_mitra/features/doctor/patients/patient_detail_screen.dart';
import 'package:memory_mitra/features/patient/games/familiar_place/familiar_place_game.dart';
import 'package:memory_mitra/features/patient/games/melody/melody_game.dart';
import 'package:memory_mitra/features/patient/games/memory_cards/memory_cards_game.dart';
import 'package:memory_mitra/features/patient/games/procedure/procedure_game.dart';
import 'package:memory_mitra/features/patient/games/story/story_game.dart';
import 'package:memory_mitra/features/patient/games/weaves/weaves_game.dart';
import 'package:memory_mitra/features/patient/patient_shell.dart';

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
      home: child,
    ),
  );
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

    await tester.tap(find.text('Games').last);
    await beat(tester);
    await shoot(tester, '04_game_hub');

    await tester.tap(find.text('Memories').last);
    await beat(tester);
    await shoot(tester, '05_memory_wallet');

    await tester.tap(find.text('Today').last);
    await beat(tester);
    await shoot(tester, '06_today');

    await tester.tap(find.text('Profile').last);
    await beat(tester);
    await shoot(tester, '07_patient_profile');
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
}
