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
/// 1. If the device is offline, or the build has no AI configured, do not
///    attempt a call — answer on-device immediately. A patient asking "what do
///    I have today?" in a village with no signal gets an answer, not a spinner
///    followed by an error.
/// 2. Otherwise try the remote service.
/// 3. If it fails for *any* reason, fall back to the on-device answer rather
///    than surfacing an error. The failure is still reported through
///    [lastFailure] so a caregiver screen can show "offline — generated on this
///    device" honestly.
///
/// The result always carries its [AiSource], so nothing on screen can pass a
/// locally-computed sentence off as a model's work.
class ResilientAiService implements AiService {
  ResilientAiService({
    required AiService remote,
    required ConnectivityService connectivity,
    OnDeviceAiService onDevice = const OnDeviceAiService(),
  })  : _remote = remote,
        _connectivity = connectivity,
        _onDevice = onDevice;

  final AiService _remote;
  final ConnectivityService _connectivity;
  final OnDeviceAiService _onDevice;

  AiFailure? _lastFailure;

  /// Why the last call fell back, or null if it did not. Useful for a quiet
  /// "showing offline insight" line; never shown as a blocking error.
  AiFailure? get lastFailure => _lastFailure;

  /// True when a remote call is worth attempting right now.
  @override
  bool get isAvailable => _connectivity.isOnline && _remote.isAvailable;

  @override
  void dispose() {
    _remote.dispose();
    _onDevice.dispose();
  }

  @override
  Future<AiResult<CognitiveInsight>> cognitiveInsight(PatientAiContext context) async {
    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return AiSuccess<CognitiveInsight>(_onDevice.buildInsight(context));
    }

    final AiResult<CognitiveInsight> result = await _remote.cognitiveInsight(context);
    return result.fold(
      onSuccess: (CognitiveInsight value) {
        _lastFailure = null;
        return AiSuccess<CognitiveInsight>(value);
      },
      onError: (AiFailure failure) {
        _lastFailure = failure;
        debugPrint('ResilientAiService: insight fell back to device ($failure)');
        return AiSuccess<CognitiveInsight>(_onDevice.buildInsight(context));
      },
    );
  }

  @override
  Future<AiResult<AssistantReply>> ask(String question, PatientAiContext context) async {
    if (question.trim().isEmpty) {
      // Not worth a round trip, and not worth an error screen either.
      return AiSuccess<AssistantReply>(_onDevice.buildReply('', context));
    }

    if (!isAvailable) {
      _lastFailure = AiFailure(
        _connectivity.isOnline ? AiErrorKind.notConfigured : AiErrorKind.offline,
      );
      return AiSuccess<AssistantReply>(_onDevice.buildReply(question, context));
    }

    final AiResult<AssistantReply> result = await _remote.ask(question, context);
    return result.fold(
      onSuccess: (AssistantReply value) {
        _lastFailure = null;
        return AiSuccess<AssistantReply>(value);
      },
      onError: (AiFailure failure) {
        _lastFailure = failure;
        debugPrint('ResilientAiService: answer fell back to device ($failure)');
        return AiSuccess<AssistantReply>(_onDevice.buildReply(question, context));
      },
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

    final AiResult<List<DailyQuestion>> result = await _remote.dailyQuestions(context);
    return result.fold(
      onSuccess: (List<DailyQuestion> value) {
        _lastFailure = null;
        return AiSuccess<List<DailyQuestion>>(value);
      },
      onError: (AiFailure failure) {
        _lastFailure = failure;
        debugPrint('ResilientAiService: questions fell back to device ($failure)');
        return AiSuccess<List<DailyQuestion>>(_onDevice.buildDailyQuestions(context));
      },
    );
  }
}
