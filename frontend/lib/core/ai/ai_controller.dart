import 'package:flutter/foundation.dart';

import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_service.dart';

/// What a screen is currently showing.
enum AiPhase { idle, loading, ready, failed }

/// A `ChangeNotifier` around one AI call, matching the app's existing state
/// pattern (`ChangeNotifier` + `InheritedNotifier`, no state-management
/// package).
///
/// Exists so screens never manage their own loading booleans, never fire two
/// overlapping requests, and never render a stale answer after a newer one has
/// been asked for.
class AiRequestController<T> extends ChangeNotifier {
  AiRequestController(this._call);

  final Future<AiResult<T>> Function(PatientAiContext context) _call;

  AiPhase _phase = AiPhase.idle;
  T? _value;
  AiFailure? _failure;
  int _generation = 0;
  bool _disposed = false;

  AiPhase get phase => _phase;
  T? get value => _value;
  AiFailure? get failure => _failure;

  bool get isLoading => _phase == AiPhase.loading;
  bool get hasValue => _value != null;

  /// True while loading *and* a previous answer is on screen — the caller can
  /// keep showing it, dimmed, rather than replacing it with a spinner.
  bool get isRefreshing => isLoading && _value != null;

  /// Runs the call. A second invocation supersedes the first: the older
  /// result is discarded when it lands, so a slow response can never overwrite
  /// a newer one.
  Future<void> run(PatientAiContext context) async {
    final int generation = ++_generation;
    _phase = AiPhase.loading;
    _failure = null;
    _notify();

    final AiResult<T> result = await _call(context);
    if (_disposed || generation != _generation) return;

    result.fold(
      onSuccess: (T value) {
        _value = value;
        _phase = AiPhase.ready;
      },
      onError: (AiFailure failure) {
        _failure = failure;
        _phase = AiPhase.failed;
      },
    );
    _notify();
  }

  /// Drops the current answer without firing a new call.
  void reset() {
    _generation++;
    _value = null;
    _failure = null;
    _phase = AiPhase.idle;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Convenience constructors for the two calls the app makes.
class AiControllers {
  const AiControllers._();

  static AiRequestController<CognitiveInsight> insight(AiService service) =>
      AiRequestController<CognitiveInsight>(service.cognitiveInsight);

  static AiRequestController<AssistantReply> assistant(
    AiService service,
    String Function() question,
  ) =>
      AiRequestController<AssistantReply>(
        (PatientAiContext c) => service.ask(question(), c),
      );
}
