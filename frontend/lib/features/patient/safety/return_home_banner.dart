import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/safety.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/safe_zone_monitor.dart';
import '../../../l10n/app_localizations.dart';

/// What the patient sees when they have wandered out of their safe zone.
///
/// A banner above their own screen rather than a full takeover, and that is a
/// deliberate clinical choice. Someone with dementia who is already
/// disoriented, suddenly presented with a red full-screen alarm they did not
/// ask for, becomes frightened — and a frightened person walks further, not
/// home. So: calm wording, their caregiver's name, the direction home, and one
/// large button that calls for help. No siren, no countdown, no blame.
///
/// It cannot be dismissed, because forgetting it a moment later is exactly the
/// condition this exists for.
class ReturnHomeBanner extends StatefulWidget {
  const ReturnHomeBanner({super.key, required this.child, this.location});

  final Widget child;

  /// Injected by tests and by the demo. Null in the app.
  final LocationService? location;

  @override
  State<ReturnHomeBanner> createState() => _ReturnHomeBannerState();
}

class _ReturnHomeBannerState extends State<ReturnHomeBanner> {
  late final AppState _state = AppScope.read(context);
  SafeZoneMonitor? _monitor;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _sync();
  }

  /// The monitor only exists while there is a zone to watch — no zone means no
  /// GPS stream and no battery cost.
  void _sync() {
    final SafeZone? zone = _state.safeZone;
    if (zone == null) {
      _monitor?.dispose();
      _monitor = null;
      return;
    }
    final SafeZoneMonitor? existing = _monitor;
    if (existing != null) {
      existing.setZone(zone);
      return;
    }
    final SafeZoneMonitor created = SafeZoneMonitor(
      location: widget.location ?? GeolocatorLocationService(),
      zone: zone,
      onLeft: (SafeZoneEvent e) {
        _state.recordSafeZoneEvent(e);
        unawaited(LocalNotificationService.instance.showPopUpNotification(
          id: 9101,
          title: '${_state.patient.name} has left ${e.zoneLabel}',
          body: '${e.distanceMetres.round()} m outside the safe zone.',
        ));
      },
      onReturned: _state.recordSafeZoneEvent,
    );
    _monitor = created;
    unawaited(created.start());
  }

  void _onStateChanged() {
    if (!mounted) return;
    // Only the zone matters here; every other AppState change is noise.
    if (_state.safeZone?.id != _monitor?.zone?.id ||
        _state.safeZone?.radiusMetres != _monitor?.zone?.radiusMetres) {
      setState(_sync);
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _monitor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SafeZoneMonitor? monitor = _monitor;
    if (monitor == null) return widget.child;

    return AnimatedBuilder(
      animation: monitor,
      builder: (BuildContext context, Widget? child) {
        if (!monitor.isOutside) return child!;
        return Column(
          children: <Widget>[
            _LetsHeadBack(
              zoneLabel: monitor.zone!.label,
              metresOut: monitor.metresOutside ?? 0,
              bearingHome: monitor.bearingHome,
              // The person they will actually recognise by name, rather than
              // the word "caregiver".
              caregiverName: _state.patient.primaryRelative?.name ?? 'Your family',
            ),
            Expanded(child: child!),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _LetsHeadBack extends StatelessWidget {
  const _LetsHeadBack({
    required this.zoneLabel,
    required this.metresOut,
    required this.bearingHome,
    required this.caregiverName,
  });

  final String zoneLabel;
  final double metresOut;
  final double? bearingHome;
  final String caregiverName;

  /// A compass bearing turned into a word, because "148°" means nothing to
  /// anyone and "south" means something to everyone.
  static String _headingWord(double bearing) {
    const List<String> names = <String>[
      'north', 'north-east', 'east', 'south-east',
      'south', 'south-west', 'west', 'north-west',
    ];
    return names[(((bearing + 22.5) % 360) ~/ 45)];
  }

  @override
  Widget build(BuildContext context) {
    final String direction =
        bearingHome == null ? '' : ' Home is to the ${_headingWord(bearingHome!)}.';

    return Material(
      color: AppColors.accentTint,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Transform.rotate(
                  angle: (bearingHome ?? 0) * 3.1415926535 / 180,
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppLocalizations.of(context).shallWeHeadBack, style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(
                      'You are a little way from $zoneLabel, about '
                      '${_round(metresOut)} away.$direction',
                      style: AppText.bodySmall.tint(AppColors.inkSoft),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      '$caregiverName has been told and is on the way.',
                      style: AppText.bodySmall.wght(700).tint(AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rounded to something a person can picture, not a false precision.
  static String _round(double metres) {
    if (metres < 100) return '${(metres / 10).round() * 10} metres';
    if (metres < 1000) return '${(metres / 50).round() * 50} metres';
    return '${(metres / 100).round() / 10} km';
  }
}
