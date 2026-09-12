import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_mitra/app/theme/app_theme.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/features/caregiver/caregiver_shell.dart';
import 'package:memory_mitra/features/doctor/doctor_shell.dart';
import 'package:memory_mitra/features/patient/patient_entry.dart';
import 'package:memory_mitra/features/patient/settings/language_picker_button.dart';
import 'package:memory_mitra/l10n/app_localizations.dart';
import 'package:memory_mitra/l10n/locale_controller.dart';

void main() {
  group('Role next-page language selector verification', () {
    late AppState state;
    late LocaleController locale;

    setUp(() {
      state = AppState();
      locale = LocaleController();
    });

    tearDown(() {
      locale.dispose();
      state.dispose();
    });

    Widget harness(Widget child) => AppScope(
          state: state,
          child: LocaleScope(
            controller: locale,
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[state, locale]),
              builder: (BuildContext context, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.warm(),
                locale: locale.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: child,
              ),
            ),
          ),
        );

    testWidgets('Patient role next page has language selector and updates UI in place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      state.setRole(AppRole.patient);
      await tester.pumpWidget(harness(const PatientEntry()));
      await tester.pump(const Duration(milliseconds: 700));

      // LanguagePickerButton is present on the existing next page.
      expect(find.byType(LanguagePickerButton), findsWidgets);
      expect(find.text('English'), findsWidgets);

      // Tap the language selector button.
      await tester.tap(find.byType(LanguagePickerButton).first);
      await tester.pumpAndSettle();

      // Modal bottom sheet opens with the three supported languages and shows active selection.
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('অসমীয়া'), findsOneWidget);

      // Select Hindi.
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      // UI updates immediately in place and selection persists.
      expect(locale.locale.languageCode, 'hi');
      expect(state.localeCode, 'hi');
      expect(find.text('हिंदी'), findsWidgets);
    });

    testWidgets('Caregiver role next page has language selector and updates UI in place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      state.setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell()));
      await tester.pump(const Duration(milliseconds: 700));

      // LanguagePickerButton is present on Caregiver next page.
      expect(find.byType(LanguagePickerButton), findsOneWidget);
      expect(find.text('English'), findsWidgets);

      // Tap the language selector button.
      await tester.tap(find.byType(LanguagePickerButton));
      await tester.pumpAndSettle();

      // Modal bottom sheet shows the 3 languages.
      expect(find.text('English'), findsWidgets);
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('অসমীয়া'), findsOneWidget);

      // Select Assamese.
      await tester.tap(find.text('অসমীয়া'));
      await tester.pumpAndSettle();

      // UI updates immediately in place without navigating away.
      expect(locale.locale.languageCode, 'as');
      expect(state.localeCode, 'as');
      expect(find.text('অসমীয়া'), findsWidgets);
    });

    testWidgets('Doctor role next page has language selector and updates UI in place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      state.setRole(AppRole.doctor);
      await tester.pumpWidget(harness(const DoctorShell()));
      await tester.pump(const Duration(milliseconds: 700));

      // LanguagePickerButton is present on Doctor next page.
      expect(find.byType(LanguagePickerButton), findsOneWidget);
      expect(find.text('English'), findsWidgets);

      // Tap the language selector button.
      await tester.tap(find.byType(LanguagePickerButton));
      await tester.pumpAndSettle();

      // Modal sheet opens with Hindi and Assamese.
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('অসমীয়া'), findsOneWidget);

      // Select Hindi.
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      // UI updates in place and persists.
      expect(locale.locale.languageCode, 'hi');
      expect(state.localeCode, 'hi');
      expect(find.text('हिंदी'), findsWidgets);
    });
  });
}
