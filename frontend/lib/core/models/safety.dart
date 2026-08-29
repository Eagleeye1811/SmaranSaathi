import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A point on the earth.
///
/// Deliberately not `latlong2`'s `LatLng`: the domain layer and the tests must
/// not depend on the map package, so the map screen converts at its own edge.
/// That is what lets every rule in this file be tested without a device, a
/// tile server or a plugin.
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Metres between two points, by the haversine formula.
  ///
  /// Accurate to a few metres at the distances a safe zone deals in, which is
  /// far below GPS error, so nothing is gained by anything more elaborate.
  double distanceTo(GeoPoint other) {
    const double earthRadius = 6371000; // metres
    final double dLat = _radians(other.latitude - latitude);
    final double dLng = _radians(other.longitude - longitude);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(latitude)) *
            math.cos(_radians(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Compass bearing to [other] in degrees, 0 = north.
  ///
  /// Used to point a lost patient the right way without a route: "the way home
  /// is behind you" is more use than a blue line they cannot follow.
  double bearingTo(GeoPoint other) {
    final double dLng = _radians(other.longitude - longitude);
    final double y = math.sin(dLng) * math.cos(_radians(other.latitude));
    final double x =
        math.cos(_radians(latitude)) * math.sin(_radians(other.latitude)) -
            math.sin(_radians(latitude)) *
                math.cos(_radians(other.latitude)) *
                math.cos(dLng);
    return (_degrees(math.atan2(y, x)) + 360) % 360;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
  static double _degrees(double radians) => radians * 180 / math.pi;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'lat': latitude, 'lng': longitude};

  static GeoPoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final double? lat = (json['lat'] as num?)?.toDouble();
    final double? lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return GeoPoint(lat, lng);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
}

/// The area the patient is expected to stay inside.
///
/// A circle rather than a drawn polygon, on purpose: a caregiver setting this
/// up on a phone, often in a hurry, can place a pin and drag one slider. A
/// polygon editor is a better *map* feature and a worse *caregiver* feature.
@immutable
class SafeZone {
  const SafeZone({
    required this.id,
    required this.label,
    required this.centre,
    required this.radiusMetres,
    required this.createdAtIso,
  });

  final String id;

  /// What the caregiver calls it — "Home", "Ma's street".
  final String label;

  final GeoPoint centre;
  final double radiusMetres;
  final String createdAtIso;

  /// The smallest zone the UI offers.
  ///
  /// Below about 50 m a zone is smaller than ordinary GPS error in a built-up
  /// area, so it would alarm while the person sat in their own front room.
  static const double minRadiusMetres = 50;
  static const double maxRadiusMetres = 2000;
  static const double defaultRadiusMetres = 200;

  bool contains(GeoPoint point) => centre.distanceTo(point) <= radiusMetres;

  /// How far outside the boundary [point] is; negative when inside.
  double overshoot(GeoPoint point) => centre.distanceTo(point) - radiusMetres;

  SafeZone copyWith({String? label, GeoPoint? centre, double? radiusMetres}) =>
      SafeZone(
        id: id,
        label: label ?? this.label,
        centre: centre ?? this.centre,
        radiusMetres: radiusMetres ?? this.radiusMetres,
        createdAtIso: createdAtIso,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'centre': centre.toJson(),
        'radiusMetres': radiusMetres,
        'createdAtIso': createdAtIso,
      };

  static SafeZone? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final GeoPoint? centre =
        GeoPoint.fromJson(json['centre'] as Map<String, dynamic>?);
    final double? radius = (json['radiusMetres'] as num?)?.toDouble();
    if (centre == null || radius == null) return null;
    return SafeZone(
      id: json['id'] as String? ?? 'zone',
      label: json['label'] as String? ?? 'Safe zone',
      centre: centre,
      radiusMetres: radius,
      createdAtIso: json['createdAtIso'] as String? ?? '',
    );
  }

  /// Round-trips through the settings box, which stores plain strings.
  String encode() => jsonEncode(toJson());

  static SafeZone? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt value must not stop the app from starting; no zone simply
      // means the caregiver is asked to set one again.
      return null;
    }
  }
}

/// One reading from the device.
@immutable
class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracyMetres,
    required this.atIso,
  });

  final GeoPoint point;

  /// The radius the device believes it is accurate to. Load-bearing: a fix
  /// accurate to 80 m cannot prove someone left a 100 m zone.
  final double accuracyMetres;

  final String atIso;

  DateTime? get at => DateTime.tryParse(atIso);

  @override
  String toString() => 'LocationFix($point ±${accuracyMetres.round()}m)';
}

/// Where the patient is relative to their zone.
enum SafeZonePresence {
  /// No zone set, or no fix yet.
  unknown,
  inside,
  outside,
}

/// Something worth telling the caregiver about.
enum SafeZoneEventKind { left, returned }

@immutable
class SafeZoneEvent {
  const SafeZoneEvent({
    required this.kind,
    required this.atIso,
    required this.point,
    required this.distanceMetres,
    required this.zoneLabel,
  });

  final SafeZoneEventKind kind;
  final String atIso;
  final GeoPoint point;

  /// How far outside the boundary at the moment of the event.
  final double distanceMetres;

  final String zoneLabel;

  DateTime? get at => DateTime.tryParse(atIso);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'atIso': atIso,
        'point': point.toJson(),
        'distanceMetres': distanceMetres,
        'zoneLabel': zoneLabel,
      };
}
