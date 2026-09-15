import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/caregiver/profile/caregiver_profile_screen.dart';
import 'package:smaran_saathi/features/doctor/profile/doctor_profile_screen.dart';
import 'package:smaran_saathi/features/patient/profile/patient_profile_screen.dart';
import 'package:smaran_saathi/features/patient/settings/language_picker_button.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';
import 'package:smaran_saathi/l10n/locale_controller.dart';

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

    /// Finds the language control however this role renders it, picks the
    /// named language, and leaves the frame settled.
    Future<void> pick(WidgetTester tester, String name) async {
      // The page's own list, not the first scrollable in the tree — these
      // profiles carry horizontal strips (chips, day pickers) that match
      // `Scrollable` first and scroll the wrong way.
      final Finder scroll = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );

      // The compact control keeps its options behind a sheet, so it has to be
      // found and opened first. `scrollUntilVisible` rather than a hand-rolled
      // drag loop: on a long profile the button is not merely off-screen, it
      // has not been built yet.
      if (find.text(name).evaluate().isEmpty && scroll.evaluate().isNotEmpty) {
        try {
          await tester.scrollUntilVisible(
            find.byType(LanguagePickerButton),
            220,
            scrollable: scroll.first,
            maxScrolls: 40,
          );
        } catch (_) {
          // No compact control on this profile — it uses the inline card,
          // whose options are already on the page.
        }
      }
      for (int i = 0; i < 20 && find.text(name).evaluate().isEmpty; i++) {
        if (find.byType(LanguagePickerButton).evaluate().isNotEmpty) {
          // `scrollUntilVisible` stops the moment the button is barely in
          // frame, where a tap lands on the list's clip rather than on it.
          await tester.ensureVisible(find.byType(LanguagePickerButton).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.byType(LanguagePickerButton).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          break;
        }
        if (scroll.evaluate().isEmpty) break;
        await tester.drag(scroll.first, const Offset(0, -320));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.text(name), findsWidgets, reason: 'no language control on this profile');
      await tester.ensureVisible(find.text(name).first);
      await tester.pump();
      await tester.tap(find.text(name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('Patient role profile has the language selector and updates UI in place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      state.setRole(AppRole.patient);
      await tester.pumpWidget(harness(const PatientProfileScreen()));
      await tester.pump(const Duration(milliseconds: 700));

      await pick(tester, 'हिंदी');

      expect(locale.locale.languageCode, 'hi');
      expect(state.localeCode, 'hi');
      expect(find.text('हिंदी'), findsWidgets);
    });

    testWidgets('Caregiver role profile has the language selector and updates UI in place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      state.setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverProfileScreen()));
      await tester.pump(const Duration(milliseconds: 700));

      await pick(tester, 'অসমীয়া');

      // UI updates immediately in place without navigating away.
      expect(locale.locale.languageCode, 'as');
      expect(state.localeCode, 'as');
      expect(find.text('অসমীয়া'), findsWidgets);
    });

    testWidgets('Doctor role profile has the language selector and updates UI in place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      state.setRole(AppRole.doctor);
      await tester.pumpWidget(harness(const DoctorProfileScreen()));
      await tester.pump(const Duration(milliseconds: 700));

      await pick(tester, 'हिंदी');

      // UI updates in place and persists.
      expect(locale.locale.languageCode, 'hi');
      expect(state.localeCode, 'hi');
      expect(find.text('हिंदी'), findsWidgets);
    });
  });
}
