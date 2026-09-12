import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';
import '../models/daily.dart';
import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_service.dart';
import 'on_device_ai_service.dart';

/// The service the app actually uses.
///
/// Policy, in one place, three tiers:
///
/// 1. If the device is online and a remote model is configured, try it
///    (Gemini today).
/// 2. If that's unavailable or fails for any reason, fall through to the
///    local tier — the fine-tuned on-device LLM when one is supplied and has
///    been downloaded ([llamaOnDevice]), otherwise straight to rule-based
///    templates.
/// 3. Rule-based templates ([OnDeviceAiService]) are the final floor: they
///    require no download, no model, and work on any device from the first
///    launch — so they're never skipped entirely, only preferred less.
///
/// [llamaOnDevice] already knows how to fall back to its own internal
/// [OnDeviceAiService] when the model isn't ready yet (see
/// `LlamaOnDeviceAiService`'s class doc) — so this class doesn't need to
/// separately check "is the model downloaded" itself; it just prefers
/// whichever local tier was supplied and trusts it to degrade gracefully.
///
/// The result always carries its [AiSource], so nothing on screen can pass a
/// locally-computed or on-device-generated sentence off as Gemini's work.
class ResilientAiService implements AiService {
  ResilientAiService({
    required AiService remote,
    required ConnectivityService connectivity,
    AiService? llamaOnDevice,
    OnDeviceAiService onDevice = const OnDeviceAiService(),
    Duration timeout = _kTimeout,
  })  : _remote = remote,
        _connectivity = connectivity,
        _local = llamaOnDevice ?? onDevice;

  final AiService _remote;
  final ConnectivityService _connectivity;

  /// Whichever local tier is in play — the on-device LLM if one was supplied,
  /// otherwise the rule-based [OnDeviceAiService] directly.
  final AiService _local;

  AiFailure? _lastFailure;

  /// Why the last call fell back, or null if it succeeded remotely.
  /// Useful for a quiet "showing offline insight" label; never a blocking error.
  AiFailure? get lastFailure => _lastFailure;

  /// True when a remote call is worth attempting right now.
  @override
  bool get isAvailable => _connectivity.isOnline && _remote.isAvailable;

  @override
  void dispose() {
    _remote.dispose();
    _local.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Runs [call] with a [_timeout] circuit breaker.
  ///
  /// On timeout: sets [_lastFailure] to [AiErrorKind.timeout] and returns
  /// the [fallback] value wrapped in [AiSuccess].
  /// On any other error: sets [_lastFailure] to [AiErrorKind.network] and
  /// returns [fallback].
  Future<AiResult<T>> _withTimeout<T>({
    required Future<AiResult<T>> Function() call,
    required T fallback,
    required String label,
  }) async {
    try {
      final AiResult<T> result = await call().timeout(_timeout);
      return result.fold(
        onSuccess: (T value) {
          _lastFailure = null;
          return AiSuccess<T>(value);
        },
        onError: (AiFailure failure) {
          _lastFailure = failure;
          debugPrint('ResilientAiService: $label remote error → device ($failure)');
          return AiSuccess<T>(fallback);
        },
      );
    } on Object catch (e) {
      final bool isTimeout = e.toString().contains('TimeoutException');
      _lastFailure = AiFailure(isTimeout ? AiErrorKind.timeout : AiErrorKind.server);

      debugPrint('ResilientAiService: $label ${isTimeout ? "timed out" : "threw"} → device ($e)');
      return AiSuccess<T>(fallback);
    }
  }

  // ── AiService implementation ──────────────────────────────────────────────

  @override
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext context) async {
    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return _local.cognitiveInsight(context);
    }

    final AiResult<CognitiveInsight> result = await _remote.cognitiveInsight(context);
    switch (result) {
      case AiSuccess<CognitiveInsight>(:final CognitiveInsight value):
        _lastFailure = null;
        return AiSuccess<CognitiveInsight>(value);
      case AiError<CognitiveInsight>(:final AiFailure failure):
        _lastFailure = failure;
        debugPrint('ResilientAiService: insight fell back to device ($failure)');
        return _local.cognitiveInsight(context);
    }
  }

  @override
  Future<AiResult<AssistantReply>> ask(String question, PatientAiContext context) async {
    if (question.trim().isEmpty) {
      // Not worth a round trip, and not worth an error screen either.
      return _local.ask('', context);
    }

    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return _local.ask(question, context);
    }

    final AiResult<AssistantReply> result = await _remote.ask(question, context);
    switch (result) {
      case AiSuccess<AssistantReply>(:final AssistantReply value):
        _lastFailure = null;
        return AiSuccess<AssistantReply>(value);
      case AiError<AssistantReply>(:final AiFailure failure):
        _lastFailure = failure;
        debugPrint('ResilientAiService: answer fell back to device ($failure)');
        return _local.ask(question, context);
    }
  }

  @override
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext context) async {
    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return _local.dailyQuestions(context);
    }

    final AiResult<List<DailyQuestion>> result = await _remote.dailyQuestions(context);
    switch (result) {
      case AiSuccess<List<DailyQuestion>>(:final List<DailyQuestion> value):
        _lastFailure = null;
        return AiSuccess<List<DailyQuestion>>(value);
      case AiError<List<DailyQuestion>>(:final AiFailure failure):
        _lastFailure = failure;
        debugPrint('ResilientAiService: questions fell back to device ($failure)');
        return _local.dailyQuestions(context);
    }
  }
}
