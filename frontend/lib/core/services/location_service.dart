import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/safety.dart';

/// What happened when we asked for the patient's position.
enum LocationPermissionOutcome {
  granted,

  /// Refused this time; asking again is allowed.
  denied,

  /// Refused permanently. Only Settings can change it.
  permanentlyDenied,

  /// Location is switched off on the device entirely, which no app permission
  /// can override — the caregiver has to be told to turn it on.
  serviceDisabled,
}

extension LocationPermissionOutcomeX on LocationPermissionOutcome {
  bool get isGranted => this == LocationPermissionOutcome.granted;

  /// Caregiver-facing wording. Never technical, and always says who can fix it.
  String get message => switch (this) {
        LocationPermissionOutcome.granted => '',
        LocationPermissionOutcome.denied =>
          'MemoryMitra needs permission to see the location before it can watch the safe zone.',
        LocationPermissionOutcome.permanentlyDenied =>
          'Location access is turned off for this app. Turn it on in the phone\'s Settings.',
        LocationPermissionOutcome.serviceDisabled =>
          'Location is switched off on this phone. Turn it on to use the safe zone.',
      };
}

/// The device's position, abstracted away from any one plugin.
///
/// The same shape as the voice layer's [SpeechRecognizer]: an interface here
/// is what lets the whole safe-zone flow be tested without a device, a GPS fix
/// or a platform channel.
abstract class LocationService {
  /// Checks the service and the permission, asking if it has not been asked.
  Future<LocationPermissionOutcome> ensurePermission();

  /// A single reading, or null when one cannot be taken.
  Future<LocationFix?> current();

  /// Readings as the patient moves.
  ///
  /// [distanceFilterMetres] is how far they must move before a new reading is
  /// emitted — the single biggest lever on battery life, which matters on a
  /// phone that has to last the day.
  Stream<LocationFix> watch({int distanceFilterMetres = 10});

  void dispose();
}

/// `geolocator` behind the app's [LocationService] interface.
class GeolocatorLocationService implements LocationService {
  StreamSubscription<Position>? _subscription;

  @override
  Future<LocationPermissionOutcome> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionOutcome.serviceDisabled;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse =>
        LocationPermissionOutcome.granted,
      LocationPermission.deniedForever =>
        LocationPermissionOutcome.permanentlyDenied,
      _ => LocationPermissionOutcome.denied,
    };
  }

  @override
  Future<LocationFix?> current() async {
    if (!(await ensurePermission()).isGranted) return null;
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return _toFix(position);
    } catch (error) {
      debugPrint('GeolocatorLocationService: current() failed ($error)');
      return null;
    }
  }

  @override
  Stream<LocationFix> watch({int distanceFilterMetres = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMetres,
      ),
    ).map(_toFix);
  }

  static LocationFix _toFix(Position position) => LocationFix(
        point: GeoPoint(position.latitude, position.longitude),
        accuracyMetres: position.accuracy,
        atIso: position.timestamp.toIso8601String(),
      );

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// A scriptable location source for tests and for the demo.
///
/// Also what makes the feature demonstrable indoors: a laptop with no GPS can
/// still walk a patient out of their zone and back.
@visibleForTesting
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.outcome = LocationPermissionOutcome.granted,
    this.initial,
  });

  LocationPermissionOutcome outcome;
  LocationFix? initial;

  final StreamController<LocationFix> _controller =
      StreamController<LocationFix>.broadcast();

  int permissionAsks = 0;
  bool disposed = false;

  @override
  Future<LocationPermissionOutcome> ensurePermission() async {
    permissionAsks++;
    return outcome;
  }

  @override
  Future<LocationFix?> current() async => outcome.isGranted ? initial : null;

  @override
  Stream<LocationFix> watch({int distanceFilterMetres = 10}) => _controller.stream;

  /// Moves the fake patient.
  void emit(GeoPoint point, {double accuracyMetres = 5}) {
    _controller.add(LocationFix(
      point: point,
      accuracyMetres: accuracyMetres,
      atIso: DateTime.now().toIso8601String(),
    ));
  }

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}
