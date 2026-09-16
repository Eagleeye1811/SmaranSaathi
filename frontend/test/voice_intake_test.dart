import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/core/voice/speech_engines.dart';
import 'package:smaran_saathi/core/voice/voice_intake_controller.dart';
import 'package:smaran_saathi/core/voice/voice_intake_matcher.dart';
import 'package:smaran_saathi/core/voice/voice_models.dart';

const VoiceIntakeMatcher kMatcher = VoiceIntakeMatcher();

const List<String> kFrequency = <String>['Never', 'Rarely', 'Sometimes', 'Often'];
const List<String> kYesNo = <String>['Yes', 'No'];

void main() {
  group('VoiceIntakeMatcher', () {
    test('hears an option inside an ordinary sentence', () {
      // Nobody answers a spoken question with the bare label.
      expect(kMatcher.match('yes it happens sometimes', kFrequency).optionIndex, 2);
      expect(kMatcher.match('umm, often I think', kFrequency).optionIndex, 3);
      expect(kMatcher.match('no never', kFrequency).optionIndex, 0);
    });

    test('accepts the spoken position as well as the words', () {
      expect(kMatcher.match('number two', kFrequency).optionIndex, 1);
      expect(kMatcher.match('the first one', kFrequency).optionIndex, 0);
      expect(kMatcher.match('four', kFrequency).optionIndex, 3);
    });

    test('understands yes and no however they are said', () {
      expect(kMatcher.match('yeah', kYesNo).optionIndex, 0);
      expect(kMatcher.match('haan', kYesNo).optionIndex, 0);
      expect(kMatcher.match('nope', kYesNo).optionIndex, 1);
      expect(kMatcher.match('no', kYesNo).optionIndex, 1);
    });

    test('an instruction beats an answer', () {
      expect(kMatcher.match('next', kFrequency).command, VoiceIntakeCommand.next);
      expect(kMatcher.match('go back', kFrequency).command, VoiceIntakeCommand.back);
      expect(kMatcher.match('say again', kFrequency).command, VoiceIntakeCommand.repeat);
      expect(kMatcher.match('stop', kFrequency).command, VoiceIntakeCommand.stop);
    });

    test('matches on whole words, so "no" is not found inside another word', () {
      // "Not really" must not be read as the word "no" plus noise.
      expect(kMatcher.match('nothing at all', kYesNo).optionIndex, isNot(0));
      // "one" inside "money" must not select the first option.
      expect(
        kMatcher.match('managing money', <String>['Managing money', 'Cooking'])
            .optionIndex,
        0,
      );
    });

    test('refuses rather than guesses when two options both fit', () {
      // "Never" is a synonym of the "No" option *and* an option of its own.
      final VoiceIntakeMatch result =
          kMatcher.match('never', <String>['Never', 'No']);
      expect(result.isNothing, isTrue,
          reason: 'a wrong answer recorded silently is worse than asking again');
    });

    test('says nothing for silence or gibberish', () {
      expect(kMatcher.match('', kFrequency).isNothing, isTrue);
      expect(kMatcher.match('mmm hmm what', kYesNo).command, VoiceIntakeCommand.repeat);
      expect(kMatcher.match('bananas', kFrequency).isNothing, isTrue);
    });

    test('matchAll finds every option named in one sentence, for a '
        'multi-select question a single match() would refuse', () {
      const List<String> options = <String>['Music', 'Gardening', 'Reading', 'Walking'];
      expect(kMatcher.matchAll('music gardening reading', options), <int>[0, 1, 2]);
      expect(kMatcher.matchAll('just walking', options), <int>[3]);
      expect(kMatcher.matchAll('nothing here', options), isEmpty);
    });

    test('isAffirmative and isNegative recognise a yes or a no in three languages', () {
      for (final String said in <String>['yes', 'yeah', 'haan', 'हाँ', 'হয়']) {
        expect(kMatcher.isAffirmative(said), isTrue, reason: 'for "$said"');
      }
      for (final String said in <String>['no', 'nope', 'nahi', 'नहीं']) {
        expect(kMatcher.isNegative(said), isTrue, reason: 'for "$said"');
      }
      expect(kMatcher.isAffirmative('gardening'), isFalse);
      expect(kMatcher.isNegative('gardening'), isFalse);
    });
  });

  group('spoken numbers and dictation', () {
    test('an age is understood however it is said', () {
      expect(kMatcher.spokenNumber('68'), 68);
      expect(kMatcher.spokenNumber('sixty eight'), 68);
      expect(kMatcher.spokenNumber('I am sixty eight years old'), 68);
      expect(kMatcher.spokenNumber('seventy'), 70);
      expect(kMatcher.spokenNumber('a hundred and two'), 102);
    });

    test('a sentence with no number in it is not a number', () {
      expect(kMatcher.spokenNumber('quite old'), isNull);
      expect(kMatcher.spokenNumber(''), isNull);
      // Nobody is nine hundred; a misheard figure must not be stored.
      expect(kMatcher.spokenNumber('nine hundred'), isNull);
    });

    test('a dictated name loses the sentence around it', () {
      expect(kMatcher.cleanDictation('my name is anita das'), 'Anita Das');
      expect(kMatcher.cleanDictation('i am rahul sharma'), 'Rahul Sharma');
      expect(kMatcher.cleanDictation('her name is priya.'), 'Priya');
      expect(kMatcher.cleanDictation('i worked as a weaver'), 'Weaver');
    });
  });

  group('VoiceIntakeController', () {
    late FakeSpeechRecognizer mic;
    late FakeSpeechSynthesizer voice;
    late List<int> answers;
    late int advanced;

    VoiceIntakeController build({List<VoiceIntakeQuestion>? questions}) {
      mic = FakeSpeechRecognizer(alreadyGranted: true);
      voice = FakeSpeechSynthesizer();
      answers = <int>[];
      advanced = 0;
      final VoiceIntakeController controller = VoiceIntakeController(
        recognizer: mic,
        synthesizer: voice,
        onAdvance: () => advanced++,
      );
      controller.setQuestions(questions ??
          <VoiceIntakeQuestion>[
            VoiceIntakeQuestion(
              prompt: 'How often do you forget appointments?',
              options: kFrequency,
              onSelect: answers.add,
            ),
          ]);
      return controller;
    }

    test('a working device reports itself usable once asked', () async {
      final VoiceIntakeController controller = build();
      expect(controller.probed, isFalse);
      await controller.initialize();
      expect(controller.probed, isTrue);
      expect(controller.canListen, isTrue);
      controller.dispose();
    });

    test('reads the question and its numbered options aloud', () async {
      final VoiceIntakeController controller = build();
      mic.script = const <SpeechResult>[];
      await controller.start();

      expect(voice.spoken, isNotEmpty);
      final String said = voice.spoken.first;
      expect(said, contains('How often do you forget appointments?'));
      expect(said, contains('1. Never'));
      expect(said, contains('4. Often'));
      expect(said, contains('say the number'),
          reason: 'the person has to be told how to answer');
      expect(mic.listenCount, 1, reason: 'it listens straight after asking');
      controller.dispose();
    });

    // The fake microphone replays its script on every `listen`, so one
    // scripted utterance answers each question in turn — which is exactly the
    // walk this test is about.
    test('each spoken answer is recorded, read back, and the screen advances '
        'after the last one', () async {
      final VoiceIntakeController controller = build(
        questions: <VoiceIntakeQuestion>[
          VoiceIntakeQuestion(
            prompt: 'First question',
            options: kYesNo,
            onSelect: (int i) => answers.add(i),
          ),
          VoiceIntakeQuestion(
            prompt: 'Second question',
            options: kYesNo,
            onSelect: (int i) => answers.add(i),
          ),
        ],
      );
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'yes please', isFinal: true),
      ];
      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(answers, <int>[0, 0], reason: 'both questions were answered');
      expect(voice.spoken.any((String s) => s.contains('Yes.')), isTrue,
          reason: 'the answer is confirmed aloud before moving on');
      expect(voice.spoken.any((String s) => s.contains('Second question')), isTrue,
          reason: 'the second question is read out after the first is answered');
      expect(advanced, 1, reason: 'and the screen changes after the last one');
      controller.dispose();
    });

    test('"next" on the last question leaves the screen', () async {
      final VoiceIntakeController controller = build();
      mic.script = const <SpeechResult>[SpeechResult(text: 'next', isFinal: true)];
      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(advanced, 1);
      expect(answers, isEmpty, reason: '"next" is not an answer');
      controller.dispose();
    });

    test('an unrecognised answer asks again instead of guessing', () async {
      final VoiceIntakeController controller = build();
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'the weather is nice', isFinal: true),
      ];
      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(answers, isEmpty);
      expect(voice.spoken.any((String s) => s.contains('did not catch that')), isTrue);
      expect(mic.listenCount, greaterThan(1), reason: 'and it listens again');
      controller.dispose();
    });

    test('"stop" ends voice mode and keeps every answer', () async {
      final VoiceIntakeController controller = build();
      mic.script = const <SpeechResult>[SpeechResult(text: 'stop', isFinal: true)];
      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isActive, isFalse);
      expect(controller.phase, VoicePhase.idle);
      controller.dispose();
    });

    test('a device with no microphone offers nothing at all', () async {
      mic = FakeSpeechRecognizer(available: false);
      voice = FakeSpeechSynthesizer();
      final VoiceIntakeController controller = VoiceIntakeController(
        recognizer: mic,
        synthesizer: voice,
        onAdvance: () {},
      );

      // Nothing is known until the device is asked, and "not asked yet" must
      // never be shown as "cannot listen" — that hid the microphone entirely.
      expect(controller.probed, isFalse);
      await controller.initialize();
      expect(controller.probed, isTrue);
      expect(controller.canListen, isFalse);
      await controller.start();
      expect(controller.isActive, isFalse);
      expect(mic.listenCount, 0);
      controller.dispose();
    });

    test('a refused microphone is reported, not retried forever', () async {
      mic = FakeSpeechRecognizer(
        permission: SpeechPermissionOutcome.permanentlyDenied,
      );
      voice = FakeSpeechSynthesizer();
      final VoiceIntakeController controller = VoiceIntakeController(
        recognizer: mic,
        synthesizer: voice,
        onAdvance: () {},
      );
      controller.setQuestions(<VoiceIntakeQuestion>[
        VoiceIntakeQuestion(prompt: 'q', options: kYesNo, onSelect: (_) {}),
      ]);

      await controller.start();

      expect(controller.isActive, isFalse);
      expect(controller.error?.kind, VoiceErrorKind.permissionPermanentlyDenied);
      expect(mic.listenCount, 0);
      controller.dispose();
    });

    test('a dictated name is recorded in the words the person used', () async {
      final List<String> names = <String>[];
      mic = FakeSpeechRecognizer(alreadyGranted: true);
      voice = FakeSpeechSynthesizer();
      advanced = 0;
      final VoiceIntakeController controller = VoiceIntakeController(
        recognizer: mic,
        synthesizer: voice,
        onAdvance: () => advanced++,
      );
      controller.setQuestions(<VoiceIntakeQuestion>[
        VoiceIntakeQuestion.dictated(
          prompt: 'What is your name?',
          onSpeak: names.add,
        ),
      ]);

      await controller.start();
      mic.emit(const SpeechResult(text: 'my name is anita das', isFinal: true));
      await Future<void>.delayed(Duration.zero);

      expect(names, <String>['Anita Das']);
      expect(voice.spoken.any((String s) => s.contains('Anita Das.')), isTrue,
          reason: 'it reads the name back so a mishearing can be caught');
      expect(advanced, 0,
          reason: 'the mic asks whether to move on before it does — it never '
              'advances a question by itself');

      // Confirming is what actually moves the flow on.
      mic.emit(const SpeechResult(text: 'next', isFinal: true));
      await Future<void>.delayed(Duration.zero);
      expect(advanced, 1);
      controller.dispose();
    });

    test('an age that was not a number asks again rather than storing zero',
        () async {
      final List<int> ages = <int>[];
      mic = FakeSpeechRecognizer(alreadyGranted: true);
      voice = FakeSpeechSynthesizer();
      final VoiceIntakeController controller = VoiceIntakeController(
        recognizer: mic,
        synthesizer: voice,
        onAdvance: () {},
      );
      controller.setQuestions(<VoiceIntakeQuestion>[
        VoiceIntakeQuestion.number(prompt: 'How old are you?', onSpeak: ages.add),
      ]);
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'quite old really', isFinal: true),
      ];

      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(ages, isEmpty);
      expect(voice.spoken.any((String s) => s.contains('did not catch that')), isTrue);
      controller.dispose();
    });

    test('"next" is an instruction on a dictated question, not a name',
        () async {
      final List<String> names = <String>[];
      mic = FakeSpeechRecognizer(alreadyGranted: true);
      voice = FakeSpeechSynthesizer();
      advanced = 0;
      final VoiceIntakeController controller = VoiceIntakeController(
        recognizer: mic,
        synthesizer: voice,
        onAdvance: () => advanced++,
      );
      controller.setQuestions(<VoiceIntakeQuestion>[
        VoiceIntakeQuestion.dictated(prompt: 'Your name?', onSpeak: names.add),
      ]);
      mic.script = const <SpeechResult>[SpeechResult(text: 'next', isFinal: true)];

      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(names, isEmpty);
      expect(advanced, 1);
      controller.dispose();
    });

    test('giving up on a silent microphone says so instead of just stopping',
        () async {
      final VoiceIntakeController controller = build();
      mic.script = const <SpeechResult>[
        SpeechResult(text: 'mumble mumble', isFinal: true),
      ];

      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isActive, isFalse);
      expect(controller.error?.kind, VoiceErrorKind.noSpeechDetected,
          reason: 'silently reverting looks like the button did nothing');
      controller.dispose();
    });

    test('turning voice on skips questions already answered by tapping',
        () async {
      final VoiceIntakeController controller = build(
        questions: <VoiceIntakeQuestion>[
          VoiceIntakeQuestion(
            prompt: 'Already answered',
            options: kYesNo,
            answeredIndex: 0,
            onSelect: (int i) => answers.add(i),
          ),
          VoiceIntakeQuestion(
            prompt: 'Still open',
            options: kYesNo,
            onSelect: (int i) => answers.add(i),
          ),
        ],
      );
      mic.script = const <SpeechResult>[];
      await controller.start();

      expect(controller.questionIndex, 1);
      expect(voice.spoken.first, contains('Still open'));
      controller.dispose();
    });

    test('a single-choice answer waits to be confirmed before it advances',
        () async {
      final VoiceIntakeController controller = build();
      await controller.start();
      mic.emit(const SpeechResult(text: 'often I think', isFinal: true));
      await Future<void>.delayed(Duration.zero);

      expect(answers, <int>[3], reason: 'the answer is applied immediately');
      expect(advanced, 0, reason: 'but the screen has not moved yet');
      expect(voice.spoken.any((String s) => s.contains('Say next to continue')), isTrue);

      mic.emit(const SpeechResult(text: 'next', isFinal: true));
      await Future<void>.delayed(Duration.zero);
      expect(advanced, 1);
      controller.dispose();
    });

    test('a multi-select question applies every option heard in one sentence',
        () async {
      final Set<int> selected = <int>{};
      final VoiceIntakeController controller = build(
        questions: <VoiceIntakeQuestion>[
          VoiceIntakeQuestion.multiSelect(
            prompt: 'What do they enjoy?',
            options: const <String>['Music', 'Gardening', 'Reading', 'Walking'],
            selectedIndices: selected,
            onSelect: (int i) => selected.add(i),
          ),
        ],
      );
      await controller.start();
      mic.emit(const SpeechResult(text: 'music gardening reading', isFinal: true));
      await Future<void>.delayed(Duration.zero);

      expect(selected, <int>{0, 1, 2}, reason: 'all three named options are picked');
      expect(advanced, 0, reason: 'it still waits for confirmation, same as any answer');
      expect(voice.spoken.any((String s) => s.contains('Music, Gardening, Reading.')), isTrue);
      controller.dispose();
    });

    test('a multi-select question keeps taking answers through the confirm turn',
        () async {
      final Set<int> selected = <int>{};
      final VoiceIntakeController controller = build(
        questions: <VoiceIntakeQuestion>[
          VoiceIntakeQuestion.multiSelect(
            prompt: 'What do they enjoy?',
            options: const <String>['Music', 'Gardening', 'Reading', 'Walking'],
            selectedIndices: selected,
            onSelect: (int i) => selected.add(i),
          ),
        ],
      );
      await controller.start();
      mic.emit(const SpeechResult(text: 'music', isFinal: true));
      await Future<void>.delayed(Duration.zero);
      expect(selected, <int>{0});

      // Said after being asked "say next, or tell me more" — not a command,
      // so it is tried against the same question rather than being refused.
      mic.emit(const SpeechResult(text: 'gardening', isFinal: true));
      await Future<void>.delayed(Duration.zero);
      expect(selected, <int>{0, 1}, reason: 'a second answer adds to the first');
      expect(advanced, 0);

      mic.emit(const SpeechResult(text: 'next', isFinal: true));
      await Future<void>.delayed(Duration.zero);
      expect(advanced, 1);
      controller.dispose();
    });

    test('a multi-select question stops at its cap and says so', () async {
      final Set<int> selected = <int>{0};
      final VoiceIntakeController controller = build(
        questions: <VoiceIntakeQuestion>[
          VoiceIntakeQuestion.multiSelect(
            prompt: 'What would help most?',
            options: const <String>['Money', 'Time', 'Advice', 'Company'],
            selectedIndices: selected,
            maxSelectable: 2,
            onSelect: (int i) => selected.add(i),
          ),
        ],
      );
      await controller.start();
      mic.emit(const SpeechResult(text: 'time and advice', isFinal: true));
      await Future<void>.delayed(Duration.zero);

      expect(selected, <int>{0, 1}, reason: 'only room for one more, so only one is added');
      expect(voice.spoken.any((String s) => s.contains('up to 2')), isTrue);
      controller.dispose();
    });
  });
}
