import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/sync_operation.dart';
import '../../data/repositories/repositories.dart';
import 'connectivity_service.dart';

/// Where a queued operation is sent once the device is back online.
///
/// No backend exists yet, so the shipped transport is [LoopbackTransport].
/// When a Firebase or FastAPI client lands it implements this one method and
/// nothing else in the app changes.
abstract class SyncTransport {
  /// Returns normally on success; throws to leave the operation queued.
  Future<void> send(PendingOperation operation);

  /// Pulls everything the server holds for a patient, or null when there is
  /// nothing to pull — a profile that has never synced, or no network.
  ///
  /// The mirror image of [send]: that drains this device's outbox upwards,
  /// this fills a fresh device's local store back down. Default-implemented
  /// so a transport that cannot restore (the loopback one) is still a valid
  /// transport rather than a compile error.
  Future<Map<String, dynamic>?> restore(String patientId);
}

/// Accepts everything after a short delay, standing in for a network round
/// trip. Keeps the demo honest about latency without needing a server.
class LoopbackTransport implements SyncTransport {
  const LoopbackTransport({this.latency = const Duration(milliseconds: 180)});

  final Duration latency;

  @override
  Future<void> send(PendingOperation operation) => Future<void>.delayed(latency);
  /// Nothing to restore from: this transport has no server behind it, so a
  /// device using it is the only copy of its own record.
  @override
  Future<Map<String, dynamic>?> restore(String patientId) async => null;

}

/// Drains the durable outbox whenever the device is online.
///
/// The contract the rest of the app relies on:
///
/// * A user action is written to Hive **and** queued in the same call, so the
///   two can never disagree after a crash.
/// * Queued work survives restart — the queue is a Hive box, not a list.
/// * Coming back online drains the queue without anyone tapping anything.
/// * A failed send leaves the operation queued and retryable, never dropped.
class SyncManager extends ChangeNotifier {
  SyncManager({
    required SyncRepository repository,
    required ConnectivityService connectivity,
    SyncTransport transport = const LoopbackTransport(),
  })  : _repository = repository,
        _connectivity = connectivity,
        _transport = transport {
    _subscription = _connectivity.changes.listen(_onConnectivityChanged);
  }

  final SyncRepository _repository;
  final ConnectivityService _connectivity;
  final SyncTransport _transport;
  StreamSubscription<bool>? _subscription;

  int _pending = 0;
  bool _syncing = false;
  bool _disposed = false;
  Future<void> _inFlight = Future<void>.value();
  DateTime? _lastSyncedAt;
  String? _lastError;

  int get pendingCount => _pending;
  bool get isSyncing => _syncing;
  bool get isOnline => _connectivity.isOnline;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;

  /// True when work is waiting and the device cannot send it.
  bool get hasUnsyncedWork => _pending > 0;

  /// Completes when any drain started in the background has finished.
  ///
  /// Enqueuing while online kicks off a drain that nobody awaits, which is
  /// right for the UI and wrong for a caller about to close the boxes. Tests
  /// and shutdown paths await this first.
  Future<void> get settled => _inFlight;

  /// Loads the queue depth left over from a previous run.
  Future<void> load() async {
    _pending = (await _repository.pending()).length;
    _safeNotify();
  }

  /// Records a local change in the outbox. Called by `AppState` immediately
  /// after the change itself has been written to its own box.
  Future<void> enqueue(SyncOperationKind kind, Map<String, dynamic> payload) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _repository.enqueue(PendingOperation(
      id: '${kind.name}_${now}_$_pending',
      kind: kind,
      payload: payload,
      createdAtMillis: now,
    ));
    _pending += 1;
    _safeNotify();

    // Online, this drains straight away — the queue is invisible to a
    // connected user and only becomes a feature when the connection drops.
    if (_connectivity.isOnline) _startBackgroundSync();
  }

  void _onConnectivityChanged(bool online) {
    _safeNotify();
    if (online) _startBackgroundSync();
  }

  /// Runs a drain nobody is waiting on, but keeps a handle so [settled] can.
  void _startBackgroundSync() {
    _inFlight = _inFlight.then((_) async {
      try {
        await sync();
      } catch (error) {
        debugPrint('SyncManager: background drain failed ($error)');
      }
    });
  }

  /// Processes the queue. Returns the number of operations confirmed synced.
  ///
  /// Safe to call at any time: it is a no-op while offline, while another
  /// drain is running, or when the queue is empty.
  Future<int> sync() async {
    if (_disposed || _syncing || !_connectivity.isOnline) return 0;

    final List<PendingOperation> queue = await _repository.pending();
    if (queue.isEmpty) {
      _pending = 0;
      _safeNotify();
      return 0;
    }

    _syncing = true;
    _lastError = null;
    _safeNotify();

    int sent = 0;
    for (final PendingOperation operation in queue) {
      // A connection lost mid-drain stops the run; whatever is left stays
      // queued and is picked up by the next reconnect.
      if (_disposed || !_connectivity.isOnline) break;
      await _repository.update(operation.copyWith(status: SyncStatus.syncing));
      try {
        await _transport.send(operation);
        await _repository.update(operation.copyWith(
          status: SyncStatus.synced,
          attempts: operation.attempts + 1,
          syncedAtMillis: DateTime.now().millisecondsSinceEpoch,
        ));
        sent += 1;
      } catch (error) {
        _lastError = error.toString();
        await _repository.update(operation.copyWith(
          status: SyncStatus.failed,
          attempts: operation.attempts + 1,
          lastError: error.toString(),
        ));
      }
    }

    if (_disposed) return sent;
    await _repository.purgeSynced();
    _pending = (await _repository.pending()).length;
    if (sent > 0) _lastSyncedAt = DateTime.now();
    _syncing = false;
    _safeNotify();
    return sent;
  }

  /// Everything in the outbox, newest first — backs the caregiver's sync list.
  Future<List<PendingOperation>> inspect() => _repository.all();

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
