import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/core/voice/speech_engines.dart';
import 'package:memory_mitra/core/voice/voice_language.dart';
import 'package:memory_mitra/core/voice/voice_models.dart';
import 'package:memory_mitra/core/voice/voice_nav_intent.dart';
import 'package:memory_mitra/core/voice/voice_navigation_controller.dart';
import 'package:memory_mitra/core/widgets/voice_nav_host.dart';
import 'package:memory_mitra/l10n/app_localizations.dart';

const VoiceNavMatcher matcher = VoiceNavMatcher();

/// Every destination the patient shell offers, so the matcher tests exercise
/// the same set the running app does.
const Set<VoiceDestination> patientSet = <VoiceDestination>{
  VoiceDestination.home,
  VoiceDestination.today,
  VoiceDestination.reminders,
  VoiceDestination.activities,
  VoiceDestination.companion,
  VoiceDestination.profile,
  VoiceDestination.memories,
  VoiceDestination.memoryLane,
  VoiceDestination.carePlan,
  VoiceDestination.report,
  VoiceDestination.progress,
};

void main() {
  group('VoiceNavMatcher — English', () {
    test('bare place names resolve', () {
      for (final MapEntry<String, VoiceDestination> e in <String, VoiceDestination>{
        'home': VoiceDestination.home,
        'today': VoiceDestination.today,
        'games': VoiceDestination.activities,
        'my report': VoiceDestination.report,
        'care plan': VoiceDestination.carePlan,
        'memories': VoiceDestination.memories,
        'my progress': VoiceDestination.progress,
      }.entries) {
        expect(matcher.match(e.key, allowed: patientSet).destination, e.value,
            reason: 'for "${e.key}"');
      }
    });

    test('polite scaffolding is stripped', () {
      for (final String said in <String>[
        'please take me to the report page',
        'can you open my report',
        'show me the report screen',
        'I want to go to the report',
        'Mitra, open report now',
      ]) {
        expect(matcher.match(said, allowed: patientSet).destination,
            VoiceDestination.report,
            reason: 'for "$said"');
      }
    });

    test('longest phrase wins, so a specific place beats a generic one', () {
      // "plan" alone is care plan, but "care plan" must not be beaten by a
      // shorter phrase belonging to another destination.
      expect(matcher.match('care plan', allowed: patientSet).destination,
          VoiceDestination.carePlan);
      // "memory lane" must not collapse into "memories".
      expect(matcher.match('memory lane', allowed: patientSet).destination,
          VoiceDestination.memoryLane);
    });

    test('whole-word matching, so a place name inside another word is ignored', () {
      // "homework" contains "home"; a substring match would send them away.
      expect(matcher.match('homework', allowed: patientSet).isNothing, isTrue);
    });
  });

  group('VoiceNavMatcher — Hindi and Assamese', () {
    test('Devanagari resolves', () {
      expect(matcher.match('घर', allowed: patientSet).destination, VoiceDestination.home);
      expect(matcher.match('मुझे रिपोर्ट दिखाओ', allowed: patientSet).destination,
          VoiceDestination.report);
      expect(matcher.match('खेल खोलो', allowed: patientSet).destination,
          VoiceDestination.activities);
      expect(matcher.match('यादें', allowed: patientSet).destination,
          VoiceDestination.memories);
    });

    test('Assamese resolves', () {
      expect(matcher.match('ঘৰ', allowed: patientSet).destination, VoiceDestination.home);
      expect(matcher.match('ৰিপৰ্ট', allowed: patientSet).destination,
          VoiceDestination.report);
      expect(matcher.match('খেল', allowed: patientSet).destination,
          VoiceDestination.activities);
      expect(matcher.match('স্মৃতি', allowed: patientSet).destination,
          VoiceDestination.memories);
    });

    test('romanised Hindi resolves, because that is how engines often return it',
        () {
      expect(matcher.match('mujhe ghar le chalo', allowed: patientSet).destination,
          VoiceDestination.home);
      expect(matcher.match('khel kholo', allowed: patientSet).destination,
          VoiceDestination.activities);
    });

    test('code-switching works: an English place name in a Hindi sentence', () {
      expect(matcher.match('mujhe report dikhao', allowed: patientSet).destination,
          VoiceDestination.report);
    });
  });

  group('VoiceNavMatcher — actions', () {
    test('back, help and stop win over any destination', () {
      expect(matcher.match('go back', allowed: patientSet).action, VoiceNavAction.back);
      expect(matcher.match('पीछे', allowed: patientSet).action, VoiceNavAction.back);
      expect(matcher.match('উভতি যাওক', allowed: patientSet).action, VoiceNavAction.back);
      expect(matcher.match('what can I say', allowed: patientSet).action,
          VoiceNavAction.help);
      expect(matcher.match('मदद', allowed: patientSet).action, VoiceNavAction.help);
      expect(matcher.match('stop', allowed: patientSet).action, VoiceNavAction.stop);
    });

    test('nonsense resolves to nothing rather than a guess', () {
      expect(matcher.match('bananas and rainfall', allowed: patientSet).isNothing, isTrue);
      expect(matcher.match('', allowed: patientSet).isNothing, isTrue);
    });
  });

  group('VoiceNavMatcher — misheard words', () {
    test('a place name mangled by noise still resolves', () {
      for (final MapEntry<String, VoiceDestination> e in <String, VoiceDestination>{
        // One or two characters wrong is what a fan or a television does to
        // a transcript.
        'activitis': VoiceDestination.activities,
        'take me to activites': VoiceDestination.activities,
        'open my repot': VoiceDestination.report,
        'show me the memores': VoiceDestination.memories,
        'go to compainon': VoiceDestination.companion,
        'care plann': VoiceDestination.carePlan,
        'my progres': VoiceDestination.progress,
      }.entries) {
        expect(matcher.match(e.key, allowed: patientSet).destination, e.value,
            reason: 'for "${e.key}"');
      }
    });

    test('a misheard instruction still resolves', () {
      expect(matcher.match('go bak', allowed: patientSet).action, VoiceNavAction.back);
      expect(matcher.match('canel', allowed: patientSet).action, VoiceNavAction.stop);
    });

    test('the place name is found inside a noisy sentence', () {
      expect(
        matcher.match('umm can you please take me to the activites page now',
            allowed: patientSet).destination,
        VoiceDestination.activities,
      );
    });

    test('short words are not "corrected" into a destination', () {
      // "hope", "come", "more" are each one edit from a real phrase. Acting on
      // them would send someone somewhere they never asked for, so the budget
      // scales with length and three-letter noise resolves to nothing.
      for (final String said in <String>['hop', 'com', 'mor', 'tod']) {
        expect(matcher.match(said, allowed: patientSet).isNothing, isTrue,
            reason: 'for "$said"');
      }
    });

    test('genuine nonsense is still refused rather than nudged somewhere', () {
      for (final String said in <String>[
        'bananas and rainfall',
        'what is the weather like tomorrow',
        'my grandson is coming on sunday',
      ]) {
        expect(matcher.match(said, allowed: patientSet).isNothing, isTrue,
            reason: 'for "$said"');
      }
    });

    test('an exact match is never overridden by a fuzzy one', () {
      // "report" is exact; "reports" is one edit from it and from nothing
      // else. Both must land on the report, not on whatever happens to be
      // one edit closer.
      expect(matcher.match('report', allowed: patientSet).destination,
          VoiceDestination.report);
      expect(matcher.match('reports', allowed: patientSet).destination,
          VoiceDestination.report);
    });
  });

  group('the allowed set biases matching without filtering it', () {
    const Set<VoiceDestination> doctorSet = <VoiceDestination>{
      VoiceDestination.overview,
      VoiceDestination.patients,
      VoiceDestination.analytics,
      VoiceDestination.alerts,
      VoiceDestination.profile,
    };

    test('a reachable place resolves', () {
      expect(matcher.match('alerts', allowed: doctorSet).destination,
          VoiceDestination.alerts);
    });

    test('an unreachable place still resolves, so it can be refused aloud', () {
      // Silence here would read as "it did not hear me". Resolving it lets the
      // controller answer "I cannot open that from here", which is a limit the
      // person can understand rather than a fault they cannot.
      expect(matcher.match('memories', allowed: doctorSet).destination,
          VoiceDestination.memories);
    });

    test('an ambiguous word goes to the reachable reading first', () {
      // "activity" names the patient's games and the caregiver's log. Each
      // shell hears its own.
      expect(
        matcher.match('activity', allowed: patientSet).destination,
        VoiceDestination.activities,
      );
      expect(
        matcher.match('activity',
            allowed: const <VoiceDestination>{VoiceDestination.activityLog}).destination,
        VoiceDestination.activityLog,
      );
    });
  });

  group('VoiceNavigationController', () {
    late FakeSpeechRecognizer mic;
    late FakeSpeechSynthesizer tts;
    late List<VoiceDestination> navigated;

    VoiceNavigationController build({
      VoiceLanguage language = VoiceLanguage.english,
      Set<VoiceDestination> destinations = patientSet,
      bool navigateSucceeds = true,
      VoiceNavBack? onBack,
    }) {
      return VoiceNavigationController(
        recognizer: mic,
        synthesizer: tts,
        destinations: destinations,
        language: language,
        onBack: onBack,
        onNavigate: (VoiceDestination d) {
          navigated.add(d);
          return navigateSucceeds;
        },
      );
    }

    setUp(() {
      mic = FakeSpeechRecognizer(alreadyGranted: true);
      tts = FakeSpeechSynthesizer();
      navigated = <VoiceDestination>[];
    });

    test('a spoken place navigates and is confirmed aloud', () async {
      mic.script = const <SpeechResult>[SpeechResult(text: 'open my report', isFinal: true)];
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(navigated, <VoiceDestination>[VoiceDestination.report]);
      expect(tts.spoken, <String>['What should I do for you?', 'Opening Report.']);
      expect(c.phase, VoicePhase.idle);
      // The host reads this once to dismiss its panel.
      expect(c.takeNavigated(), VoiceDestination.report);
      expect(c.takeNavigated(), isNull);
      c.dispose();
    });

    test('confirms in Hindi when Hindi is the voice language', () async {
      mic.script = const <SpeechResult>[SpeechResult(text: 'घर', isFinal: true)];
      final VoiceNavigationController c = build(language: VoiceLanguage.hindi);
      await c.start();
      await pumpEventQueue();

      expect(navigated, <VoiceDestination>[VoiceDestination.home]);
      expect(tts.spoken, <String>['मैं आपके लिए क्या करूँ?', 'होम खोल रहे हैं।']);
      expect(mic.lastLocaleId, 'hi_IN');
      c.dispose();
    });

    test('Assamese steps down to Hindi and speaks the fallback language', () async {
      // The realistic device: Hindi installed, Assamese not.
      mic.locales = <String>['en_IN', 'hi_IN'];
      tts.languages = <String>['en-IN', 'hi-IN'];
      mic.script = const <SpeechResult>[SpeechResult(text: 'ঘৰ', isFinal: true)];

      final VoiceNavigationController c = build(language: VoiceLanguage.assamese);
      await c.start();
      await pumpEventQueue();

      expect(c.resolvedInputLanguage!.isFallback, isTrue);
      expect(c.spokenLanguage, VoiceLanguage.hindi);
      expect(navigated, <VoiceDestination>[VoiceDestination.home]);
      // Assamese words still matched, because the phrase table is shared.
      expect(tts.spoken, <String>['मैं आपके लिए क्या करूँ?', 'होम खोल रहे हैं।']);
      c.dispose();
    });

    test('Assamese is used directly when the device has it', () async {
      mic.locales = <String>['en_IN', 'as_IN'];
      tts.languages = <String>['en-IN', 'as-IN'];
      mic.script = const <SpeechResult>[SpeechResult(text: 'ৰিপৰ্ট', isFinal: true)];

      final VoiceNavigationController c = build(language: VoiceLanguage.assamese);
      await c.start();
      await pumpEventQueue();

      expect(c.resolvedInputLanguage!.isFallback, isFalse);
      expect(navigated, <VoiceDestination>[VoiceDestination.report]);
      expect(tts.spoken.last, contains('ৰিপৰ্ট'));
      c.dispose();
    });

    test('a place this shell cannot reach is refused aloud, not ignored', () async {
      mic.script = const <SpeechResult>[SpeechResult(text: 'analytics', isFinal: true)];
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(navigated, isEmpty);
      expect(c.takeNavigated(), isNull);
      expect(tts.spoken.last, contains('cannot open'));
      c.dispose();
    });

    test('unrecognised speech says so rather than navigating somewhere', () async {
      mic.script =
          const <SpeechResult>[SpeechResult(text: 'bananas and rainfall', isFinal: true)];
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(navigated, isEmpty);
      expect(tts.spoken.last, contains('did not catch'));
      c.dispose();
    });

    test('silence is an error the person can retry from', () async {
      mic.script = const <SpeechResult>[SpeechResult(text: '', isFinal: true)];
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(c.phase, VoicePhase.error);
      expect(c.error!.kind, VoiceErrorKind.noSpeechDetected);
      expect(c.error!.isRetryable, isTrue);
      c.dispose();
    });

    test('"go back" pops, and says nothing when there is nothing to pop', () async {
      mic.script = const <SpeechResult>[SpeechResult(text: 'go back', isFinal: true)];
      int pops = 0;

      final VoiceNavigationController c = build(onBack: () {
        pops++;
        return true;
      });
      await c.start();
      await pumpEventQueue();
      expect(pops, 1);
      expect(tts.spoken.last, 'Going back.');
      c.dispose();

      tts.spoken.clear();
      mic.script = const <SpeechResult>[SpeechResult(text: 'go back', isFinal: true)];
      final VoiceNavigationController d = build(onBack: () => false);
      await d.start();
      await pumpEventQueue();
      expect(d.status, contains('did not catch'));
      // Only the opening question — nothing is confirmed, because nothing
      // happened.
      expect(tts.spoken, <String>['What should I do for you?']);
      d.dispose();
    });

    test('"help" reads the destinations this shell offers', () async {
      mic.script = const <SpeechResult>[SpeechResult(text: 'what can I say', isFinal: true)];
      final VoiceNavigationController c = build(
        destinations: const <VoiceDestination>{
          VoiceDestination.home,
          VoiceDestination.today,
        },
      );
      await c.start();
      await pumpEventQueue();

      expect(tts.spoken.last, 'You can say: Home, Today. Or say back, or stop.');
      c.dispose();
    });

    test('a pause ends the turn: nobody has to say they have finished',
        () async {
      // The engine's own ending, which is how a normal sentence finishes.
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'take me to', isFinal: false),
        SpeechResult(text: 'take me to activities', isFinal: true),
      ];
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(navigated, <VoiceDestination>[VoiceDestination.activities]);
      // Never stopped by hand — the turn ended itself.
      expect(mic.stopCount, 0);
      c.dispose();
    });

    test('an engine that never sends a final result still ends the turn', () {
      // The Android builds that announce the end of a turn only as a status:
      // partials arrive, then silence, and no final ever comes. Without the
      // safety net the person is left talking to a microphone that has
      // stopped caring.
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'open my report', isFinal: false),
      ];
      final VoiceNavigationController c = build();

      // A synchronous body: `elapse` drives the fake clock, and the fakes
      // complete on microtasks it flushes as it goes.
      fakeAsync((FakeAsync time) {
        unawaited(c.start());
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 1));
        expect(c.phase, VoicePhase.listening, reason: 'still waiting for more words');
        expect(navigated, isEmpty);

        // Past the settle window with nothing new heard.
        time.elapse(const Duration(seconds: 5));
        time.flushMicrotasks();
      });

      expect(navigated, <VoiceDestination>[VoiceDestination.report]);
      expect(mic.stopCount, 1);
      c.dispose();
    });

    test('the deadline moves with each word, so a slow speaker is not cut off', () {
      final VoiceNavigationController c = build();

      fakeAsync((FakeAsync time) {
        unawaited(c.start());
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 1));

        // Three seconds apart — past the post-speech window each time, but
        // each word pushes the deadline back.
        for (final String said in <String>['take', 'take me', 'take me to report']) {
          mic.emit(SpeechResult(text: said, isFinal: false));
          time.elapse(const Duration(seconds: 3));
          expect(navigated, isEmpty, reason: 'still speaking after "$said"');
        }

        time.elapse(const Duration(seconds: 5));
        time.flushMicrotasks();
      });

      expect(navigated, <VoiceDestination>[VoiceDestination.report]);
      c.dispose();
    });

    test('a turn that ends twice still navigates once', () async {
      // A final result and a done status for the same utterance: the engine
      // is entitled to both, and acting on both would navigate twice.
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'open my report', isFinal: true),
        SpeechResult(text: 'open my report', isFinal: true),
      ];
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(navigated, <VoiceDestination>[VoiceDestination.report]);
      c.dispose();
    });

    test('speaking can be interrupted, and the question is not repeated',
        () async {
      tts.gate = Completer<void>();
      final VoiceNavigationController c = build();
      unawaited(c.start());
      await pumpEventQueue();
      expect(c.phase, VoicePhase.speaking, reason: 'held mid-question');

      mic.script = const <SpeechResult>[SpeechResult(text: 'home', isFinal: true)];
      await c.interrupt();
      await pumpEventQueue();

      // Only the opening question was ever uttered, not a second one.
      expect(tts.spoken.where((String t) => t.contains('What should I do')), hasLength(1));
      expect(navigated, <VoiceDestination>[VoiceDestination.home]);
      c.dispose();
    });

    test('a denied microphone is an error, and never a silent no-op', () async {
      mic = FakeSpeechRecognizer(permission: SpeechPermissionOutcome.denied);
      final VoiceNavigationController c = build();
      await c.start();
      await pumpEventQueue();

      expect(c.phase, VoicePhase.error);
      expect(c.error!.kind, VoiceErrorKind.permissionDenied);
      expect(navigated, isEmpty);
      c.dispose();
    });

    test('go() reaches a destination without opening the microphone', () async {
      final VoiceNavigationController c = build();
      await c.go(VoiceDestination.carePlan);
      await pumpEventQueue();

      expect(navigated, <VoiceDestination>[VoiceDestination.carePlan]);
      expect(mic.listenCount, 0);
      c.dispose();
    });

    test('options are named in the spoken language', () async {
      final VoiceNavigationController c = build(
        language: VoiceLanguage.hindi,
        destinations: const <VoiceDestination>{VoiceDestination.home, VoiceDestination.today},
      );
      await c.initialize();
      expect(
        c.options.map((({VoiceDestination destination, String label}) o) => o.label),
        <String>['होम', 'आज'],
      );
      c.dispose();
    });
  });

  group('VoiceNavHost', () {
    testWidgets('the mic asks a question and offers no menu to read',
        (WidgetTester tester) async {
      final FakeSpeechSynthesizer tts = FakeSpeechSynthesizer();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VoiceNavHost(
            destinations: const <VoiceDestination>{
              VoiceDestination.home,
              VoiceDestination.report,
            },
            recognizer: FakeSpeechRecognizer(alreadyGranted: true),
            synthesizer: tts,
            onNavigate: (VoiceDestination d) => true,
            child: const Center(child: Text('shell content')),
          ),
        ),
      ));
      // The localisation delegates resolve asynchronously, so the first frame
      // after pumpWidget is still empty.
      await tester.pump();

      expect(find.text('shell content'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The question is both asked aloud and shown.
      expect(tts.spoken, <String>['What should I do for you?']);
      expect(find.text('What should I do for you?'), findsOneWidget);

      // No destination menu: the person answers the question rather than
      // reading a list.
      expect(find.text('Home'), findsNothing);
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('a screen\'s own floating button clears the microphone',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);

      // A Scaffold's floating button and this overlay live in separate
      // trees and know nothing about each other, so nothing but geometry
      // keeps them apart.
      Future<void> pumpWith(Widget floatingButton) async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VoiceNavHost(
              destinations: const <VoiceDestination>{VoiceDestination.home},
              recognizer: FakeSpeechRecognizer(alreadyGranted: true),
              synthesizer: FakeSpeechSynthesizer(),
              onNavigate: (VoiceDestination d) => true,
              child: Scaffold(
                body: const Center(child: Text('screen content')),
                floatingActionButton: floatingButton,
              ),
            ),
          ),
        ));
        await tester.pump();
      }

      void expectClear() {
        final Rect mic = tester.getRect(find.byIcon(Icons.mic_rounded));
        final Rect fab = tester.getRect(find.byType(FloatingActionButton));
        expect(mic.overlaps(fab), isFalse,
            reason: 'mic $mic overlaps the screen\'s button $fab');
      }

      // What Today does now: a plain circular button in the corner, narrow
      // enough to clear the centred microphone on its own.
      await pumpWith(FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add_alarm_rounded),
      ));
      expectClear();

      // And the shape that originally broke — a wide labelled button, which
      // does reach the centre and so has to be lifted out of the lane.
      await pumpWith(Padding(
        padding: const EdgeInsets.only(bottom: VoiceNavHost.micLaneHeight),
        child: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add_alarm_rounded),
          label: const Text('Create reminder'),
        ),
      ));
      expectClear();
    });

    testWidgets('the microphone sits low and centred, above the bottom bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VoiceNavHost(
            destinations: const <VoiceDestination>{VoiceDestination.home},
            recognizer: FakeSpeechRecognizer(alreadyGranted: true),
            synthesizer: FakeSpeechSynthesizer(),
            onNavigate: (VoiceDestination d) => true,
            child: const Center(child: Text('shell content')),
          ),
        ),
      ));
      await tester.pump();

      final Rect mic = tester.getRect(find.byIcon(Icons.mic_rounded));
      final Size body = tester.getSize(find.byType(VoiceNavHost));
      expect((mic.center.dx - body.width / 2).abs(), lessThan(1));
      // Within a mic's height of the bottom edge, where the nav bar begins.
      expect(body.height - mic.bottom, lessThan(80));
    });
  });
}
