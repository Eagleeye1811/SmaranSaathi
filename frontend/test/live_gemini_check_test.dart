import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/core/ai/ai_config.dart';
import 'package:memory_mitra/core/ai/ai_context_builder.dart';
import 'package:memory_mitra/core/ai/ai_models.dart';
import 'package:memory_mitra/core/ai/gemini_ai_service.dart';
import 'package:memory_mitra/core/models/memory_fragment.dart';
import 'package:memory_mitra/core/services/app_state.dart';

/// A real round trip to Gemini through the app's actual [GeminiAiService] —
/// not a mock transport. Verifies the currently-configured model name is
/// live and that a real reply parses cleanly end to end.
///
/// Reads the key from `GEMINI_API_KEY` in the environment
/// (`flutter test --dart-define=GEMINI_API_KEY=... test/live_gemini_check_test.dart`);
/// skipped, not failed, if it's absent — this is a deliberate manual
/// diagnostic, not part of the regular `flutter test` suite's guarantees.
void main() {
  const String key = String.fromEnvironment('GEMINI_API_KEY');

  test('a real reply from the configured model parses cleanly', () async {
    if (key.isEmpty) {
      // ignore: avoid_print
      print('live_gemini_check_test: no GEMINI_API_KEY, skipping.');
      return;
    }

    // The widgets test binding fakes every HTTP request; undo that so this
    // one specific test reaches the real network.
    HttpOverrides.global = null;

    final AppState state = AppState();
    final GeminiAiService service = GeminiAiService(config: const AiConfig(apiKey: key));

    // ignore: avoid_print
    print('model under test: ${service.config.model}');

    final AiResult<AssistantReply> hi = await service.ask('hi', state.aiContext());
    // ignore: avoid_print
    print('--- hi --- success=${hi.isSuccess} '
        'text="${hi.valueOrNull?.text}" intent=${hi.valueOrNull?.intent} '
        'failure=${hi.failureOrNull}');
    expect(hi.isSuccess, isTrue, reason: 'model: ${service.config.model}');

    final AiResult<AssistantReply> shared = await service.ask(
      'I used to walk to school through a bamboo grove with my sister Ima, '
      'we would laugh the whole way',
      state.aiContext(),
    );
    // ignore: avoid_print
    print('--- shared memory --- success=${shared.isSuccess} '
        'text="${shared.valueOrNull?.text}" '
        'sharedMemory.category=${shared.valueOrNull?.sharedMemory?.category} '
        'sharedMemory.summary="${shared.valueOrNull?.sharedMemory?.summary}" '
        'failure=${shared.failureOrNull}');
    expect(shared.isSuccess, isTrue);
    expect(shared.valueOrNull?.sharedMemory, isNotNull,
        reason: 'a real, specific memory should be captured, not just answered');

    service.dispose();
    state.dispose();
  });

  test('a memory persisted in an earlier session is recognised in a later one',
      () async {
    if (key.isEmpty) {
      // ignore: avoid_print
      print('live_gemini_check_test: no GEMINI_API_KEY, skipping.');
      return;
    }

    HttpOverrides.global = null;

    // "Session 1": a story gets shared and actually persisted through
    // AppState — the real repository path, not a hand-built context.
    final AppState state = AppState();
    await state.saveSharedMemory(const SharedMemory(
      category: MemoryCategory.childhood,
      summary: 'Walking to school through a bamboo grove with sister Ima.',
      mentionedName: 'Ima',
    ));

    // "Session 2": a fresh ask() with no mention of the story in this turn's
    // own text — the only way the model can know is knownMemories.
    final GeminiAiService service = GeminiAiService(config: const AiConfig(apiKey: key));
    final AiResult<AssistantReply> reply = await service.ask(
      'Did I ever tell you about my sister?',
      state.aiContext(replyLanguage: 'en'),
    );
    // ignore: avoid_print
    print('--- recognises past memory --- success=${reply.isSuccess} '
        'text="${reply.valueOrNull?.text}" failure=${reply.failureOrNull}');
    expect(reply.isSuccess, isTrue);
    expect(reply.valueOrNull!.text.toLowerCase(), contains('ima'),
        reason: 'the earlier bamboo-grove/Ima story should actually be recalled, '
            'not just today\'s single resurface candidate');

    service.dispose();
    state.dispose();
  });
}
