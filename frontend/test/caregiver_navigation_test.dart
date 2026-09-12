import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/caregiver/patient_view_screen.dart';
import 'package:smaran_saathi/features/patient/profile/patient_profile_screen.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

Widget harness(Widget child, {required AppState state}) {
  return AppScope(
    state: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.warm(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<void> beat(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  group('a caregiver previewing the patient app', () {
    test('the role is borrowed, and handed straight back', () {
      final AppState state = AppState()..setRole(AppRole.caregiver);
      addTearDown(state.dispose);

      state.beginPatientPreview();
      // The role really does change — the patient's screens have to render at
      // the patient's text size to be worth previewing at all.
      expect(state.role, AppRole.patient);
      expect(state.viewingAsPatient, isTrue);

      state.endPatientPreview();
      expect(state.role, AppRole.caregiver,
          reason: 'leaving the preview must never strand them as the patient');
      expect(state.viewingAsPatient, isFalse);
    });

    test('ending a preview that never began changes nothing', () {
      final AppState state = AppState()..setRole(AppRole.caregiver);
      addTearDown(state.dispose);
      state.endPatientPreview();
      expect(state.role, AppRole.caregiver);
    });

    testWidgets('backing out restores the caregiver role', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppState state = AppState()..setRole(AppRole.caregiver);
      addTearDown(state.dispose);

      await tester.pumpWidget(harness(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PatientViewScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        state: state,
      ));
      await beat(tester);

      await tester.tap(find.text('open'));
      await beat(tester);
      expect(state.viewingAsPatient, isTrue);
      expect(state.role, AppRole.patient);

      // The way back out, as a person would use it.
      await tester.pageBack();
      await beat(tester);

      expect(state.viewingAsPatient, isFalse);
      expect(state.role, AppRole.caregiver,
          reason: 'this is the bug: back used to leave them as the patient');
    });
  });

  group('the patient profile during a preview', () {
    testWidgets('cannot sign the caregiver out or change the role',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppState state = AppState()..setRole(AppRole.caregiver);
      addTearDown(state.dispose);
      state.beginPatientPreview();

      await tester.pumpWidget(
        harness(const Material(child: PatientProfileScreen()), state: state),
      );
      await beat(tester);

      final Finder scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
          find.text('Back to caregiver view'), 300, scrollable: scrollable);
      await beat(tester);

      // The role switch is replaced by the only honest thing it can do.
      expect(find.text('Back to caregiver view'), findsOneWidget);
      expect(find.text('Switch role'), findsNothing);
      // And the caregiver cannot sign themselves out from inside the
      // patient's screen.
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets('a real patient still gets both', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);

      await tester.pumpWidget(
        harness(const Material(child: PatientProfileScreen()), state: state),
      );
      await beat(tester);

      await tester.scrollUntilVisible(find.text('Switch role'), 300,
          scrollable: find.byType(Scrollable).first);
      await beat(tester);

      expect(find.text('Switch role'), findsOneWidget);
      expect(find.text('Back to caregiver view'), findsNothing);
    });
  });
}
