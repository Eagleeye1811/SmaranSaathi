import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/core/ai/ai_config.dart';
import 'package:memory_mitra/core/ai/ai_context.dart';
import 'package:memory_mitra/core/ai/ai_context_builder.dart';
import 'package:memory_mitra/core/ai/ai_controller.dart';
import 'package:memory_mitra/core/ai/ai_models.dart';
import 'package:memory_mitra/core/ai/ai_transport.dart';
import 'package:memory_mitra/core/ai/gemini_ai_service.dart';
import 'package:memory_mitra/core/ai/on_device_ai_service.dart';
import 'package:memory_mitra/core/ai/resilient_ai_service.dart';
import 'package:memory_mitra/core/models/daily.dart';
import 'package:memory_mitra/core/models/game.dart';
import 'package:memory_mitra/core/models/memory_fragment.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/core/services/connectivity_service.dart';

/// A fixed clock, so prompts and expectations are reproducible.
final DateTime kNow = DateTime(2026, 3, 14, 9, 30);

const AiConfig kConfigured = AiConfig(apiKey: 'test-key-not-a-real-secret');

PatientAiContext contextFrom(AppState state) => state.aiContext(now: kNow);

/// Wraps a model answer in Gemini's response envelope.
String geminiEnvelope(Map<String, dynamic> answer) => jsonEncode(<String, dynamic>{
      'candidates': <Map<String, dynamic>>[
        <String, dynamic>{
          'finishReason': 'STOP',
          'content': <String, dynamic>{
            'parts': <Map<String, String>>[
              <String, String>{'text': jsonEncode(answer)},
            ],
          },
        },
      ],
    });

const Map<String, dynamic> kValidInsight = <String, dynamic>{
  'summary': 'Aama has been steady over the last two weeks.',
  'strengths': <String>['Procedural work is strong'],
  'attentionAreas': <String>['Auditory sequences are slipping'],
  'recommendedActivity': 'melody',
  'recommendedDifficulty': 2,
  'reason': 'Melody exercises the domain that has slipped most.',
  'evidence': <String>['Average accuracy 78%', 'Melody not played in 9 days'],
};

const Map<String, dynamic> kValidReply = <String, dynamic>{
  'text': 'You have your evening medicine at 8:00 PM.',
  'intent': 'reminders',
  'followUps': <String>['What activity should I do?'],
};

GeminiAiService geminiReturning(String body, {AiConfig config = kConfigured}) =>
    GeminiAiService(
      config: config,
      transport: FakeAiTransport((_) async => AiSuccess<String>(body)),
    );

GeminiAiService geminiFailing(AiErrorKind kind, {AiConfig config = kConfigured}) =>
    GeminiAiService(
      config: config,
      transport: FakeAiTransport((_) async => AiError<String>.of(kind)),
    );

void main() {
  // ─────────────────────────────────────────────────────────────────────
  group('AiConfig', () {
    test('is unconfigured by default, so no build accidentally calls out', () {
      const AiConfig config = AiConfig();
      expect(config.isConfigured, isFalse);
      expect(config.usesProxy, isFalse);
    });

    test('a key is sent as a header, never in the URL', () {
      const AiConfig config = AiConfig(apiKey: 'secret');
      expect(config.endpoint().toString(), isNot(contains('secret')));
      expect(config.endpoint().query, isEmpty);
      expect(config.headers()['x-goog-api-key'], 'secret');
    });

    test('a proxy URL takes over and stops the key being sent at all', () {
      const AiConfig config =
          AiConfig(apiKey: 'secret', proxyUrl: 'https://api.example.org/ai');
      expect(config.usesProxy, isTrue);
      expect(config.endpoint().toString(), 'https://api.example.org/ai');
      expect(config.headers().containsKey('x-goog-api-key'), isFalse,
          reason: 'the backend holds the key; the device must not send one');
    });

    test('reads nothing from the environment in a plain test build', () {
      expect(AiConfig.fromEnvironment().isConfigured, isFalse);
    });

    // dotenv is a process-wide singleton with no "uninitialize" — this must
    // stay the last AiConfig test in the file so the one above still sees an
    // unloaded dotenv.
    test('falls back to .env when no --dart-define is set — this is what '
        'lets a plain `flutter run` work with no launch script', () {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=from-dotenv\nGEMINI_MODEL=gemini-test-model');
      final AiConfig config = AiConfig.fromEnvironment();
      expect(config.apiKey, 'from-dotenv');
      expect(config.model, 'gemini-test-model');
      expect(config.isConfigured, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('PatientAiContext', () {
    test('derives accuracy, trend and per-activity breakdown from real sessions',
        () {
      final AppState state = AppState();
      final PatientAiContext c = contextFrom(state);

      expect(c.recent(), isNotEmpty, reason: 'seeded history is present');
      expect(c.averageAccuracy(), isNotNull);
      expect(c.averageAccuracy(), inInclusiveRange(0, 100));
      expect(c.accuracyByGame(), isNotEmpty);
      expect(c.adherencePercent, inInclusiveRange(0, 100));
      state.dispose();
    });

    test('the prompt payload carries every signal the task requires', () {
      final AppState state = AppState()..setMood(MoodLevel.good);
      final Map<String, dynamic> json = contextFrom(state).toPromptJson();

      final Map<String, dynamic> performance =
          json['performance'] as Map<String, dynamic>;
      expect(performance['averageAccuracy'], isNotNull);
      expect(performance['accuracyTrend'], isNotNull);
      expect(json['cognitiveDomains'], isNotEmpty);
      expect((json['today'] as Map<String, dynamic>)['mood'], 'good');

      final Map<String, dynamic> session =
          (performance['recentSessions'] as List<dynamic>).first
              as Map<String, dynamic>;
      // Scores, accuracy, mistakes, hints, completion time, difficulty.
      for (final String key in <String>[
        'accuracy', 'mistakes', 'hints', 'seconds', 'level', 'completed', 'expectedSeconds',
      ]) {
        expect(session.containsKey(key), isTrue, reason: 'missing $key');
      }
      state.dispose();
    });

    test('redaction removes identifying detail but keeps the analysis usable', () {
      final AppState state = AppState();
      final PatientAiContext c = contextFrom(state);

      final Map<String, dynamic> open = c.toPromptJson();
      final Map<String, dynamic> shut = c.toPromptJson(redacted: true);
      final Map<String, dynamic> openPatient = open['patient'] as Map<String, dynamic>;
      final Map<String, dynamic> shutPatient = shut['patient'] as Map<String, dynamic>;

      expect(openPatient['name'], state.patient.shortName);
      expect(shutPatient['name'], 'the patient');
      expect(shutPatient.containsKey('family'), isFalse);
      expect(shutPatient.containsKey('location'), isFalse);
      // Still analysable.
      expect(shut['performance'], isNotEmpty);
      expect(shut['cognitiveDomains'], isNotEmpty);
      state.dispose();
    });

    test('carries every past shared memory, not just today\'s resurface candidate',
        () {
      final AppState state = AppState();
      final PatientAiContext c = PatientAiContext(
        patient: state.patient,
        sessions: state.sessions,
        levels: state.levels,
        cognitiveProfile: state.cognitiveProfile,
        reminders: state.reminders,
        now: kNow,
        knownMemories: <MemoryFragment>[
          MemoryFragment(
            id: 'a',
            category: MemoryCategory.childhood,
            summary: 'Bamboo grove walk.',
            mentionedName: 'Ima',
            createdAt: kNow.subtract(const Duration(days: 5)),
          ),
          MemoryFragment(
            id: 'b',
            category: MemoryCategory.festivals,
            summary: 'Bihu dance in the courtyard.',
            createdAt: kNow.subtract(const Duration(days: 1)),
          ),
        ],
      );

      final List<dynamic> shared =
          (c.toPromptJson()['memoryCompanion'] as Map<String, dynamic>)['sharedMemories']
              as List<dynamic>;
      expect(shared, hasLength(2));
      expect(shared[0], containsPair('summary', 'Bamboo grove walk.'));
      expect(shared[0], containsPair('mentionedName', 'Ima'));
      expect(shared[0], containsPair('daysAgo', 5));
      expect(shared[1], containsPair('summary', 'Bihu dance in the courtyard.'));

      // Redaction strips these the same way it strips family.
      final List<dynamic> redactedShared =
          (c.toPromptJson(redacted: true)['memoryCompanion'] as Map<String, dynamic>)
              ['sharedMemories'] as List<dynamic>;
      expect(redactedShared, isEmpty);
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('OnDeviceAiService — insight', () {
    const OnDeviceAiService service = OnDeviceAiService();

    test('produces every required field with no network', () async {
      final AppState state = AppState();
      final AiResult<CognitiveInsight> result =
          await service.cognitiveInsight(contextFrom(state));

      final CognitiveInsight insight = result.valueOrNull!;
      expect(insight.summary, isNotEmpty);
      expect(insight.strengths, isNotEmpty);
      expect(insight.attentionAreas, isNotEmpty);
      expect(insight.recommendedDifficulty, inInclusiveRange(1, 5));
      expect(insight.reason, isNotEmpty);
      expect(insight.evidence, isNotEmpty, reason: 'the explainable part');
      expect(insight.source, AiSource.onDevice);
      state.dispose();
    });

    test('does not recommend what was just played or already done today', () async {
      final AppState state = AppState();
      state.finishGame(
        GameId.procedure,
        const GamePerformance(
          accuracy: 90, focus: 88, memory: 86,
          hintsUsed: 0, mistakes: 1, seconds: 40, completed: true,
        ),
      );

      final CognitiveInsight insight =
          (await service.cognitiveInsight(contextFrom(state))).valueOrNull!;
      expect(insight.recommendedActivity, isNot(GameId.procedure));
      state.dispose();
    });

    test('says so plainly when there is no history to analyse', () async {
      final AppState state = AppState();
      final PatientAiContext bare = PatientAiContext(
        patient: state.patient,
        sessions: const <GameSession>[],
        levels: state.levels,
        cognitiveProfile: state.cognitiveProfile,
        reminders: state.reminders,
        now: kNow,
      );

      final CognitiveInsight insight =
          (await service.cognitiveInsight(bare)).valueOrNull!;
      expect(insight.summary.toLowerCase(), contains('not played'));
      expect(insight.strengths, isNotEmpty, reason: 'never leave a caregiver blank');
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('OnDeviceAiService — memory assistant', () {
    const OnDeviceAiService service = OnDeviceAiService();

    test('"What do I have today?" answers from real reminders', () async {
      final AppState state = AppState();
      final AssistantReply reply =
          (await service.ask('What do I have today?', contextFrom(state))).valueOrNull!;

      expect(reply.intent, AssistantIntent.schedule);
      expect(reply.text, isNotEmpty);
      expect(reply.followUps, isNotEmpty);
      state.dispose();
    });

    test('"What activity should I do?" suggests something startable', () async {
      final AppState state = AppState();
      final AssistantReply reply =
          (await service.ask('What activity should I do?', contextFrom(state)))
              .valueOrNull!;

      expect(reply.intent, AssistantIntent.activity);
      expect(reply.suggestedActivity, isNotNull);
      state.dispose();
    });

    test('"What are my reminders?" names a real one and tracks completion',
        () async {
      final AppState state = AppState();
      final Reminder due = state.reminders.firstWhere((Reminder r) => !r.done);

      AssistantReply reply =
          (await service.ask('What are my reminders?', contextFrom(state))).valueOrNull!;
      expect(reply.intent, AssistantIntent.reminders);
      expect(reply.text.toLowerCase(), contains(due.title.toLowerCase()));

      // Tick everything off; the answer must change accordingly.
      for (final Reminder r in state.reminders.where((Reminder r) => !r.done).toList()) {
        state.toggleReminder(r.id);
      }
      reply = (await service.ask('What are my reminders?', contextFrom(state)))
          .valueOrNull!;
      expect(reply.text.toLowerCase(), contains('nothing is waiting'));
      state.dispose();
    });

    test('answers about family only from the profile', () async {
      final AppState state = AppState();
      final String name = state.patient.family.first.name;

      final AssistantReply reply =
          (await service.ask('Who is $name?', contextFrom(state))).valueOrNull!;
      expect(reply.intent, AssistantIntent.people);
      expect(reply.text, contains(name));
      state.dispose();
    });

    test('is not a general chatbot — out-of-scope questions are redirected',
        () async {
      final AppState state = AppState();
      for (final String question in <String>[
        'What is the capital of France?',
        'Write me a poem about the monsoon',
        'Who won the cricket match',
      ]) {
        final AssistantReply reply =
            (await service.ask(question, contextFrom(state))).valueOrNull!;
        expect(reply.intent, AssistantIntent.outOfScope, reason: question);
        expect(reply.text.toLowerCase(), contains('not sure'));
        expect(reply.followUps, isNotEmpty,
            reason: 'a redirect must offer somewhere to go');
      }
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('GeminiAiService — parsing', () {
    test('parses a well-formed insight out of the response envelope', () async {
      final AppState state = AppState();
      final GeminiAiService service = geminiReturning(geminiEnvelope(kValidInsight));

      final CognitiveInsight insight =
          (await service.cognitiveInsight(contextFrom(state))).valueOrNull!;
      expect(insight.summary, kValidInsight['summary']);
      expect(insight.recommendedActivity, GameId.melody);
      expect(insight.recommendedDifficulty, 2);
      expect(insight.source, AiSource.gemini);
      expect(insight.evidence, hasLength(2));
      state.dispose();
    });

    test('parses an assistant reply and its intent', () async {
      final AppState state = AppState();
      final GeminiAiService service = geminiReturning(geminiEnvelope(kValidReply));

      final AssistantReply reply =
          (await service.ask('What are my reminders?', contextFrom(state))).valueOrNull!;
      expect(reply.text, kValidReply['text']);
      expect(reply.intent, AssistantIntent.reminders);
      expect(reply.source, AiSource.gemini);
      state.dispose();
    });

    test('tolerates a fenced code block around the JSON', () async {
      final AppState state = AppState();
      final String fenced = jsonEncode(<String, dynamic>{
        'candidates': <Map<String, dynamic>>[
          <String, dynamic>{
            'content': <String, dynamic>{
              'parts': <Map<String, String>>[
                <String, String>{'text': '```json\n${jsonEncode(kValidInsight)}\n```'},
              ],
            },
          },
        ],
      });

      final AiResult<CognitiveInsight> result =
          await geminiReturning(fenced).cognitiveInsight(contextFrom(state));
      expect(result.isSuccess, isTrue);
      state.dispose();
    });

    test('accepts a bare object, so the FastAPI proxy can answer directly',
        () async {
      final AppState state = AppState();
      final GeminiAiService service = geminiReturning(
        jsonEncode(kValidInsight),
        config: const AiConfig(proxyUrl: 'https://api.example.org/ai'),
      );

      final AiResult<CognitiveInsight> result =
          await service.cognitiveInsight(contextFrom(state));
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.recommendedActivity, GameId.melody);
      state.dispose();
    });

    test('clamps a difficulty the model invented outside the real scale',
        () async {
      final AppState state = AppState();
      final Map<String, dynamic> silly =
          Map<String, dynamic>.from(kValidInsight)..['recommendedDifficulty'] = 97;

      final CognitiveInsight insight =
          (await geminiReturning(geminiEnvelope(silly)).cognitiveInsight(contextFrom(state)))
              .valueOrNull!;
      expect(insight.recommendedDifficulty, 5);
      state.dispose();
    });

    test('the prompt actually carries the patient data', () async {
      final AppState state = AppState();
      final FakeAiTransport transport =
          FakeAiTransport((_) async => AiSuccess<String>(geminiEnvelope(kValidInsight)));
      await GeminiAiService(config: kConfigured, transport: transport)
          .cognitiveInsight(contextFrom(state));

      expect(transport.requests, hasLength(1));
      final String sent = transport.requests.single;
      expect(sent, contains('recommendedActivity'), reason: 'the schema instruction');
      expect(sent, contains('averageAccuracy'), reason: 'the performance data');
      expect(sent.toLowerCase(), contains('never diagnose'),
          reason: 'the safety instruction travels with every request');
      state.dispose();
    });

    test('a conversational ask() request carries every past shared memory, '
        'not just the resurface candidate', () async {
      final AppState state = AppState();
      final FakeAiTransport transport =
          FakeAiTransport((_) async => AiSuccess<String>(geminiEnvelope(kValidReply)));
      final PatientAiContext withMemories = PatientAiContext(
        patient: state.patient,
        sessions: state.sessions,
        levels: state.levels,
        cognitiveProfile: state.cognitiveProfile,
        reminders: state.reminders,
        now: kNow,
        knownMemories: <MemoryFragment>[
          MemoryFragment(
            id: 'x',
            category: MemoryCategory.childhood,
            summary: 'Bamboo grove walk with Ima.',
            createdAt: kNow.subtract(const Duration(days: 5)),
          ),
        ],
      );

      await GeminiAiService(config: kConfigured, transport: transport)
          .ask('hello', withMemories);

      expect(transport.requests, hasLength(1));
      expect(transport.requests.single, contains('Bamboo grove walk with Ima.'),
          reason: 'the model cannot recognise a story it was never shown');
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('GeminiAiService — error handling', () {
    test('reports a build with no key rather than calling out', () async {
      final AppState state = AppState();
      final AiResult<CognitiveInsight> result =
          await GeminiAiService(config: const AiConfig()).cognitiveInsight(contextFrom(state));

      expect(result.failureOrNull!.kind, AiErrorKind.notConfigured);
      expect(result.failureOrNull!.isRetryable, isFalse);
      state.dispose();
    });

    test('maps transport failures through unchanged', () async {
      final AppState state = AppState();
      for (final AiErrorKind kind in <AiErrorKind>[
        AiErrorKind.timeout,
        AiErrorKind.offline,
        AiErrorKind.rateLimited,
        AiErrorKind.server,
        AiErrorKind.unauthorized,
        AiErrorKind.unsupportedPlatform,
      ]) {
        final AiResult<CognitiveInsight> result =
            await geminiFailing(kind).cognitiveInsight(contextFrom(state));
        expect(result.failureOrNull!.kind, kind);
        expect(result.failureOrNull!.message, isNotEmpty,
            reason: 'every failure needs caregiver-facing wording');
      }
      state.dispose();
    });

    test('an empty candidate list is reported as empty, not as success', () async {
      final AppState state = AppState();
      final AiResult<CognitiveInsight> result = await geminiReturning(
        jsonEncode(<String, dynamic>{'candidates': <dynamic>[]}),
      ).cognitiveInsight(contextFrom(state));

      expect(result.failureOrNull!.kind, AiErrorKind.empty);
      state.dispose();
    });

    test('non-JSON and wrong-shape replies are malformed, never rendered',
        () async {
      final AppState state = AppState();

      final AiResult<CognitiveInsight> notJson =
          await geminiReturning('<html>502 Bad Gateway</html>')
              .cognitiveInsight(contextFrom(state));
      expect(notJson.failureOrNull!.kind, AiErrorKind.malformed);

      final AiResult<CognitiveInsight> wrongShape = await geminiReturning(
        geminiEnvelope(<String, dynamic>{'summary': 'ok', 'recommendedActivity': 'chess'}),
      ).cognitiveInsight(contextFrom(state));
      expect(wrongShape.failureOrNull!.kind, AiErrorKind.malformed);
      state.dispose();
    });

    test('a safety block is distinguished from a server error', () async {
      final AppState state = AppState();

      final AiResult<AssistantReply> blocked = await geminiReturning(
        jsonEncode(<String, dynamic>{
          'promptFeedback': <String, dynamic>{'blockReason': 'SAFETY'},
        }),
      ).ask('anything', contextFrom(state));
      expect(blocked.failureOrNull!.kind, AiErrorKind.blocked);
      expect(blocked.failureOrNull!.isRetryable, isFalse);
      state.dispose();
    });

    test('a provider error object maps to the right kind', () async {
      final AppState state = AppState();
      final AiResult<CognitiveInsight> result = await geminiReturning(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 429, 'status': 'RESOURCE_EXHAUSTED', 'message': 'quota',
          },
        }),
      ).cognitiveInsight(contextFrom(state));

      expect(result.failureOrNull!.kind, AiErrorKind.rateLimited);
      state.dispose();
    });

    test('a blank question is rejected without a round trip', () async {
      final AppState state = AppState();
      final FakeAiTransport transport =
          FakeAiTransport((_) async => AiSuccess<String>(geminiEnvelope(kValidReply)));
      final AiResult<AssistantReply> result =
          await GeminiAiService(config: kConfigured, transport: transport)
              .ask('   ', contextFrom(state));

      expect(result.failureOrNull!.kind, AiErrorKind.empty);
      expect(transport.requests, isEmpty, reason: 'no wasted call');
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('ResilientAiService', () {
    test('does not attempt a call while offline, and still answers', () async {
      final AppState state = AppState();
      final FakeAiTransport transport =
          FakeAiTransport((_) async => AiSuccess<String>(geminiEnvelope(kValidInsight)));
      final ResilientAiService service = ResilientAiService(
        remote: GeminiAiService(config: kConfigured, transport: transport),
        connectivity: ManualConnectivityService(online: false),
      );

      final AiResult<CognitiveInsight> result =
          await service.cognitiveInsight(contextFrom(state));

      expect(result.isSuccess, isTrue, reason: 'offline is not an error state here');
      expect(result.valueOrNull!.source, AiSource.onDevice);
      expect(transport.requests, isEmpty, reason: 'no doomed request');
      expect(service.lastFailure!.kind, AiErrorKind.offline);
      state.dispose();
    });

    test('uses the model when online and configured', () async {
      final AppState state = AppState();
      final ResilientAiService service = ResilientAiService(
        remote: geminiReturning(geminiEnvelope(kValidInsight)),
        connectivity: ManualConnectivityService(),
      );

      final AiResult<CognitiveInsight> result =
          await service.cognitiveInsight(contextFrom(state));
      expect(result.valueOrNull!.source, AiSource.gemini);
      expect(service.lastFailure, isNull);
      state.dispose();
    });

    test('every remote failure degrades to an on-device answer', () async {
      final AppState state = AppState();
      for (final AiErrorKind kind in AiErrorKind.values) {
        final ResilientAiService service = ResilientAiService(
          remote: geminiFailing(kind),
          connectivity: ManualConnectivityService(),
        );

        final AiResult<CognitiveInsight> insight =
            await service.cognitiveInsight(contextFrom(state));
        expect(insight.isSuccess, isTrue, reason: 'must not surface ${kind.name}');
        expect(insight.valueOrNull!.source, AiSource.onDevice);
        expect(service.lastFailure!.kind, kind, reason: 'but must report it honestly');

        final AiResult<AssistantReply> reply =
            await service.ask('What do I have today?', contextFrom(state));
        expect(reply.isSuccess, isTrue);
        expect(reply.valueOrNull!.source, AiSource.onDevice);
      }
      state.dispose();
    });

    test('an unconfigured build quietly uses the device, without an error', () async {
      final AppState state = AppState();
      final ResilientAiService service = ResilientAiService(
        remote: GeminiAiService(config: const AiConfig()),
        connectivity: ManualConnectivityService(),
      );

      expect(service.isAvailable, isFalse);
      final AiResult<AssistantReply> reply =
          await service.ask('What are my reminders?', contextFrom(state));
      expect(reply.isSuccess, isTrue);
      expect(service.lastFailure!.kind, AiErrorKind.notConfigured);
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('AiRequestController', () {
    test('moves idle → loading → ready and notifies', () async {
      final AppState state = AppState();
      final AiRequestController<CognitiveInsight> controller = AiControllers.insight(
        ResilientAiService(
          remote: geminiReturning(geminiEnvelope(kValidInsight)),
          connectivity: ManualConnectivityService(),
        ),
      );

      final List<AiPhase> phases = <AiPhase>[];
      controller.addListener(() => phases.add(controller.phase));

      expect(controller.phase, AiPhase.idle);
      await controller.run(contextFrom(state));

      expect(phases, <AiPhase>[AiPhase.loading, AiPhase.ready]);
      expect(controller.value, isNotNull);
      expect(controller.isLoading, isFalse);
      controller.dispose();
      state.dispose();
    });

    test('exposes a failure phase when the service really does fail', () async {
      final AppState state = AppState();
      final AiRequestController<CognitiveInsight> controller =
          AiControllers.insight(geminiFailing(AiErrorKind.timeout));

      await controller.run(contextFrom(state));
      expect(controller.phase, AiPhase.failed);
      expect(controller.failure!.kind, AiErrorKind.timeout);
      expect(controller.failure!.isRetryable, isTrue);
      controller.dispose();
      state.dispose();
    });

    test('a slow first call cannot overwrite a newer answer', () async {
      final AppState state = AppState();
      int call = 0;
      final AiRequestController<CognitiveInsight> controller =
          AiRequestController<CognitiveInsight>((PatientAiContext c) async {
        final int mine = ++call;
        // The first call takes longer than the second.
        await Future<void>.delayed(Duration(milliseconds: mine == 1 ? 60 : 5));
        return AiSuccess<CognitiveInsight>(CognitiveInsight(
          summary: 'call $mine',
          strengths: const <String>[],
          attentionAreas: const <String>[],
          recommendedActivity: GameId.melody,
          recommendedDifficulty: 1,
          reason: '',
          evidence: const <String>[],
          source: AiSource.onDevice,
          generatedAt: kNow,
        ));
      });

      final Future<void> stale = controller.run(contextFrom(state));
      final Future<void> fresh = controller.run(contextFrom(state));
      await Future.wait(<Future<void>>[stale, fresh]);

      expect(controller.value!.summary, 'call 2',
          reason: 'the superseded response must be discarded');
      controller.dispose();
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('OnDeviceAiService.classify — regression', () {
    test('a bare "hi" is recognised as companionship, not out-of-scope', () {
      // Once matched via a bare `.contains('hi ')`, which a plain "hi" with
      // no trailing character could never satisfy.
      expect(OnDeviceAiService.classify('hi'), AssistantIntent.companionship);
      expect(OnDeviceAiService.classify('Hi!'), AssistantIntent.companionship);
      expect(OnDeviceAiService.classify('hi,'), AssistantIntent.companionship);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('AppState — memory companion', () {
    test('a shared memory is persisted and furnishes its room', () async {
      final AppState state = AppState();
      expect(state.memoryFragments, isEmpty);
      expect(state.memoriesByCategory[MemoryCategory.childhood], 0);

      final MemoryFragment saved = await state.saveSharedMemory(const SharedMemory(
        category: MemoryCategory.childhood,
        summary: 'Walking to school through a bamboo grove.',
        mentionedName: 'Ima',
      ));

      expect(state.memoryFragments, hasLength(1));
      expect(state.memoriesByCategory[MemoryCategory.childhood], 1);
      expect(saved.summary, contains('bamboo grove'));
      expect(saved.mentionedName, 'Ima');
      state.dispose();
    });

    test('the daily budget counts today\'s activity and clamps at zero', () async {
      final AppState state = AppState();
      expect(state.memoryInvitesRemainingToday, 2);

      await state.saveSharedMemory(
          const SharedMemory(category: MemoryCategory.family, summary: 'First story.'));
      expect(state.memoryInvitesRemainingToday, 1);

      await state.saveSharedMemory(
          const SharedMemory(category: MemoryCategory.food, summary: 'Second story.'));
      expect(state.memoryInvitesRemainingToday, 0);
      state.dispose();
    });

    test('a memory created today is never offered back as a resurface candidate',
        () async {
      final AppState state = AppState();
      await state.saveSharedMemory(
          const SharedMemory(category: MemoryCategory.village, summary: 'Fresh story.'));

      // Still today, and the budget is not yet spent, but nothing is old
      // enough to sit for a day before being reoffered.
      expect(state.memoryInvitesRemainingToday, greaterThan(0));
      expect(state.memoryResurfaceCandidate, isNull);
      state.dispose();
    });

    test('resurfacing moves a fragment to the back of the queue', () async {
      final AppState state = AppState();
      final MemoryFragment fragment = await state.saveSharedMemory(
          const SharedMemory(category: MemoryCategory.work, summary: 'Weaving story.'));

      await state.markMemoryResurfaced(fragment.id);
      final MemoryFragment updated =
          state.memoryFragments.firstWhere((MemoryFragment f) => f.id == fragment.id);
      expect(updated.timesResurfaced, 1);
      expect(updated.lastResurfacedAt, isNotNull);
      state.dispose();
    });

    test('aiContext() carries every shared memory, most recent first, not just '
        'the resurface candidate', () async {
      final AppState state = AppState();
      await state.saveSharedMemory(
          const SharedMemory(category: MemoryCategory.childhood, summary: 'First story.'));
      await state.saveSharedMemory(
          const SharedMemory(category: MemoryCategory.festivals, summary: 'Second story.'));

      final PatientAiContext c = state.aiContext();
      expect(c.knownMemories, hasLength(2));
      expect(c.knownMemories.first.summary, 'Second story.',
          reason: 'most recently shared first');
      expect(c.knownMemories.last.summary, 'First story.');
      state.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('GeminiAiService — memory companion parsing', () {
    test('a shared story in the reply is captured as a SharedMemory', () async {
      final AppState state = AppState();
      final GeminiAiService service = geminiReturning(geminiEnvelope(<String, dynamic>{
        'text': 'That sounds like a wonderful walk.',
        'intent': 'memoryMoment',
        'followUps': <String>[],
        'memorySharedCategory': 'childhood',
        'memorySharedSummary': 'Walking to school through a bamboo grove.',
        'memorySharedName': 'Ima',
      }));

      final AssistantReply reply = (await service.ask(
              'I used to walk to school through a bamboo grove with my sister Ima',
              contextFrom(state)))
          .valueOrNull!;

      expect(reply.intent, AssistantIntent.memoryMoment);
      expect(reply.sharedMemory, isNotNull);
      expect(reply.sharedMemory!.category, MemoryCategory.childhood);
      expect(reply.sharedMemory!.summary, contains('bamboo grove'));
      expect(reply.sharedMemory!.mentionedName, 'Ima');
      expect(reply.resurfacedFragmentId, isNull);
      state.dispose();
    });

    test('no memorySharedCategory means no memory was captured', () async {
      final AppState state = AppState();
      final AssistantReply reply =
          (await geminiReturning(geminiEnvelope(kValidReply)).ask(
                  'What are my reminders?', contextFrom(state)))
              .valueOrNull!;
      expect(reply.sharedMemory, isNull);
      state.dispose();
    });

    test('resurfacedMemory ties back to the context\'s own candidate id, never invented',
        () async {
      final AppState state = AppState();
      final MemoryFragment yesterday = MemoryFragment(
        id: 'frag-bihu-1',
        category: MemoryCategory.festivals,
        summary: 'Dancing Bihu in the courtyard as a girl.',
        createdAt: kNow.subtract(const Duration(days: 3)),
      );
      final PatientAiContext withCandidate = PatientAiContext(
        patient: state.patient,
        sessions: state.sessions,
        levels: state.levels,
        cognitiveProfile: state.cognitiveProfile,
        reminders: state.reminders,
        now: kNow,
        memoryInvitesRemainingToday: 2,
        memoryResurfaceCandidate: yesterday,
        totalSharedMemories: 1,
      );

      final AssistantReply reply = (await geminiReturning(geminiEnvelope(<String, dynamic>{
        'text': 'You told me once about dancing Bihu in the courtyard. Tell me again?',
        'intent': 'memoryMoment',
        'followUps': <String>[],
        'resurfacedMemory': true,
      })).ask('hello', withCandidate))
          .valueOrNull!;

      expect(reply.resurfacedFragmentId, 'frag-bihu-1');

      // And when the model does not actually resurface anything this turn,
      // the id is never attached even though a candidate was available.
      final AssistantReply notResurfaced = (await geminiReturning(geminiEnvelope(<String, dynamic>{
        'text': 'It is good to hear from you.',
        'intent': 'companionship',
        'followUps': <String>[],
        'resurfacedMemory': false,
      })).ask('hello', withCandidate))
          .valueOrNull!;
      expect(notResurfaced.resurfacedFragmentId, isNull);
      state.dispose();
    });
  });
}
