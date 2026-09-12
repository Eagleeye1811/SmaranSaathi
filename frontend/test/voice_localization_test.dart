import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/app/theme/app_theme.dart';
import 'package:memory_mitra/core/ai/on_device_ai_service.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/core/voice/speech_engines.dart';
import 'package:memory_mitra/core/voice/voice_assistant_controller.dart';
import 'package:memory_mitra/core/voice/voice_bootstrap.dart';
import 'package:memory_mitra/core/voice/voice_intake_controller.dart';
import 'package:memory_mitra/core/voice/voice_language.dart';
import 'package:memory_mitra/core/voice/voice_models.dart';
import 'package:memory_mitra/core/voice/voice_nav_intent.dart';
import 'package:memory_mitra/core/voice/voice_navigation_controller.dart';
import 'package:memory_mitra/core/widgets/voice_nav_host.dart';
import 'package:memory_mitra/features/caregiver/caregiver_shell.dart';
import 'package:memory_mitra/features/doctor/doctor_shell.dart';
import 'package:memory_mitra/features/patient/patient_shell.dart';
import 'package:memory_mitra/features/patient/voice/voice_assistant_sheet.dart';
import 'package:memory_mitra/l10n/app_localizations.dart';
import 'package:memory_mitra/l10n/content_labels.dart';
import 'package:memory_mitra/l10n/locale_controller.dart';

void main() {
  late AppState state;
  late LocaleController locale;

  setUp(() {
    state = AppState();
    locale = LocaleController();
  });

  tearDown(() {
    state.dispose();
    locale.dispose();
  });

  Widget harness(Widget child) {
    return AppScope(
      state: state,
      child: LocaleScope(
        controller: locale,
        child: AnimatedBuilder(
          animation: locale,
          builder: (BuildContext context, _) {
            return MaterialApp(
              locale: locale.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.warm(),
              home: Scaffold(body: child),
            );
          },
        ),
      ),
    );
  }

  group('Voice Assistant & Language Selection Integration', () {
    test('Flow 1: Patient selects Hindi -> Voice Assistant uses Hindi STT & TTS', () async {
      locale.setLocale(const Locale('hi'));
      state.localeCode = 'hi';

      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        locales: <String>['en_IN', 'hi_IN'],
      )..script = const <SpeechResult>[
          SpeechResult(text: 'मेरी दवाइयाँ', isFinal: true),
        ];
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(
        languages: <String>['en-IN', 'hi-IN'],
      );

      final VoiceAssistantController controller = buildVoiceController(
        state,
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        language: locale.voiceLanguage,
      );

      expect(controller.language, VoiceLanguage.hindi);
      await controller.initialize();

      expect(controller.resolvedInputLanguage?.localeId, 'hi_IN');
      expect(controller.resolvedOutputLanguage?.localeId, 'hi-IN');

      await controller.startListening();
      await Future<void>.delayed(Duration.zero);

      expect(controller.recognizedText, 'मेरी दवाइयाँ');
      expect(speaker.lastLocaleId, 'hi-IN', reason: 'TTS spoke in Hindi locale');
      expect(speaker.spoken, isNotEmpty);

      controller.dispose();
    });

    test('Flow 2: Patient changes to English -> Voice Assistant updates to English', () async {
      // Start in Hindi
      locale.setLocale(const Locale('hi'));
      state.localeCode = 'hi';

      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        locales: <String>['en_IN', 'hi_IN'],
      );
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(
        languages: <String>['en-IN', 'hi-IN'],
      );

      final VoiceAssistantController controller = buildVoiceController(
        state,
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        language: locale.voiceLanguage,
      );

      await controller.initialize();
      expect(controller.language, VoiceLanguage.hindi);
      expect(controller.resolvedInputLanguage?.localeId, 'hi_IN');

      // Switch to English
      locale.setLocale(const Locale('en'));
      state.localeCode = 'en';
      await controller.setLanguage(locale.voiceLanguage);

      expect(controller.language, VoiceLanguage.english);
      expect(controller.resolvedInputLanguage?.localeId, 'en_IN');
      expect(controller.resolvedOutputLanguage?.localeId, 'en-IN');

      controller.dispose();
    });

    test('Flow 3: Caregiver selects Hindi -> Voice navigation uses Hindi', () async {
      locale.setLocale(const Locale('hi'));
      state.localeCode = 'hi';

      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        locales: <String>['en_IN', 'hi_IN'],
      )..script = const <SpeechResult>[
          SpeechResult(text: 'रोगी', isFinal: true),
        ];
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(
        languages: <String>['en-IN', 'hi-IN'],
      );

      final List<VoiceDestination> navigated = <VoiceDestination>[];
      final VoiceNavigationController nav = buildVoiceNavController(
        onNavigate: (VoiceDestination d) {
          navigated.add(d);
          return true;
        },
        destinations: const <VoiceDestination>{VoiceDestination.patient},
        recognizer: mic,
        synthesizer: speaker,
        language: locale.voiceLanguage,
      );

      expect(nav.language, VoiceLanguage.hindi);
      await nav.initialize();
      expect(nav.spokenLanguage, VoiceLanguage.hindi);

      await nav.start();
      await pumpEventQueue();

      expect(speaker.spoken.first, 'मैं आपके लिए क्या करूँ?',
          reason: 'Spoken prompt is in Hindi');
      expect(navigated, <VoiceDestination>[VoiceDestination.patient]);

      nav.dispose();
    });

    test('Flow 4a: Doctor selects Assamese with full device support -> uses Assamese', () async {
      locale.setLocale(const Locale('as'));
      state.localeCode = 'as';

      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        locales: <String>['en_IN', 'hi_IN', 'as_IN'],
      )..script = const <SpeechResult>[
          SpeechResult(text: 'ৰোগীসকল', isFinal: true),
        ];
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(
        languages: <String>['en-IN', 'hi-IN', 'as-IN'],
      );

      final List<VoiceDestination> navigated = <VoiceDestination>[];
      final VoiceNavigationController nav = buildVoiceNavController(
        onNavigate: (VoiceDestination d) {
          navigated.add(d);
          return true;
        },
        destinations: const <VoiceDestination>{VoiceDestination.patients},
        recognizer: mic,
        synthesizer: speaker,
        language: locale.voiceLanguage,
      );

      expect(nav.language, VoiceLanguage.assamese);
      await nav.initialize();
      expect(nav.spokenLanguage, VoiceLanguage.assamese);

      await nav.start();
      await pumpEventQueue();

      expect(speaker.spoken.first, 'মই আপোনাৰ বাবে কি কৰিম?',
          reason: 'Spoken prompt is in Assamese');
      expect(navigated, <VoiceDestination>[VoiceDestination.patients]);

      nav.dispose();
    });

    test('Flow 4b: Assamese TTS unavailable on device -> does NOT crash and does NOT speak Assamese in English voice', () async {
      locale.setLocale(const Locale('as'));
      state.localeCode = 'as';

      // Device lacks Assamese voice
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(locales: <String>['en_IN']);
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(languages: <String>['en-IN']);

      final VoiceAssistantController controller = buildVoiceController(
        state,
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        language: locale.voiceLanguage,
      );

      await controller.initialize();
      expect(controller.language, VoiceLanguage.assamese);

      // Asking directly produces a reply
      await controller.askDirectly('আজি মোৰ কি আছে?');
      await pumpEventQueue();

      // Verify no crash
      expect(controller.reply, isNotNull);
      // Verify Assamese was NOT spoken using the English voice
      expect(speaker.spoken, isEmpty,
          reason: 'Must NOT speak Assamese using an English voice');

      // Verify localized ttsUnavailable error is raised gracefully
      expect(controller.error?.kind, VoiceErrorKind.ttsUnavailable);
      final AppLocalizations l = AppLocalizations(const Locale('as'));
      expect(controller.error!.localizedMessage(l),
          "মই এই যন্ত্ৰত ক'ব নোৱাৰোঁ, কিন্তু আপুনি মোৰ উত্তৰ পঢ়িব পাৰে।");

      controller.dispose();
    });

    test('Flow 4c: Assamese with Indic Hindi voice -> speaks Assamese words using phonetic Indic synthesis', () async {
      locale.setLocale(const Locale('as'));
      state.localeCode = 'as';

      // Device has Hindi Indic voice installed (common in Chrome & Android)
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(locales: <String>['en_IN', 'hi_IN']);
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(languages: <String>['en-IN', 'hi-IN']);

      final VoiceAssistantController controller = buildVoiceController(
        state,
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        language: locale.voiceLanguage,
      );

      await controller.initialize();
      expect(controller.language, VoiceLanguage.assamese);
      expect(controller.canSpeak, isTrue, reason: 'Can speak via Indic phonetic voice');

      await controller.askDirectly('নমস্কাৰ');
      await pumpEventQueue();

      expect(controller.reply, isNotNull);
      // Spoken output must be articulated via Indic voice
      expect(speaker.spoken, isNotEmpty, reason: 'Assamese is spoken aloud');
      expect(speaker.lastLocaleId, 'hi-IN', reason: 'Uses Indic voice');
      // The screen reply remains in Assamese
      expect(controller.reply?.text.isNotEmpty, isTrue);

      controller.dispose();
    });

    test('Flow 5: Restart the app -> persists and restores locale and voice language', () {
      // Simulate user selecting Assamese in session
      state.localeCode = 'as';

      // Simulate app restarting: new LocaleController seeded from state.localeCode
      final LocaleController restoredLocale = LocaleController(
        initial: state.localeCode == null ? null : Locale(state.localeCode!),
      );

      expect(restoredLocale.locale.languageCode, 'as');
      expect(restoredLocale.voiceLanguage, VoiceLanguage.assamese);

      // Controller built after restart automatically uses restored locale
      final VoiceAssistantController c = buildVoiceController(
        state,
        synthesizer: FakeSpeechSynthesizer(),
        recognizer: FakeSpeechRecognizer(),
      );
      expect(c.language, VoiceLanguage.assamese);

      c.dispose();
      restoredLocale.dispose();
    });

    test('Flow 6: Change language while Voice Assistant is active -> safely cancels and switches', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        locales: <String>['en_IN', 'hi_IN'],
      );
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(
        languages: <String>['en-IN', 'hi-IN'],
      );

      final VoiceAssistantController controller = buildVoiceController(
        state,
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        language: VoiceLanguage.hindi,
      );

      await controller.startListening();
      expect(controller.isListening, isTrue);

      // Mid-session switch to English
      await controller.setLanguage(VoiceLanguage.english);

      expect(mic.cancelCount, greaterThan(0), reason: 'Active mic was safely canceled');
      expect(controller.isListening, isFalse);
      expect(controller.language, VoiceLanguage.english);
      expect(controller.resolvedInputLanguage?.localeId, 'en_IN');

      controller.dispose();
    });

    testWidgets('Flow 6 UI: Changing language while VoiceAssistantSheet is open updates voice and UI',
        (WidgetTester tester) async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        locales: <String>['en_IN', 'hi_IN', 'as_IN'],
      );
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer(
        languages: <String>['en-IN', 'hi-IN', 'as-IN'],
      );

      final VoiceAssistantController controller = buildVoiceController(
        state,
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        language: VoiceLanguage.english,
      );

      await tester.pumpWidget(harness(VoiceAssistantSheet(controller: controller)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ask Mitra'), findsOneWidget);

      // Change locale to Hindi while sheet is mounted
      locale.setLocale(const Locale('hi'));
      state.localeCode = 'hi';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.language, VoiceLanguage.hindi);
      expect(find.text('मित्रा से पूछें'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('VoiceNavHost in Patient, Caregiver, and Doctor shells updates on language change',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Patient Shell
      await tester.pumpWidget(harness(const PatientShell()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VoiceNavHost), findsOneWidget);

      // Switch to Hindi
      locale.setLocale(const Locale('hi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Caregiver Shell
      await tester.pumpWidget(harness(const CaregiverShell()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VoiceNavHost), findsOneWidget);

      // Switch to Assamese
      locale.setLocale(const Locale('as'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Doctor Shell
      await tester.pumpWidget(harness(const DoctorShell()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VoiceNavHost), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Flow 7: Multilingual intake speech utterances exist for en, hi, as', () {
      for (final VoiceLanguage lang in VoiceLanguage.values) {
        expect(VoiceIntakeSpeech.sayNumber(lang), isNotEmpty);
        expect(VoiceIntakeSpeech.sayAfterBeep(lang), isNotEmpty);
        expect(VoiceIntakeSpeech.sayNext(lang), isNotEmpty);
        expect(VoiceIntakeSpeech.sayAnswerOrNumber(lang), isNotEmpty);
        expect(VoiceIntakeSpeech.hearingTrouble(lang), isNotEmpty);
        expect(VoiceIntakeSpeech.didNotCatch(lang), isNotEmpty);
        expect(VoiceIntakeSpeech.voiceOff(lang), isNotEmpty);

        expect(VoiceNavSpeech.prompt(lang), isNotEmpty);
        expect(VoiceNavSpeech.opening(lang, 'test'), isNotEmpty);
        expect(VoiceNavSpeech.unavailable(lang, 'test'), isNotEmpty);
        expect(VoiceNavSpeech.notUnderstood(lang), isNotEmpty);
        expect(VoiceNavSpeech.goingBack(lang), isNotEmpty);
        expect(VoiceNavSpeech.help(lang, <String>['test']), isNotEmpty);
      }
    });
  });
}
