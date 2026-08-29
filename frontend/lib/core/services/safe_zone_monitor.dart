import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/safety.dart';
import 'location_service.dart';

/// Watches the patient's position against their safe zone.
///
/// A `ChangeNotifier`, matching the app's existing state pattern, so the map
/// and the caregiver's banner rebuild on each fix without a state-management
/// package.
///
/// **Why this is not a one-line distance check.** A naive
/// `distance > radius → alarm` produces an unusable product. Consumer GPS
/// drifts tens of metres while a phone sits still on a table, more indoors and
/// more between tall buildings. A caregiver woken three times a night by a
/// grandmother who never left her bed turns the feature off, and then it is
/// there for none of the times that matter. Three guards, in order:
///
///  1. **The accuracy buffer.** A fix accurate to ±80 m cannot prove anyone
///     left a 100 m zone, so the reading must be outside by more than its own
///     stated error before it counts at all.
///  2. **Confirmation.** One qualifying fix is a suspicion; [_confirmations]
///     consecutive ones are a fact.
///  3. **Re-entry hysteresis.** Coming back has to be *properly* back — inside
///     by [_reentryMarginMetres] — or a person standing on the boundary
///     generates an alert every few seconds.
class SafeZoneMonitor extends ChangeNotifier {
  SafeZoneMonitor({
    required LocationService location,
    SafeZone? zone,
    this.onLeft,
    this.onReturned,
  })  : _location = location,
        _zone = zone;

  final LocationService _location;

  /// Called once, on the fix that confirms the patient has left.
  final void Function(SafeZoneEvent event)? onLeft;

  /// Called once, on the fix that confirms they are properly back.
  final void Function(SafeZoneEvent event)? onReturned;

  /// How many consecutive qualifying fixes confirm a crossing.
  ///
  /// Two rather than one: at a 10 m distance filter that is a real walk away,
  /// not a jitter, and it still fires within seconds of someone actually
  /// leaving.
  static const int _confirmations = 2;

  /// How far back inside counts as returned.
  static const double _reentryMarginMetres = 20;

  SafeZone? _zone;
  LocationFix? _lastFix;
  SafeZonePresence _presence = SafeZonePresence.unknown;
  LocationPermissionOutcome? _permission;
  final List<SafeZoneEvent> _events = <SafeZoneEvent>[];

  int _outsideStreak = 0;
  StreamSubscription<LocationFix>? _subscription;
  bool _disposed = false;

  // ── What the UI reads ──────────────────────────────────────────────────

  SafeZone? get zone => _zone;
  LocationFix? get lastFix => _lastFix;
  SafeZonePresence get presence => _presence;
  bool get isOutside => _presence == SafeZonePresence.outside;
  bool get isTracking => _subscription != null;

  /// Null until permission has been asked for.
  LocationPermissionOutcome? get permission => _permission;

  /// Newest first, so the caregiver's list needs no sorting.
  List<SafeZoneEvent> get events => List<SafeZoneEvent>.unmodifiable(_events);

  /// How far outside the boundary, or null when inside or unknown.
  double? get metresOutside {
    final SafeZone? zone = _zone;
    final LocationFix? fix = _lastFix;
    if (zone == null || fix == null || !isOutside) return null;
    return zone.overshoot(fix.point);
  }

  /// The compass bearing from the patient back to the middle of their zone.
  double? get bearingHome {
    final SafeZone? zone = _zone;
    final LocationFix? fix = _lastFix;
    if (zone == null || fix == null) return null;
    return fix.point.bearingTo(zone.centre);
  }

  // ── Control ────────────────────────────────────────────────────────────

  /// Asks for permission and begins watching. Safe to call more than once.
  Future<LocationPermissionOutcome> start({int distanceFilterMetres = 10}) async {
    final LocationPermissionOutcome outcome = await _location.ensurePermission();
    _permission = outcome;
    if (!outcome.isGranted) {
      _notify();
      return outcome;
    }
    if (_subscription != null) {
      _notify();
      return outcome;
    }

    // A first reading straight away, so the map is not empty while the person
    // stands still waiting for the stream's distance filter to trip.
    final LocationFix? first = await _location.current();
    if (_disposed) return outcome;
    if (first != null) _ingest(first);

    _subscription = _location
        .watch(distanceFilterMetres: distanceFilterMetres)
        .listen(_ingest, onError: (Object error) {
      debugPrint('SafeZoneMonitor: position stream failed ($error)');
    });
    _notify();
    return outcome;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _notify();
  }

  /// Replaces the zone and re-evaluates the last known fix against it.
  ///
  /// Immediate re-evaluation matters: a caregiver who shrinks the zone around
  /// a patient who is already out should be told now, not at the next fix.
  void setZone(SafeZone? zone) {
    _zone = zone;
    _presence = SafeZonePresence.unknown;
    final LocationFix? fix = _lastFix;
    if (fix != null && zone != null) {
      // The confirmation guard exists to filter GPS jitter *over time*, and
      // there is no time here: the caregiver has just redrawn the boundary
      // around a position we already hold. Seeding the streak lets that one
      // known fix settle the question, so tightening the zone around someone
      // already outside says so now rather than at the next fix.
      _outsideStreak = _confirmations - 1;
      _evaluate(fix, zone);
    } else {
      _outsideStreak = 0;
    }
    _notify();
  }

  /// Feeds a reading in by hand. The demo and the tests use this; in the app
  /// the stream calls it.
  @visibleForTesting
  void ingest(LocationFix fix) => _ingest(fix);

  // ── The rule ───────────────────────────────────────────────────────────

  void _ingest(LocationFix fix) {
    _lastFix = fix;
    final SafeZone? zone = _zone;
    if (zone == null) {
      _presence = SafeZonePresence.unknown;
      _notify();
      return;
    }
    _evaluate(fix, zone);
    _notify();
  }

  void _evaluate(LocationFix fix, SafeZone zone) {
    final double overshoot = zone.overshoot(fix.point);

    // Guard 1: the reading has to be outside by more than its own error.
    // A ±80 m fix 30 m past the line is not evidence of anything.
    final bool convincinglyOutside = overshoot > fix.accuracyMetres;

    if (convincinglyOutside) {
      _outsideStreak++;
      // Guard 2: one qualifying fix is a suspicion, two are a fact.
      if (_presence != SafeZonePresence.outside && _outsideStreak >= _confirmations) {
        _presence = SafeZonePresence.outside;
        _record(SafeZoneEventKind.left, fix, overshoot, zone);
      }
      return;
    }

    _outsideStreak = 0;

    // Guard 3: properly back inside, not hovering on the line.
    final bool convincinglyInside = overshoot < -_reentryMarginMetres;
    if (!convincinglyInside) {
      // In the margin: hold whatever we already believed rather than
      // flip-flopping. An unknown presence resolves to inside, because the
      // person is within the boundary and nothing has said otherwise.
      if (_presence == SafeZonePresence.unknown && overshoot <= 0) {
        _presence = SafeZonePresence.inside;
      }
      return;
    }

    if (_presence == SafeZonePresence.outside) {
      _presence = SafeZonePresence.inside;
      _record(SafeZoneEventKind.returned, fix, overshoot, zone);
      return;
    }
    _presence = SafeZonePresence.inside;
  }

  void _record(
      SafeZoneEventKind kind, LocationFix fix, double overshoot, SafeZone zone) {
    final SafeZoneEvent event = SafeZoneEvent(
      kind: kind,
      atIso: fix.atIso,
      point: fix.point,
      distanceMetres: overshoot,
      zoneLabel: zone.label,
    );
    _events.insert(0, event);
    // The caregiver's list is a recent history, not an audit log; an
    // unbounded list on a phone left running for weeks is a slow leak.
    if (_events.length > 50) _events.removeLast();

    switch (kind) {
      case SafeZoneEventKind.left:
        onLeft?.call(event);
      case SafeZoneEventKind.returned:
        onReturned?.call(event);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _location.dispose();
    super.dispose();
  }
}
