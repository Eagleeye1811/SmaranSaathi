import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Whether the device currently has a route to the network.
///
/// Abstracted so tests — and the caregiver's manual "work offline" switch —
/// can drive it without a real radio.
abstract class ConnectivityService {
  /// Best current knowledge. Cheap; does not hit the network.
  bool get isOnline;

  /// Emits on every transition. Does not replay the current value.
  Stream<bool> get changes;

  /// Refreshes [isOnline] from the platform.
  Future<bool> refresh();

  Future<void> dispose();
}

/// Real connectivity, backed by `connectivity_plus`.
///
/// Note this reports *interface* state, not reachability: a device attached to
/// a captive portal reads as online. That is the right trade-off here — the
/// sync transport surfaces a genuine failure by failing, and the queue simply
/// retries.
class PlatformConnectivityService implements ConnectivityService {
  PlatformConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(_onResults);
    unawaited(refresh());
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _online = true;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _controller.stream;

  void _onResults(List<ConnectivityResult> results) => _set(_readOnline(results));

  static bool _readOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((ConnectivityResult r) => r == ConnectivityResult.none);

  void _set(bool value) {
    if (_online == value) return;
    _online = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  Future<bool> refresh() async {
    try {
      _set(_readOnline(await _connectivity.checkConnectivity()));
    } catch (error) {
      // A platform that cannot answer is treated as online: the transport will
      // fail honestly and the queue will hold the work.
      debugPrint('ConnectivityService: check failed ($error)');
    }
    return _online;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// Connectivity the caller sets by hand.
///
/// Backs the caregiver's "work offline" switch and every offline test — the
/// demo can be driven into a genuine offline state on a device that is online.
class ManualConnectivityService implements ConnectivityService {
  ManualConnectivityService({bool online = true}) : _online = online;

  bool _online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _controller.stream;

  set isOnline(bool value) {
    if (_online == value) return;
    _online = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  Future<bool> refresh() async => _online;

  @override
  Future<void> dispose() async => _controller.close();
}

/// Wraps a real service with a manual override.
///
/// The override can only force the app *offline* — a caregiver on a train can
/// tell the app to stop trying, but no switch can conjure a connection that
/// does not exist.
class OverridableConnectivityService implements ConnectivityService {
  OverridableConnectivityService(this._delegate) {
    _subscription = _delegate.changes.listen((_) => _emit());
  }

  final ConnectivityService _delegate;
  StreamSubscription<bool>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _forcedOffline = false;
  bool _last = true;

  bool get forcedOffline => _forcedOffline;

  set forcedOffline(bool value) {
    if (_forcedOffline == value) return;
    _forcedOffline = value;
    _emit();
  }

  void _emit() {
    final bool now = isOnline;
    if (now == _last) return;
    _last = now;
    if (!_controller.isClosed) _controller.add(now);
  }

  @override
  bool get isOnline => !_forcedOffline && _delegate.isOnline;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<bool> refresh() async {
    await _delegate.refresh();
    _emit();
    return isOnline;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
    await _delegate.dispose();
  }
}
