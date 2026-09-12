import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/ai/ai_context.dart';
import 'package:smaran_saathi/core/ai/ai_context_builder.dart';
import 'package:smaran_saathi/core/ai/ai_models.dart';
import 'package:smaran_saathi/core/ai/ai_service.dart';
import 'package:smaran_saathi/core/ai/on_device_ai_service.dart';
import 'package:smaran_saathi/core/models/daily.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/voice/speech_engines.dart';
import 'package:smaran_saathi/core/voice/voice_assistant_controller.dart';
import 'package:smaran_saathi/core/voice/voice_language.dart';
import 'package:smaran_saathi/core/voice/voice_models.dart';
import 'package:smaran_saathi/features/patient/voice/ask_saathi_button.dart';
import 'package:smaran_saathi/features/patient/voice/voice_assistant_sheet.dart';

/// An assistant that fails, for exercising the AI-error branch.
class _FailingAssistant implements AiService {
  @override
  bool get isAvailable => true;
  @override
  void dispose() {}
  @override
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext c) async =>
      AiError<CognitiveInsight>.of(AiErrorKind.server);
  @override
  Future<AiResult<AssistantReply>> ask(String q, PatientAiContext c) async =>
      AiError<AssistantReply>.of(AiErrorKind.server);
  @override
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext c) async =>
      AiError<List<DailyQuestion>>.of(AiErrorKind.server);
}

/// An assistant we can hold mid-flight, to observe the `thinking` phase.
class _GatedAssistant implements AiService {
  final Completer<void> gate = Completer<void>();
  @override
  bool get isAvailable => true;
  @override
  void dispose() {}
  @override
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext c) async =>
      AiError<CognitiveInsight>.of(AiErrorKind.unknown);
  @override
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext c) async =>
      AiError<List<DailyQuestion>>.of(AiErrorKind.unknown);
  @override
  Future<AiResult<AssistantReply>> ask(String q, PatientAiContext c) async {
    await gate.future;
    return AiSuccess<AssistantReply>(AssistantReply(
      text: 'Answer to "$q".',
      intent: AssistantIntent.schedule,
      source: AiSource.onDevice,
    ));
  }
}

void main() {
  late AppState state;

  setUp(() => state = AppState());
  tearDown(() => state.dispose());

  VoiceAssistantController build({
    AiService? assistant,
    FakeSpeechRecognizer? recognizer,
    FakeSpeechSynthesizer? synthesizer,
    VoiceLanguage language = VoiceLanguage.english,
    bool autoSpeak = true,
  }) {
    return VoiceAssistantController(
      assistant: assistant ?? const OnDeviceAiService(),
      recognizer: recognizer ?? FakeSpeechRecognizer(),
      synthesizer: synthesizer ?? FakeSpeechSynthesizer(),
      contextBuilder: () => state.aiContext(),
      language: language,
      autoSpeak: autoSpeak,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  group('VoiceLanguageResolver', () {
    const VoiceLanguageResolver resolver = VoiceLanguageResolver();

    test('matches an exact locale', () {
      final ResolvedVoiceLanguage r =
          resolver.resolve(VoiceLanguage.hindi, <String>['en_US', 'hi_IN']);
      expect(r.resolved, VoiceLanguage.hindi);
      expect(r.localeId, 'hi_IN');
      expect(r.isExactMatch, isTrue);
    });

    test('accepts hyphenated ids, which iOS reports', () {
      final ResolvedVoiceLanguage r =
          resolver.resolve(VoiceLanguage.hindi, <String>['hi-IN']);
      expect(r.localeId, 'hi-IN', reason: 'the original id is passed back through');
      expect(r.isExactMatch, isTrue);
    });

    test('finds Assamese when the device genuinely has it', () {
      final ResolvedVoiceLanguage r =
          resolver.resolve(VoiceLanguage.assamese, <String>['as_IN', 'en_IN']);
      expect(r.resolved, VoiceLanguage.assamese);
      expect(r.isFallback, isFalse);
    });

    test('Assamese falls back to Hindi before English', () {
      final ResolvedVoiceLanguage r = resolver
          .resolve(VoiceLanguage.assamese, <String>['en_IN', 'hi_IN']);
      expect(r.resolved, VoiceLanguage.hindi,
          reason: 'a speaker in Jorhat follows Hindi more readily than English');
      expect(r.isFallback, isTrue);
      expect(r.requested, VoiceLanguage.assamese);
    });

    test('Assamese falls through to English when Hindi is absent too', () {
      final ResolvedVoiceLanguage r =
          resolver.resolve(VoiceLanguage.assamese, <String>['en_US']);
      expect(r.resolved, VoiceLanguage.english);
      expect(r.isFallback, isTrue);
    });

    test('reports unsupported when the engine offers nothing usable', () {
      expect(
        resolver.resolve(VoiceLanguage.assamese, <String>['fr_FR']).isSupported,
        isFalse,
      );
      expect(resolver.resolve(VoiceLanguage.english, <String>[]).isSupported, isFalse);
    });

    test('maps the free-text patient language field', () {
      expect(VoiceLanguageX.fromPatientLanguage('Assamese'), VoiceLanguage.assamese);
      expect(VoiceLanguageX.fromPatientLanguage('Hindi'), VoiceLanguage.hindi);
      expect(VoiceLanguageX.fromPatientLanguage('Bodo'), VoiceLanguage.english,
          reason: 'an unmapped language degrades rather than failing');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('the complete voice → AI → voice flow', () {
    test('speech becomes a spoken answer, ending back at idle', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer()
        ..script = const <SpeechResult>[
          SpeechResult(text: 'what are my', isFinal: false),
          SpeechResult(text: 'what are my reminders', isFinal: true),
        ];
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c =
          build(recognizer: mic, synthesizer: speaker);

      final List<VoicePhase> phases = <VoicePhase>[];
      c.addListener(() => phases.add(c.phase));

      await c.startListening();
      await Future<void>.delayed(Duration.zero);

      // Heard, answered, and spoken aloud.
      expect(c.recognizedText, 'what are my reminders');
      expect(c.reply, isNotNull);
      expect(c.reply!.intent, AssistantIntent.reminders);
      expect(speaker.spoken.single, c.reply!.text);
      expect(speaker.lastLocaleId, 'en-IN',
          reason: 'the speech and TTS engines advertise ids differently');

      // The phases the UI renders, in order.
      expect(phases, containsAllInOrder(<VoicePhase>[
        VoicePhase.listening,
        VoicePhase.thinking,
        VoicePhase.speaking,
        VoicePhase.idle,
      ]));
      expect(c.phase, VoicePhase.idle);
      c.dispose();
    });

    test('the answer is grounded in real app data, not invented', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer()
        ..script = const <SpeechResult>[
          SpeechResult(text: 'what are my reminders', isFinal: true),
        ];
      final VoiceAssistantController c = build(recognizer: mic);
      await c.startListening();
      await Future<void>.delayed(Duration.zero);

      final Reminder due = state.reminders.firstWhere((Reminder r) => !r.done);
      expect(c.reply!.text.toLowerCase(), contains(due.title.toLowerCase()));
      c.dispose();
    });

    test('partial results appear live while the patient is still speaking',
        () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer();
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      expect(c.phase, VoicePhase.listening);

      mic.emit(const SpeechResult(text: 'what do', isFinal: false));
      expect(c.recognizedText, 'what do');
      expect(c.phase, VoicePhase.listening, reason: 'a partial does not end the turn');

      mic.emit(const SpeechResult(text: 'what do I have today', isFinal: false));
      expect(c.recognizedText, 'what do I have today');
      c.dispose();
    });

    test('the follow-up chips reach the same assistant without the microphone',
        () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer();
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c =
          build(recognizer: mic, synthesizer: speaker);

      await c.askDirectly('What activity should I do?');

      expect(mic.listenCount, 0, reason: 'no microphone involved');
      expect(c.reply!.intent, AssistantIntent.activity);
      expect(c.reply!.suggestedActivity, isNotNull);
      expect(speaker.spoken, hasLength(1), reason: 'still read aloud');
      c.dispose();
    });

    test('autoSpeak off leaves the answer readable but silent', () async {
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c =
          build(synthesizer: speaker, autoSpeak: false);

      await c.askDirectly('What do I have today?');
      expect(c.reply, isNotNull);
      expect(speaker.spoken, isEmpty);
      expect(c.phase, VoicePhase.idle);
      c.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('stopping and cancelling', () {
    test('"I have finished" answers what was heard so far', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer();
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      mic.emit(const SpeechResult(text: 'what are my reminders', isFinal: false));
      await c.stopListening();

      expect(mic.stopCount, 1);
      expect(c.reply, isNotNull, reason: 'a partial transcript is still a question');
      c.dispose();
    });

    test('cancel while listening abandons the turn and speaks nothing', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer();
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c =
          build(recognizer: mic, synthesizer: speaker);

      await c.startListening();
      mic.emit(const SpeechResult(text: 'never mind', isFinal: false));
      await c.cancel();

      expect(mic.cancelCount, 1);
      expect(c.phase, VoicePhase.idle);
      expect(c.recognizedText, isEmpty);
      expect(c.reply, isNull);
      expect(speaker.spoken, isEmpty);
      c.dispose();
    });

    test('a result arriving after cancel is discarded', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer();
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      await c.cancel();
      // The engine had one more result in flight.
      mic.emit(const SpeechResult(text: 'what are my reminders', isFinal: true));
      await Future<void>.delayed(Duration.zero);

      expect(c.reply, isNull, reason: 'a cancelled turn must not answer');
      expect(c.phase, VoicePhase.idle);
      c.dispose();
    });

    test('stop speaking silences the audio but keeps the answer', () async {
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer()
        ..gate = Completer<void>();
      final VoiceAssistantController c = build(synthesizer: speaker);

      final Future<void> turn = c.askDirectly('What do I have today?');
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, VoicePhase.speaking);

      await c.stopSpeaking();
      expect(speaker.stopCount, 1);
      expect(c.phase, VoicePhase.idle);
      expect(c.reply, isNotNull, reason: 'the answer stays on screen to be read');
      await turn;
      c.dispose();
    });

    test('"say it again" re-speaks without asking the assistant again',
        () async {
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c = build(synthesizer: speaker);

      await c.askDirectly('What are my reminders?');
      expect(speaker.spoken, hasLength(1));

      await c.replay();
      expect(speaker.spoken, hasLength(2));
      expect(speaker.spoken.first, speaker.spoken.last);
      c.dispose();
    });

    test('the thinking phase is observable and cancellable', () async {
      final _GatedAssistant assistant = _GatedAssistant();
      final VoiceAssistantController c = build(assistant: assistant);

      final Future<void> turn = c.askDirectly('What do I have today?');
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, VoicePhase.thinking);
      expect(c.phase.isCancellable, isTrue);

      await c.cancel();
      assistant.gate.complete();
      await turn;

      expect(c.reply, isNull, reason: 'the abandoned answer never lands');
      expect(c.phase, VoicePhase.idle);
      c.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('permission handling', () {
    test('permission is only requested when not already granted', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(alreadyGranted: true)
        ..script = const <SpeechResult>[
          SpeechResult(text: 'what are my reminders', isFinal: true),
        ];
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      await Future<void>.delayed(Duration.zero);
      expect(c.reply, isNotNull);
      c.dispose();
    });

    test('a refusal is explained and stays retryable', () async {
      final VoiceAssistantController c = build(
        recognizer: FakeSpeechRecognizer(
          permission: SpeechPermissionOutcome.denied,
        ),
      );

      await c.startListening();
      expect(c.phase, VoicePhase.error);
      expect(c.error!.kind, VoiceErrorKind.permissionDenied);
      expect(c.error!.isRetryable, isTrue);
      expect(c.error!.message, isNot(contains('error')),
          reason: 'patient-facing wording, not a code');
      c.dispose();
    });

    test('a permanent refusal points at Settings and is not retryable',
        () async {
      final VoiceAssistantController c = build(
        recognizer: FakeSpeechRecognizer(
          permission: SpeechPermissionOutcome.permanentlyDenied,
        ),
      );

      await c.startListening();
      expect(c.error!.kind, VoiceErrorKind.permissionPermanentlyDenied);
      expect(c.error!.isRetryable, isFalse);
      expect(c.error!.message.toLowerCase(), contains('settings'));
      c.dispose();
    });

    test('a device with no speech engine says so and never opens the mic',
        () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer(
        available: false,
        permission: SpeechPermissionOutcome.unavailable,
      );
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      expect(c.error!.kind, VoiceErrorKind.speechUnavailable);
      expect(mic.listenCount, 0);
      expect(c.canListen, isFalse, reason: 'the UI hides the mic instead of lying');
      c.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('speech and AI error handling', () {
    test('silence is reported gently rather than as a failure', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer()
        ..script = const <SpeechResult>[SpeechResult(text: '   ', isFinal: true)];
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      await Future<void>.delayed(Duration.zero);
      expect(c.error!.kind, VoiceErrorKind.noSpeechDetected);
      expect(c.error!.isRetryable, isTrue);
      c.dispose();
    });

    test('a mid-recognition failure surfaces without crashing', () async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer()
        ..errorToRaise = const VoiceError(VoiceErrorKind.recognitionFailed);
      final VoiceAssistantController c = build(recognizer: mic);

      await c.startListening();
      expect(c.phase, VoicePhase.error);
      expect(c.error!.kind, VoiceErrorKind.recognitionFailed);
      c.dispose();
    });

    test('an assistant failure is reported, not spoken as an empty answer',
        () async {
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c =
          build(assistant: _FailingAssistant(), synthesizer: speaker);

      await c.askDirectly('What do I have today?');
      expect(c.error!.kind, VoiceErrorKind.assistantFailed);
      expect(c.reply, isNull);
      expect(speaker.spoken, isEmpty);
      c.dispose();
    });

    test('no text-to-speech still delivers a readable answer', () async {
      final VoiceAssistantController c = build(
        synthesizer: FakeSpeechSynthesizer(available: false, languages: <String>[]),
      );

      await c.askDirectly('What are my reminders?');
      expect(c.reply, isNotNull, reason: 'the answer survives');
      expect(c.error!.kind, VoiceErrorKind.ttsUnavailable);
      expect(c.error!.kind.isSpeechOnly, isTrue,
          reason: 'a notice, not a failure — the UI styles it softly');
      expect(c.phase, VoicePhase.idle);
      c.dispose();
    });

    test('a text-to-speech crash mid-utterance keeps the answer', () async {
      final VoiceAssistantController c =
          build(synthesizer: FakeSpeechSynthesizer(failOnSpeak: true));

      await c.askDirectly('What are my reminders?');
      expect(c.reply, isNotNull);
      expect(c.error!.kind, VoiceErrorKind.ttsFailed);
      expect(c.phase, VoicePhase.idle);
      c.dispose();
    });

    test('an unsupported language fails before the microphone opens', () async {
      final FakeSpeechRecognizer mic =
          FakeSpeechRecognizer(locales: <String>['fr_FR']);
      final VoiceAssistantController c =
          build(recognizer: mic, language: VoiceLanguage.assamese);

      await c.startListening();
      expect(c.error!.kind, VoiceErrorKind.languageUnsupported);
      expect(mic.listenCount, 0);
      c.dispose();
    });

    test('dismissing an error returns the microphone', () async {
      final VoiceAssistantController c = build(
        recognizer: FakeSpeechRecognizer(permission: SpeechPermissionOutcome.denied),
      );

      await c.startListening();
      expect(c.phase, VoicePhase.error);
      c.dismissError();
      expect(c.phase, VoicePhase.idle);
      expect(c.error, isNull);
      c.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('language selection against a real device list', () {
    test('an Assamese profile on an English-only device announces the fallback',
        () async {
      final FakeSpeechRecognizer mic =
          FakeSpeechRecognizer(locales: <String>['en_IN']);
      final VoiceAssistantController c =
          build(recognizer: mic, language: VoiceLanguage.assamese);

      await c.initialize();
      expect(c.resolvedInputLanguage!.isFallback, isTrue);
      expect(c.resolvedInputLanguage!.resolved, VoiceLanguage.english);
      c.dispose();
    });

    test('input and output languages resolve independently', () async {
      // A device that can *hear* Hindi but can only *speak* English.
      final VoiceAssistantController c = build(
        recognizer: FakeSpeechRecognizer(locales: <String>['hi_IN']),
        synthesizer: FakeSpeechSynthesizer(languages: <String>['en-IN']),
        language: VoiceLanguage.hindi,
      );

      await c.initialize();
      expect(c.resolvedInputLanguage!.resolved, VoiceLanguage.hindi);
      expect(c.resolvedOutputLanguage!.resolved, VoiceLanguage.english);
      expect(c.resolvedOutputLanguage!.isFallback, isTrue);
      c.dispose();
    });

    test('switching language cancels the turn and re-resolves', () async {
      final FakeSpeechRecognizer mic =
          FakeSpeechRecognizer(locales: <String>['en_IN', 'hi_IN']);
      final VoiceAssistantController c = build(recognizer: mic);

      await c.initialize();
      expect(c.resolvedInputLanguage!.localeId, 'en_IN');

      await c.setLanguage(VoiceLanguage.hindi);
      expect(c.language, VoiceLanguage.hindi);
      expect(c.resolvedInputLanguage!.localeId, 'hi_IN');
      c.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('the sheet', () {
    Widget harness(Widget child, AppState state) => AppScope(
          state: state,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.warm(),
            home: Scaffold(body: child),
          ),
        );

    testWidgets('walks the patient from prompt to spoken answer',
        (WidgetTester tester) async {
      final FakeSpeechRecognizer mic = FakeSpeechRecognizer();
      final FakeSpeechSynthesizer speaker = FakeSpeechSynthesizer();
      final VoiceAssistantController c = VoiceAssistantController(
        assistant: const OnDeviceAiService(),
        recognizer: mic,
        synthesizer: speaker,
        contextBuilder: () => state.aiContext(),
      );

      await tester.pumpWidget(harness(
        VoiceAssistantSheet(controller: c),
        state,
      ));
      await tester.pump();

      expect(find.text('Ask Saathi'), findsOneWidget);
      expect(find.text('Tap the microphone and ask me'), findsOneWidget);
      expect(find.text('Talk to Saathi'), findsOneWidget);

      // Tap the microphone.
      await tester.tap(find.text('Talk to Saathi'));
      await tester.pump();
      expect(find.text('I am listening…'), findsOneWidget);
      expect(find.text('I have finished'), findsOneWidget,
          reason: 'a stop control while the mic is open');

      // Words arrive.
      mic.emit(const SpeechResult(text: 'what are my reminders', isFinal: false));
      await tester.pump();
      expect(find.textContaining('what are my reminders'), findsOneWidget,
          reason: 'the patient can see they were heard');

      // Finish and answer.
      await tester.tap(find.text('I have finished'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(c.reply, isNotNull);
      expect(speaker.spoken, hasLength(1));
      expect(find.text('Ask something else'), findsOneWidget);
      expect(find.text('Say it again'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });

    testWidgets('shows the language fallback notice honestly',
        (WidgetTester tester) async {
      final VoiceAssistantController c = VoiceAssistantController(
        assistant: const OnDeviceAiService(),
        recognizer: FakeSpeechRecognizer(locales: <String>['en_IN']),
        synthesizer: FakeSpeechSynthesizer(),
        contextBuilder: () => state.aiContext(),
        language: VoiceLanguage.assamese,
      );

      await tester.pumpWidget(harness(VoiceAssistantSheet(controller: c), state));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('cannot listen in Assamese'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });

    testWidgets('a denied microphone explains itself in the sheet',
        (WidgetTester tester) async {
      final VoiceAssistantController c = VoiceAssistantController(
        assistant: const OnDeviceAiService(),
        recognizer:
            FakeSpeechRecognizer(permission: SpeechPermissionOutcome.denied),
        synthesizer: FakeSpeechSynthesizer(),
        contextBuilder: () => state.aiContext(),
      );

      await tester.pumpWidget(harness(VoiceAssistantSheet(controller: c), state));
      await tester.pump();
      await tester.tap(find.text('Talk to Saathi'));
      await tester.pump();

      expect(find.textContaining('permission to use the microphone'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });

    testWidgets('the home-screen entry point opens the sheet — voice unavailable path',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Explicitly inject unavailable stubs to exercise the "no speech plugin"
      // code path — now that the default is the real SpeechToTextRecognizer.
      await tester.pumpWidget(harness(
        const AskSaathiButton(
          recognizer: UnavailableSpeechRecognizer(),
          synthesizer: UnavailableSpeechSynthesizer(),
        ),
        state,
      ));
      await tester.pump();

      expect(find.text('Ask Saathi'), findsOneWidget);
      expect(find.text('Talk to me about your day'), findsOneWidget);

      await tester.tap(find.text('Ask Saathi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The sheet is up, and reports voice unavailable in a build with no
      // speech plugins — rather than offering a microphone that cannot work.
      expect(find.text('Voice is unavailable'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
