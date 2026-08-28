import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/app/theme/app_theme.dart';
import 'package:memory_mitra/core/ai/ai_context_builder.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/core/voice/voice_language.dart';
import 'package:memory_mitra/features/patient/patient_shell.dart';
import 'package:memory_mitra/features/patient/settings/language_selector.dart';
import 'package:memory_mitra/l10n/app_localizations.dart';
import 'package:memory_mitra/l10n/locale_controller.dart';

const List<String> kLocales = <String>['en', 'hi', 'as'];

Map<String, dynamic> loadArb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> keysOf(Map<String, dynamic> arb) =>
    arb.keys.where((String k) => !k.startsWith('@')).toSet();

void main() {
  // ─────────────────────────────────────────────────────────────────────
  group('ARB files', () {
    test('every locale defines exactly the English key set', () {
      final Set<String> english = keysOf(loadArb('en'));
      expect(english, isNotEmpty);

      for (final String locale in kLocales.where((String l) => l != 'en')) {
        final Set<String> keys = keysOf(loadArb(locale));
        expect(keys.difference(english), isEmpty, reason: '$locale has unknown keys');
        expect(english.difference(keys), isEmpty,
            reason: '$locale is missing keys — they would render as English');
      }
    });

    test('placeholders match across locales', () {
      final RegExp placeholder = RegExp(r'\{(\w+)\}');
      final Map<String, dynamic> english = loadArb('en');

      for (final String locale in kLocales.where((String l) => l != 'en')) {
        final Map<String, dynamic> arb = loadArb(locale);
        for (final String key in keysOf(english)) {
          final Set<String> want = placeholder
              .allMatches(english[key] as String)
              .map((RegExpMatch m) => m.group(1)!)
              .toSet();
          final Set<String> got = placeholder
              .allMatches(arb[key] as String)
              .map((RegExpMatch m) => m.group(1)!)
              .toSet();
          expect(got, want, reason: '$locale.$key placeholder mismatch');
        }
      }
    });

    test('no translation was left as the English source', () {
      // Product names are legitimately identical; everything else being equal
      // across all three languages means it was never translated.
      const Set<String> allowed = <String>{'appName'};
      final Map<String, dynamic> en = loadArb('en');
      final Map<String, dynamic> hi = loadArb('hi');
      final Map<String, dynamic> as = loadArb('as');

      final List<String> untranslated = <String>[
        for (final String key in keysOf(en))
          if (!allowed.contains(key) && en[key] == hi[key] && en[key] == as[key]) key,
      ];
      expect(untranslated, isEmpty);
    });

    test('the generated Dart is in step with the ARB files', () {
      // Guards against editing an ARB and forgetting `tool/gen_l10n.py`.
      for (final String locale in kLocales) {
        final Map<String, String>? generated = AppLocalizations.allStrings[locale];
        expect(generated, isNotNull, reason: '$locale missing from generated file');
        expect(generated!.keys.toSet(), keysOf(loadArb(locale)),
            reason: 'regenerate: python3 tool/gen_l10n.py');
        for (final MapEntry<String, dynamic> e in loadArb(locale).entries) {
          if (e.key.startsWith('@')) continue;
          expect(generated[e.key], e.value, reason: '$locale.${e.key} is stale');
        }
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('AppLocalizations', () {
    test('resolves strings for each supported locale', () {
      expect(const AppLocalizations(Locale('en')).todayTitle, 'Today');
      expect(const AppLocalizations(Locale('hi')).todayTitle, 'आज');
      expect(const AppLocalizations(Locale('as')).todayTitle, 'আজি');
    });

    test('substitutes placeholders in every language', () {
      for (final String locale in kLocales) {
        final AppLocalizations l = AppLocalizations(Locale(locale));
        final String text = l.todayThankYou('Aama');
        expect(text, contains('Aama'));
        expect(text, isNot(contains('{name}')), reason: '$locale left the placeholder');

        final String medicine = l.todayMedicineTaken(2, 3);
        expect(medicine, contains('2'));
        expect(medicine, contains('3'));
        expect(medicine, isNot(contains('{')));
      }
    });

    test('an unsupported locale falls back to English rather than blank', () {
      // A blank button is far worse for this audience than an English one.
      const AppLocalizations l = AppLocalizations(Locale('fr'));
      expect(l.todayTitle, 'Today');
      expect(l.voiceAskMitra, isNotEmpty);
    });

    test('supports exactly the three declared languages', () {
      expect(
        AppLocalizations.supportedLocales.map((Locale l) => l.languageCode),
        <String>['en', 'hi', 'as'],
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('LocaleController', () {
    test('notifies on a real change and ignores a no-op', () {
      final LocaleController c = LocaleController();
      int notifications = 0;
      c.addListener(() => notifications++);

      c.setLocale(const Locale('hi'));
      expect(c.locale.languageCode, 'hi');
      expect(notifications, 1);

      c.setLocale(const Locale('hi'));
      expect(notifications, 1, reason: 'no rebuild for the same language');
      c.dispose();
    });

    test('maps to the voice layer both ways', () {
      final LocaleController c = LocaleController(initial: const Locale('as'));
      expect(c.voiceLanguage, VoiceLanguage.assamese);

      c.setVoiceLanguage(VoiceLanguage.hindi);
      expect(c.locale.languageCode, 'hi');
      expect(c.voiceLanguage, VoiceLanguage.hindi);
      c.dispose();
    });

    test('starts from the patient profile language', () {
      expect(LocaleController.fromPatientLanguage('Assamese').languageCode, 'as');
      expect(LocaleController.fromPatientLanguage('Hindi').languageCode, 'hi');
      expect(LocaleController.fromPatientLanguage('Bodo').languageCode, 'en');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('live language switching', () {
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

    testWidgets('the selector changes the UI in place, with no restart',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(
        const Scaffold(body: SingleChildScrollView(child: LanguageSelector())),
      ));
      await tester.pump();

      // Starts in English.
      expect(find.text('Language'), findsOneWidget);
      // Each language is offered in its own script.
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('অসমীয়া'), findsOneWidget);

      // Switch to Hindi — the same widget tree, relabelled.
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      expect(locale.locale.languageCode, 'hi');
      expect(find.text('भाषा'), findsOneWidget);
      expect(find.text('Language'), findsNothing);

      // And on to Assamese.
      await tester.tap(find.text('অসমীয়া'));
      await tester.pumpAndSettle();
      expect(locale.locale.languageCode, 'as');
      expect(find.text('ভাষা'), findsOneWidget);
    });

    testWidgets('the patient shell renders in every language without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(const PatientShell()));
      await tester.pump(const Duration(milliseconds: 700));

      for (final String code in kLocales) {
        locale.setLocale(Locale(code));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        // flutter_test turns any layout overflow into an exception, so a
        // longer translation breaking a row fails here.
        expect(tester.takeException(), isNull, reason: 'layout broke in $code');
      }
    });

    testWidgets('the home greeting is translated', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(const PatientShell()));
      await tester.pump(const Duration(milliseconds: 700));

      locale.setLocale(const Locale('hi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('आज आप कैसा महसूस कर रही हैं?'), findsOneWidget,
          reason: 'the mood question follows the language');
      expect(find.text('How are you feeling today?'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('AI follows the selected language', () {
    test('the prompt carries the interface language, not the profile one', () {
      final AppState state = AppState();
      // The profile says Assamese; the patient has switched the app to Hindi.
      expect(state.patient.language, 'Assamese');

      final Map<String, dynamic> json =
          state.aiContext(now: DateTime(2026, 3, 14), replyLanguage: 'hi').toPromptJson();
      expect(json['replyLanguage'], 'hi');
      state.dispose();
    });

    test('falls back to the profile language when none is selected', () {
      final AppState state = AppState();
      final Map<String, dynamic> json =
          state.aiContext(now: DateTime(2026, 3, 14)).toPromptJson();
      expect(json['replyLanguage'], state.patient.language);
      state.dispose();
    });
  });
}
