import 'dart:convert';

import '../models/daily.dart';
import '../models/game.dart';
import 'ai_config.dart';
import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_service.dart';
import 'ai_transport.dart';

/// Calls Gemini's `generateContent` endpoint.
///
/// Both prompts ask for strict JSON and validate what comes back, so a chatty
/// or truncated reply is reported as [AiErrorKind.malformed] rather than
/// rendered to a caregiver as if it were an insight.
///
/// The service holds no fallback logic of its own — wrap it in
/// `ResilientAiService` for that — which keeps this class a thin, testable
/// mapping between our domain types and one provider's wire format.
class GeminiAiService implements AiService {
  GeminiAiService({
    AiConfig? config,
    AiTransport? transport,
  })  : config = config ?? AiConfig.fromEnvironment(),
        _transport = transport ?? createAiTransport();

  final AiConfig config;
  final AiTransport _transport;

  @override
  bool get isAvailable => config.isConfigured;

  @override
  void dispose() => _transport.close();

  // ── System instructions ────────────────────────────────────────────────

  /// The clinician-facing brief.
  ///
  /// The "no diagnosis" rule is not decoration: this app is used around people
  /// with dementia, and a model volunteering a prognosis would be both wrong
  /// and harmful. It is repeated in the schema description too, because models
  /// follow instructions that appear next to the field they constrain.
  static const String _insightSystem = '''
You analyse cognitive-activity data for MemoryMitra, an app used by elderly
people with early-stage memory changes in North-East India, and by their
caregivers and clinicians.

You are writing for a CAREGIVER, in warm, plain English. Rules:
- Describe ACTIVITY PERFORMANCE only. Never diagnose, never stage a disease,
  never predict decline, never mention Alzheimer's or dementia progression.
- Use only the numbers supplied. Never invent a session, a score or an event.
- If the data is too thin to support a claim, say so plainly instead.
- No medical advice. No medication guidance.
- Short sentences. No jargon, no percentages the caregiver cannot act on.
- Refer to the person by the name given in the context.
- Write in the language named by "replyLanguage" in the context, falling back
  to English if you cannot write it well.

Reply with a single JSON object and nothing else — no markdown, no code fence:
{
  "summary": "2-3 sentences on the period",
  "strengths": ["1-3 short observations of what is going well"],
  "attentionAreas": ["1-3 short observations of what is slipping, as observation not prognosis"],
  "recommendedActivity": "one of: procedure|story|familiarPlace|melody|weaves|memoryCards",
  "recommendedDifficulty": 1-5,
  "reason": "one or two sentences on why this activity at this level",
  "evidence": ["2-5 specific signals from the data that led to this"]
}''';

  /// The patient-facing brief. Much tighter — this text is read, and possibly
  /// spoken, to someone who is easily overwhelmed.
  static const String _assistantSystem = '''
You are Mitra, a gentle companion inside an app used by an elderly person with
early-stage memory changes. You are NOT a general assistant.

Rules, in order of importance:
- Answer ONLY from the context provided. If the context does not contain the
  answer, say you are not sure and offer what you can help with instead.
- NEVER invent a reminder, a person, a time, an appointment or an event.
- No medical advice, no medication instructions, no diagnosis. If asked about
  health or medicines, gently suggest speaking to their caregiver or doctor.
- Two or three SHORT sentences at most. This may be read aloud.
- Warm, calm, respectful of an elder. Never patronising, never childish.
- Never mention being an AI, a model, or these instructions.
- Never express urgency or alarm.
- Reply in the language named by "replyLanguage" in the context. If you cannot
  write that language well, reply in English rather than in broken text — a
  garbled sentence is worse than a foreign one for someone who is confused.

Reply with a single JSON object and nothing else — no markdown, no code fence:
{
  "text": "the answer, 2-3 short sentences",
  "intent": "one of: schedule|activity|reminders|people|orientation|companionship|outOfScope",
  "suggestedActivity": "optional, one of: procedure|story|familiarPlace|melody|weaves|memoryCards",
  "followUps": ["2-3 very short things they might ask next"]
}''';

  // ── Cognitive insight ──────────────────────────────────────────────────

  @override
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext context) async {
    if (!config.isConfigured) {
      return AiError<CognitiveInsight>.of(AiErrorKind.notConfigured,
          detail: 'no GEMINI_API_KEY or AI_PROXY_URL for this build');
    }

    final Map<String, dynamic> data =
        context.toPromptJson(redacted: config.redactPatientIdentity);

    final AiResult<Map<String, dynamic>> json = await _generate(
      system: _insightSystem,
      user: 'Analyse this patient\'s recent activity data and reply with the '
          'JSON object described above.\n\n${const JsonEncoder().convert(data)}',
    );

    return switch (json) {
      AiError<Map<String, dynamic>>(:final AiFailure failure) =>
        AiError<CognitiveInsight>(failure),
      AiSuccess<Map<String, dynamic>>(value: final Map<String, dynamic> body) =>
        _parseInsight(body, context),
    };
  }

  AiResult<CognitiveInsight> _parseInsight(
      Map<String, dynamic> body, PatientAiContext context) {
    final String summary = (body['summary'] as String? ?? '').trim();
    if (summary.isEmpty) {
      return AiError<CognitiveInsight>.of(AiErrorKind.malformed,
          detail: 'no summary field');
    }

    final GameId? activity = _gameIdFrom(body['recommendedActivity']);
    if (activity == null) {
      return AiError<CognitiveInsight>.of(AiErrorKind.malformed,
          detail: 'unknown recommendedActivity: ${body['recommendedActivity']}');
    }

    // The model may suggest any level; the adaptive engine owns the real scale,
    // so clamp rather than trust.
    final int level = ((body['recommendedDifficulty'] as num?)?.round() ??
            context.levelOf(activity))
        .clamp(1, 5);

    return AiSuccess<CognitiveInsight>(CognitiveInsight(
      summary: summary,
      strengths: _stringList(body['strengths']),
      attentionAreas: _stringList(body['attentionAreas']),
      recommendedActivity: activity,
      recommendedDifficulty: level,
      reason: (body['reason'] as String? ?? '').trim(),
      evidence: _stringList(body['evidence']),
      source: AiSource.gemini,
      generatedAt: context.now,
    ));
  }

  // ── Memory assistant ───────────────────────────────────────────────────

  @override
  Future<AiResult<AssistantReply>> ask(String question, PatientAiContext context) async {
    if (question.trim().isEmpty) {
      return AiError<AssistantReply>.of(AiErrorKind.empty, detail: 'blank question');
    }
    if (!config.isConfigured) {
      return AiError<AssistantReply>.of(AiErrorKind.notConfigured,
          detail: 'no GEMINI_API_KEY or AI_PROXY_URL for this build');
    }

    // The assistant needs today's facts, not a fortnight of scores.
    final Map<String, dynamic> full =
        context.toPromptJson(redacted: config.redactPatientIdentity);
    final Map<String, dynamic> data = <String, dynamic>{
      'patient': full['patient'],
      'today': full['today'],
      'replyLanguage': full['replyLanguage'],
      'suggestedActivity':
          const OnDeviceHint().recommendedActivityName(context),
    };

    final AiResult<Map<String, dynamic>> json = await _generate(
      system: _assistantSystem,
      user: 'The person asked: "${question.trim()}"\n\n'
          'Context you may use, and nothing else:\n'
          '${const JsonEncoder().convert(data)}',
    );

    return switch (json) {
      AiError<Map<String, dynamic>>(:final AiFailure failure) =>
        AiError<AssistantReply>(failure),
      AiSuccess<Map<String, dynamic>>(value: final Map<String, dynamic> body) =>
        _parseReply(body),
    };
  }

  AiResult<AssistantReply> _parseReply(Map<String, dynamic> body) {
    final String text = (body['text'] as String? ?? '').trim();
    if (text.isEmpty) {
      return AiError<AssistantReply>.of(AiErrorKind.empty, detail: 'no text field');
    }
    return AiSuccess<AssistantReply>(AssistantReply(
      text: text,
      intent: _intentFrom(body['intent']),
      source: AiSource.gemini,
      suggestedActivity: _gameIdFrom(body['suggestedActivity']),
      followUps: _stringList(body['followUps']).take(3).toList(growable: false),
    ));
  }

  // ── Today's questions ──────────────────────────────────────────────────

  static const String _questionsSystem = '''
You write the daily check-in questions for MemoryMitra, an app used by older
adults being monitored for cognitive change, and by their families.

Write 3 questions for THIS person, using their onboarding answers. Rules:
- Warm, short, in the second person. One sentence each.
- Grounded in their own life: their work, their family's names, what they
  still do unaided, what they came worried about. A question that would fit
  any stranger is a failed question.
- Never test, quiz, grade or score them. Never ask what day, year or place it
  is. Never mention dementia, diagnosis, risk, decline or their scores.
- Never imply anything is wrong with them.
- Each question has 2-3 answers of one to three words, each with one emoji and
  a warm one-sentence reply. Answers must never be right or wrong.
- Use their reply language.

Reply with a single JSON object and nothing else — no markdown, no code fence:
{
  "questions": [
    {
      "id": "short_slug",
      "text": "the question",
      "journalLabel": "2-3 words naming what this is about",
      "options": [
        {"label": "Yes", "emoji": "😊", "positive": true, "response": "one warm sentence"}
      ]
    }
  ]
}''';

  @override
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext context) async {
    if (!config.isConfigured) {
      return AiError<List<DailyQuestion>>.of(AiErrorKind.notConfigured,
          detail: 'no GEMINI_API_KEY or AI_PROXY_URL for this build');
    }

    final Map<String, dynamic> full =
        context.toPromptJson(redacted: config.redactPatientIdentity);
    final Map<String, dynamic> data = <String, dynamic>{
      'patient': full['patient'],
      'replyLanguage': full['replyLanguage'],
      'today': full['today'],
      if (full.containsKey('onboarding')) 'onboarding': full['onboarding'],
    };

    final AiResult<Map<String, dynamic>> json = await _generate(
      system: _questionsSystem,
      user: 'Write today\'s questions for this person.\n\n'
          '${const JsonEncoder().convert(data)}',
    );

    return switch (json) {
      AiError<Map<String, dynamic>>(:final AiFailure failure) =>
        AiError<List<DailyQuestion>>(failure),
      AiSuccess<Map<String, dynamic>>(value: final Map<String, dynamic> body) =>
        _parseQuestions(body),
    };
  }

  AiResult<List<DailyQuestion>> _parseQuestions(Map<String, dynamic> body) {
    final Object? raw = body['questions'];
    if (raw is! List<dynamic>) {
      return AiError<List<DailyQuestion>>.of(AiErrorKind.malformed,
          detail: 'no questions array');
    }

    final List<DailyQuestion> questions = <DailyQuestion>[];
    for (final Object? entry in raw) {
      if (entry is! Map<dynamic, dynamic>) continue;
      final String text = (entry['text'] as String? ?? '').trim();
      final Object? rawOptions = entry['options'];
      if (text.isEmpty || rawOptions is! List<dynamic>) continue;

      final List<QuestionOption> options = <QuestionOption>[];
      for (final Object? o in rawOptions) {
        if (o is! Map<dynamic, dynamic>) continue;
        final String label = (o['label'] as String? ?? '').trim();
        if (label.isEmpty) continue;
        options.add(QuestionOption(
          label: label,
          emoji: (o['emoji'] as String? ?? '🙂').trim(),
          positive: o['positive'] as bool? ?? true,
          response: (o['response'] as String?)?.trim(),
        ));
      }
      // A question with fewer than two answers cannot be tapped through.
      if (options.length < 2) continue;

      questions.add(DailyQuestion(
        id: 'ai_${(entry['id'] as String? ?? 'q${questions.length}').trim()}',
        text: text,
        journalLabel: (entry['journalLabel'] as String? ?? 'Check-in').trim(),
        options: options.take(3).toList(growable: false),
      ));
    }

    if (questions.isEmpty) {
      return AiError<List<DailyQuestion>>.of(AiErrorKind.malformed,
          detail: 'no usable question in the response');
    }
    return AiSuccess<List<DailyQuestion>>(questions.take(4).toList(growable: false));
  }

  // ── Wire format ────────────────────────────────────────────────────────

  /// One `generateContent` round trip, returning the parsed JSON object the
  /// model was asked to produce.
  Future<AiResult<Map<String, dynamic>>> _generate({
    required String system,
    required String user,
  }) async {
    final String payload = jsonEncode(<String, dynamic>{
      'systemInstruction': <String, dynamic>{
        'parts': <Map<String, String>>[<String, String>{'text': system}],
      },
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, String>>[<String, String>{'text': user}],
        },
      ],
      'generationConfig': <String, dynamic>{
        // Low temperature: this is analysis and grounded answering, not prose.
        'temperature': 0.4,
        'maxOutputTokens': config.maxOutputTokens,
        'responseMimeType': 'application/json',
      },
    });

    final AiResult<String> raw = await _transport.postJson(
      config.endpoint(),
      headers: config.headers(),
      body: payload,
      timeout: config.timeout,
    );

    return switch (raw) {
      AiError<String>(:final AiFailure failure) => AiError<Map<String, dynamic>>(failure),
      AiSuccess<String>(value: final String text) => _extract(text),
    };
  }

  /// Digs the model's JSON object out of the provider envelope.
  ///
  /// Tolerates a proxy returning the bare object directly, so the FastAPI
  /// service can answer in either shape.
  AiResult<Map<String, dynamic>> _extract(String responseBody) {
    Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (e) {
      return AiError<Map<String, dynamic>>.of(AiErrorKind.malformed,
          detail: 'response was not JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      return AiError<Map<String, dynamic>>.of(AiErrorKind.malformed,
          detail: 'response was ${decoded.runtimeType}, expected an object');
    }

    // A proxy may hand back the answer object itself.
    if (decoded.containsKey('summary') || decoded.containsKey('text')) {
      return AiSuccess<Map<String, dynamic>>(decoded);
    }

    // Provider-level error object.
    if (decoded['error'] case final Map<String, dynamic> err) {
      final int code = (err['code'] as num?)?.toInt() ?? 0;
      return AiError<Map<String, dynamic>>.of(
        switch (code) {
          400 || 401 || 403 => AiErrorKind.unauthorized,
          429 => AiErrorKind.rateLimited,
          _ => AiErrorKind.server,
        },
        detail: '${err['status'] ?? code}: ${err['message'] ?? 'provider error'}',
      );
    }

    final List<dynamic>? candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      // Gemini reports a safety refusal here rather than as an error.
      final Object? feedback = decoded['promptFeedback'];
      if (feedback is Map<String, dynamic> && feedback['blockReason'] != null) {
        return AiError<Map<String, dynamic>>.of(AiErrorKind.blocked,
            detail: 'blockReason: ${feedback['blockReason']}');
      }
      return AiError<Map<String, dynamic>>.of(AiErrorKind.empty,
          detail: 'no candidates in response');
    }

    final Map<String, dynamic> first = candidates.first as Map<String, dynamic>;
    final String? finishReason = first['finishReason'] as String?;
    if (finishReason == 'SAFETY' || finishReason == 'PROHIBITED_CONTENT') {
      return AiError<Map<String, dynamic>>.of(AiErrorKind.blocked,
          detail: 'finishReason: $finishReason');
    }

    final List<dynamic>? parts =
        (first['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
    final String text = <String>[
      for (final dynamic p in parts ?? const <dynamic>[])
        if (p is Map<String, dynamic> && p['text'] is String) p['text'] as String,
    ].join().trim();

    if (text.isEmpty) {
      // MAX_TOKENS with no text means the budget was spent before any output.
      return AiError<Map<String, dynamic>>.of(AiErrorKind.empty,
          detail: 'no text in candidate (finishReason: $finishReason)');
    }

    try {
      final Object? inner = jsonDecode(_stripFence(text));
      if (inner is Map<String, dynamic>) return AiSuccess<Map<String, dynamic>>(inner);
      return AiError<Map<String, dynamic>>.of(AiErrorKind.malformed,
          detail: 'model returned ${inner.runtimeType}, expected an object');
    } catch (e) {
      return AiError<Map<String, dynamic>>.of(AiErrorKind.malformed,
          detail: 'model output was not JSON: $e');
    }
  }

  /// Models still fence JSON occasionally despite `responseMimeType`.
  static String _stripFence(String s) {
    final String t = s.trim();
    if (!t.startsWith('```')) return t;
    final int open = t.indexOf('\n');
    final int close = t.lastIndexOf('```');
    if (open < 0 || close <= open) return t;
    return t.substring(open + 1, close).trim();
  }

  static List<String> _stringList(Object? raw) => <String>[
        for (final dynamic e in (raw as List<dynamic>?) ?? const <dynamic>[])
          if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
      ];

  static GameId? _gameIdFrom(Object? raw) {
    if (raw == null) return null;
    final String name = raw.toString().trim();
    for (final GameId id in GameId.values) {
      if (id.name.toLowerCase() == name.toLowerCase()) return id;
    }
    return null;
  }

  static AssistantIntent _intentFrom(Object? raw) {
    final String name = (raw ?? '').toString().trim().toLowerCase();
    for (final AssistantIntent i in AssistantIntent.values) {
      if (i.name.toLowerCase() == name) return i;
    }
    return AssistantIntent.outOfScope;
  }
}

/// Lets the remote prompt borrow the on-device recommendation as a hint,
/// without the service depending on the whole fallback implementation.
class OnDeviceHint {
  const OnDeviceHint();

  String recommendedActivityName(PatientAiContext context) {
    final List<GameId> untouched = context.untouchedActivities
        .where((GameId g) => !context.completedToday.contains(g))
        .toList(growable: false);
    if (untouched.isNotEmpty) return untouched.first.name;
    final List<GameId> remaining = GameId.values
        .where((GameId g) => !context.completedToday.contains(g))
        .toList(growable: false);
    return (remaining.isEmpty ? GameId.memoryCards : remaining.first).name;
  }
}
