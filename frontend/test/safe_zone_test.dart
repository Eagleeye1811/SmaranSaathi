import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/models/safety.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/services/location_service.dart';
import 'package:smaran_saathi/core/services/safe_zone_monitor.dart';
import 'package:smaran_saathi/features/patient/safety/return_home_banner.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

/// A house in Jorhat, Assam — the product's actual setting.
const GeoPoint kHome = GeoPoint(26.7509, 94.2037);

/// Roughly [metres] north of [from]. One degree of latitude is ~111,320 m.
GeoPoint north(GeoPoint from, double metres) =>
    GeoPoint(from.latitude + metres / 111320, from.longitude);

SafeZone zoneOf({double radius = 200}) => SafeZone(
      id: 'z1',
      label: 'Home',
      centre: kHome,
      radiusMetres: radius,
      createdAtIso: '2026-08-29T09:00:00.000',
    );

LocationFix fixAt(GeoPoint point, {double accuracy = 5}) => LocationFix(
      point: point,
      accuracyMetres: accuracy,
      atIso: '2026-08-29T10:00:00.000',
    );

void main() {
  group('GeoPoint', () {
    test('haversine distance is accurate at safe-zone scale', () {
      // 500 m north should measure 500 m, within a metre.
      expect(kHome.distanceTo(north(kHome, 500)), closeTo(500, 1));
      expect(kHome.distanceTo(kHome), 0);
    });

    test('bearing points the right way home', () {
      // Standing north of home, home is due south.
      expect(north(kHome, 300).bearingTo(kHome), closeTo(180, 0.5));
      expect(kHome.bearingTo(north(kHome, 300)), closeTo(0, 0.5));
    });
  });

  group('SafeZone', () {
    test('contains and overshoot agree with the radius', () {
      final SafeZone zone = zoneOf();
      expect(zone.contains(north(kHome, 150)), isTrue);
      expect(zone.contains(north(kHome, 250)), isFalse);
      expect(zone.overshoot(north(kHome, 250)), closeTo(50, 1));
      expect(zone.overshoot(north(kHome, 150)), closeTo(-50, 1));
    });

    test('survives a round trip through the settings box', () {
      final SafeZone zone = zoneOf(radius: 350);
      final SafeZone? back = SafeZone.decode(zone.encode());
      expect(back!.id, zone.id);
      expect(back.label, 'Home');
      expect(back.radiusMetres, 350);
      expect(back.centre, kHome);
    });

    test('a corrupt stored value is no zone rather than a crash', () {
      expect(SafeZone.decode('not json'), isNull);
      expect(SafeZone.decode('{"label":"Home"}'), isNull);
      expect(SafeZone.decode(null), isNull);
      expect(SafeZone.decode(''), isNull);
    });
  });

  group('SafeZoneMonitor', () {
    late FakeLocationService location;
    late List<SafeZoneEvent> left;
    late List<SafeZoneEvent> returned;

    SafeZoneMonitor build({SafeZone? zone}) => SafeZoneMonitor(
          location: location,
          zone: zone ?? zoneOf(),
          onLeft: left.add,
          onReturned: returned.add,
        );

    setUp(() {
      location = FakeLocationService();
      left = <SafeZoneEvent>[];
      returned = <SafeZoneEvent>[];
    });

    test('two confirming fixes outside raise exactly one alert', () {
      final SafeZoneMonitor m = build();

      m.ingest(fixAt(north(kHome, 100)));
      expect(m.presence, SafeZonePresence.inside);

      // One fix outside is a suspicion, not an alert.
      m.ingest(fixAt(north(kHome, 400)));
      expect(left, isEmpty);
      expect(m.presence, SafeZonePresence.inside);

      // The second confirms it.
      m.ingest(fixAt(north(kHome, 420)));
      expect(left, hasLength(1));
      expect(m.presence, SafeZonePresence.outside);
      expect(left.single.distanceMetres, closeTo(220, 2));
      expect(left.single.zoneLabel, 'Home');

      // Staying out does not re-alert.
      m.ingest(fixAt(north(kHome, 600)));
      m.ingest(fixAt(north(kHome, 800)));
      expect(left, hasLength(1));
      m.dispose();
    });

    test('a wildly inaccurate fix cannot prove anything', () {
      final SafeZoneMonitor m = build();
      m.ingest(fixAt(north(kHome, 100)));

      // 50 m past a 200 m boundary, but the phone only claims ±150 m. This is
      // the reading that wakes a caregiver at 3am for nothing.
      m.ingest(fixAt(north(kHome, 250), accuracy: 150));
      m.ingest(fixAt(north(kHome, 250), accuracy: 150));
      expect(left, isEmpty);
      expect(m.presence, SafeZonePresence.inside);
      m.dispose();
    });

    test('GPS jitter across the boundary does not alarm', () {
      final SafeZoneMonitor m = build();
      m.ingest(fixAt(north(kHome, 100)));

      // A phone on a windowsill, drifting either side of the line.
      for (int i = 0; i < 10; i++) {
        m.ingest(fixAt(north(kHome, 205), accuracy: 12));
        m.ingest(fixAt(north(kHome, 190), accuracy: 12));
      }
      expect(left, isEmpty);
      m.dispose();
    });

    test('returning has to be properly back inside', () {
      final SafeZoneMonitor m = build();
      m.ingest(fixAt(north(kHome, 100)));
      m.ingest(fixAt(north(kHome, 400)));
      m.ingest(fixAt(north(kHome, 420)));
      expect(m.isOutside, isTrue);

      // Standing on the line is not "returned" — it would fire an all-clear
      // every few seconds while they hover at the boundary.
      m.ingest(fixAt(north(kHome, 195)));
      expect(returned, isEmpty);
      expect(m.isOutside, isTrue);

      // Well inside is.
      m.ingest(fixAt(north(kHome, 120)));
      expect(returned, hasLength(1));
      expect(m.presence, SafeZonePresence.inside);
      m.dispose();
    });

    test('a full round trip can happen twice', () {
      final SafeZoneMonitor m = build();
      for (int lap = 0; lap < 2; lap++) {
        m.ingest(fixAt(north(kHome, 400)));
        m.ingest(fixAt(north(kHome, 420)));
        m.ingest(fixAt(north(kHome, 100)));
      }
      expect(left, hasLength(2));
      expect(returned, hasLength(2));
      m.dispose();
    });

    test('no zone means nothing is judged', () {
      final SafeZoneMonitor m = SafeZoneMonitor(location: location, zone: null);
      m.ingest(fixAt(north(kHome, 5000)));
      expect(m.presence, SafeZonePresence.unknown);
      expect(m.metresOutside, isNull);
      m.dispose();
    });

    test('shrinking the zone re-judges the patient immediately', () {
      final SafeZoneMonitor m = build(zone: zoneOf(radius: 1000));
      m.ingest(fixAt(north(kHome, 400)));
      expect(m.presence, SafeZonePresence.inside);

      // The caregiver tightens it to 200 m around someone already 400 m out.
      // Waiting for the next fix would be the wrong answer.
      m.setZone(zoneOf(radius: 200));
      expect(m.presence, SafeZonePresence.outside);
      expect(left, hasLength(1));
      m.dispose();
    });

    test('distance and bearing home guide the patient back', () {
      final SafeZoneMonitor m = build();
      m.ingest(fixAt(north(kHome, 400)));
      m.ingest(fixAt(north(kHome, 400)));

      expect(m.metresOutside, closeTo(200, 2));
      // They walked north, so home is due south.
      expect(m.bearingHome, closeTo(180, 1));
      m.dispose();
    });

    test('a refused permission stops tracking before it starts', () async {
      location.outcome = LocationPermissionOutcome.permanentlyDenied;
      final SafeZoneMonitor m = build();

      final LocationPermissionOutcome outcome = await m.start();
      expect(outcome, LocationPermissionOutcome.permanentlyDenied);
      expect(m.isTracking, isFalse);
      expect(m.permission!.message, contains('Settings'));
      m.dispose();
    });

    test('start() takes a reading immediately rather than waiting to move',
        () async {
      location.initial = fixAt(north(kHome, 50));
      final SafeZoneMonitor m = build();

      await m.start();
      expect(m.isTracking, isTrue);
      expect(m.lastFix, isNotNull);
      expect(m.presence, SafeZonePresence.inside);
      m.dispose();
    });

    test('the event log is newest first and bounded', () {
      final SafeZoneMonitor m = build();
      for (int lap = 0; lap < 30; lap++) {
        m.ingest(fixAt(north(kHome, 400)));
        m.ingest(fixAt(north(kHome, 420)));
        m.ingest(fixAt(north(kHome, 100)));
      }
      expect(m.events.length, lessThanOrEqualTo(50));
      expect(m.events.first.kind, SafeZoneEventKind.returned);
      m.dispose();
    });
  });

  group('ReturnHomeBanner', () {
    Widget harness(AppState state, FakeLocationService location) => AppScope(
          state: state,
          child: MaterialApp(
            theme: AppTheme.warm(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReturnHomeBanner(
                location: location,
                child: const Center(child: Text('patient home')),
              ),
            ),
          ),
        );

    testWidgets('stays out of the way while the patient is inside',
        (WidgetTester tester) async {
      final AppState state = AppState()..setSafeZone(zoneOf());
      addTearDown(state.dispose);
      final FakeLocationService location =
          FakeLocationService(initial: fixAt(north(kHome, 50)));

      await tester.pumpWidget(harness(state, location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('patient home'), findsOneWidget);
      expect(find.text('Shall we head back?'), findsNothing);
    });

    testWidgets('asks gently, and never takes the screen over',
        (WidgetTester tester) async {
      final AppState state = AppState()..setSafeZone(zoneOf());
      addTearDown(state.dispose);
      final FakeLocationService location = FakeLocationService();

      await tester.pumpWidget(harness(state, location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Two confirming fixes, 400 m north of a 200 m zone.
      location.emit(north(kHome, 400));
      location.emit(north(kHome, 420));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Shall we head back?'), findsOneWidget);
      // They walked north, so home is south — and it is said in words.
      expect(find.textContaining('south'), findsOneWidget);
      expect(find.textContaining('200 metres'), findsOneWidget);
      // The rest of their app is still there underneath.
      expect(find.text('patient home'), findsOneWidget);
    });

    testWidgets('no zone means no banner and no GPS stream',
        (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      final FakeLocationService location = FakeLocationService();

      await tester.pumpWidget(harness(state, location));
      await tester.pump();

      expect(find.text('patient home'), findsOneWidget);
      // Never even asked for permission, because there is nothing to watch.
      expect(location.permissionAsks, 0);
    });
  });
}
