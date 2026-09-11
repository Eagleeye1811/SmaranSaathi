import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';
import '../models/daily.dart';
import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_service.dart';
import 'on_device_ai_service.dart';

/// The service the app actually uses.
///
/// Policy, in one place:
///
/// 1. If the device is offline, or the build has no AI configured, answer
///    on-device immediately — no spinner, no error.
/// 2. If online, attempt the remote call with a [_kTimeout] circuit breaker.
///    Low-connectivity users (slow 2G/3G) get the on-device answer within
///    3 seconds rather than waiting indefinitely.
/// 3. If the remote call fails for *any* reason (timeout, HTTP error,
///    malformed JSON, rate-limit), fall back silently to on-device.
///
/// The result always carries its [AiSource], so nothing on screen can pass a
/// locally-computed sentence off as a model's work.
class ResilientAiService implements AiService {
  ResilientAiService({
    required AiService remote,
    required ConnectivityService connectivity,
    OnDeviceAiService onDevice = const OnDeviceAiService(),
    Duration timeout = _kTimeout,
  })  : _remote = remote,
        _connectivity = connectivity,
        _onDevice = onDevice,
        _timeout = timeout;

  final AiService _remote;
  final ConnectivityService _connectivity;
  final OnDeviceAiService _onDevice;
  final Duration _timeout;

  /// 3-second circuit breaker — on spotty 2G/3G this fires before the patient
  /// notices the app is slow, giving them an instant on-device answer instead.
  static const Duration _kTimeout = Duration(seconds: 3);

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
    _onDevice.dispose();
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
      return AiSuccess<CognitiveInsight>(_onDevice.buildInsight(context));
    }

    return _withTimeout(
      call: () => _remote.cognitiveInsight(context),
      fallback: _onDevice.buildInsight(context),
      label: 'cognitiveInsight',
    );
  }

  @override
  Future<AiResult<AssistantReply>> ask(String question, PatientAiContext context) async {
    if (question.trim().isEmpty) {
      return AiSuccess<AssistantReply>(_onDevice.buildReply('', context));
    }

    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return AiSuccess<AssistantReply>(_onDevice.buildReply(question, context));
    }

    return _withTimeout(
      call: () => _remote.ask(question, context),
      fallback: _onDevice.buildReply(question, context),
      label: 'ask',
    );
  }

  @override
  Future<AiResult<List<DailyQuestion>>> dailyQuestions(PatientAiContext context) async {
    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return AiSuccess<List<DailyQuestion>>(_onDevice.buildDailyQuestions(context));
    }

    return _withTimeout(
      call: () => _remote.dailyQuestions(context),
      fallback: _onDevice.buildDailyQuestions(context),
      label: 'dailyQuestions',
    );
  }
}
