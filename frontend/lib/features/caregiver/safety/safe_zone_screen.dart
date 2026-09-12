import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/safety.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/safe_zone_monitor.dart';
import '../../../l10n/app_localizations.dart';

/// The caregiver's safe-zone map.
///
/// One screen doing two jobs that belong together: *drawing* the boundary and
/// *watching* it. Splitting them would mean a caregiver who wants to widen the
/// zone because the patient is 30 m outside has to leave the screen showing
/// where they are.
///
/// OpenStreetMap tiles, so there is no API key, no billing account and nothing
/// to configure before the map draws. Swapping to Google later touches only
/// [_MapView].
class SafeZoneScreen extends StatefulWidget {
  const SafeZoneScreen({super.key, this.location});

  /// Injected by tests and by the demo. Null in the app, where the real
  /// device GPS is used.
  final LocationService? location;

  @override
  State<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends State<SafeZoneScreen> {
  late final AppState _state = AppScope.read(context);
  late final SafeZoneMonitor _monitor;
  final MapController _map = MapController();

  /// The zone being edited, which is not committed until Save — a caregiver
  /// dragging the radius around should not be alarming themselves with every
  /// intermediate value.
  SafeZone? _draft;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _monitor = SafeZoneMonitor(
      location: widget.location ?? GeolocatorLocationService(),
      zone: _state.safeZone,
      onLeft: _onLeft,
      onReturned: _onReturned,
    );
    unawaited(_monitor.start());
  }

  /// The alert. A notification *and* a record, because a caregiver with the
  /// phone in their pocket needs the banner, and one who opens the app an hour
  /// later needs the history.
  void _onLeft(SafeZoneEvent event) {
    _state.recordSafeZoneEvent(event);
    unawaited(LocalNotificationService.instance.showPopUpNotification(
      id: 9101,
      title: '${_state.patient.name} has left ${event.zoneLabel}',
      body: '${event.distanceMetres.round()} m outside the safe zone. '
          'Tap to see where they are.',
    ));
  }

  void _onReturned(SafeZoneEvent event) {
    _state.recordSafeZoneEvent(event);
    unawaited(LocalNotificationService.instance.showPopUpNotification(
      id: 9102,
      title: '${_state.patient.name} is back safe',
      body: 'They have returned to ${event.zoneLabel}.',
    ));
  }

  @override
  void dispose() {
    _monitor.dispose();
    super.dispose();
  }

  /// Starts editing from the existing zone, or drops a new one where the
  /// patient is standing — which is nearly always the right first guess.
  void _startEditing() {
    final GeoPoint? here = _monitor.lastFix?.point;
    setState(() {
      _editing = true;
      _draft = _monitor.zone ??
          SafeZone(
            id: 'zone-${DateTime.now().millisecondsSinceEpoch}',
            label: 'Home',
            centre: here ?? const GeoPoint(26.7509, 94.2037),
            radiusMetres: SafeZone.defaultRadiusMetres,
            createdAtIso: DateTime.now().toIso8601String(),
          );
    });
  }

  void _save() {
    final SafeZone? draft = _draft;
    if (draft == null) return;
    _state.setSafeZone(draft);
    _monitor.setZone(draft);
    setState(() => _editing = false);
  }

  Future<void> _remove() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.removeSafeZoneConfirm),
            content: const Text(
              'You will stop being told when they leave. You can draw a new '
              'zone at any time.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(context)!.keepIt),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(AppLocalizations.of(context)!.remove),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    _state.setSafeZone(null);
    _monitor.setZone(null);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.safeZone),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: _monitor,
        builder: (BuildContext context, _) {
          final SafeZone? shown = _editing ? _draft : _monitor.zone;
          return Column(
            children: <Widget>[
              if (_monitor.permission != null && !_monitor.permission!.isGranted)
                _PermissionNotice(outcome: _monitor.permission!, onRetry: _monitor.start),
              _StatusStrip(monitor: _monitor),
              Expanded(
                child: _MapView(
                  controller: _map,
                  zone: shown,
                  fix: _monitor.lastFix,
                  outside: _monitor.isOutside,
                  // Tapping only moves the centre while editing, so a
                  // caregiver panning the map cannot silently redraw the
                  // boundary they are trying to look at.
                  onTap: _editing
                      ? (GeoPoint p) => setState(() => _draft = _draft?.copyWith(centre: p))
                      : null,
                ),
              ),
              _Controls(
                editing: _editing,
                draft: _draft,
                zone: _monitor.zone,
                onStartEditing: _startEditing,
                onRadiusChanged: (double r) =>
                    setState(() => _draft = _draft?.copyWith(radiusMetres: r)),
                onSave: _save,
                onCancel: () => setState(() => _editing = false),
                onRemove: _remove,
                onRecentre: () {
                  final GeoPoint? here = _monitor.lastFix?.point;
                  if (here != null) _map.move(ll.LatLng(here.latitude, here.longitude), 16);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The map itself — the only widget that knows `flutter_map` exists.
class _MapView extends StatelessWidget {
  const _MapView({
    required this.controller,
    required this.zone,
    required this.fix,
    required this.outside,
    this.onTap,
  });

  final MapController controller;
  final SafeZone? zone;
  final LocationFix? fix;
  final bool outside;
  final void Function(GeoPoint point)? onTap;

  @override
  Widget build(BuildContext context) {
    final GeoPoint centre =
        fix?.point ?? zone?.centre ?? const GeoPoint(26.7509, 94.2037);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: ll.LatLng(centre.latitude, centre.longitude),
        initialZoom: 15,
        onTap: onTap == null
            ? null
            : (TapPosition _, ll.LatLng p) => onTap!(GeoPoint(p.latitude, p.longitude)),
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OSM's tile policy requires an identifying agent. Without it the
          // tiles are served slowly or not at all.
          userAgentPackageName: 'com.memorymitra.app',
        ),
        if (zone != null)
          CircleLayer<Object>(
            circles: <CircleMarker<Object>>[
              CircleMarker<Object>(
                point: ll.LatLng(zone!.centre.latitude, zone!.centre.longitude),
                radius: zone!.radiusMetres,
                // Metres, not pixels — the circle has to stay the same size on
                // the ground as the caregiver zooms.
                useRadiusInMeter: true,
                color: (outside ? AppColors.danger : AppColors.primary)
                    .withValues(alpha: 0.14),
                borderColor: outside ? AppColors.danger : AppColors.primary,
                borderStrokeWidth: 2.5,
              ),
            ],
          ),
        if (fix != null)
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: ll.LatLng(fix!.point.latitude, fix!.point.longitude),
                width: 44,
                height: 44,
                child: _PatientPin(outside: outside),
              ),
            ],
          ),
      ],
    );
  }
}

class _PatientPin extends StatelessWidget {
  const _PatientPin({required this.outside});

  final bool outside;

  @override
  Widget build(BuildContext context) {
    final Color color = outside ? AppColors.danger : AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
    );
  }
}

/// One line saying the thing the caregiver actually came to find out.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.monitor});

  final SafeZoneMonitor monitor;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String detail;

    if (monitor.zone == null) {
      color = AppColors.inkMuted;
      icon = Icons.add_location_alt_outlined;
      title = 'No safe zone yet';
      detail = 'Draw one so you are told if they wander.';
    } else if (monitor.isOutside) {
      color = AppColors.danger;
      icon = Icons.warning_amber_rounded;
      title = 'Outside the safe zone';
      detail = '${monitor.metresOutside!.round()} m beyond ${monitor.zone!.label}.';
    } else if (monitor.lastFix == null) {
      color = AppColors.inkMuted;
      icon = Icons.location_searching_rounded;
      title = 'Looking for them…';
      detail = 'Waiting for the first location.';
    } else {
      color = AppColors.success;
      icon = Icons.check_circle_outline_rounded;
      title = 'Inside ${monitor.zone!.label}';
      detail = 'Last seen ${_ago(monitor.lastFix!.at)}.';
    }

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.body.wght(800).tint(color)),
                Text(detail, style: AppText.caption.tint(AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime? at) {
    if (at == null) return 'just now';
    final Duration d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.editing,
    required this.draft,
    required this.zone,
    required this.onStartEditing,
    required this.onRadiusChanged,
    required this.onSave,
    required this.onCancel,
    required this.onRemove,
    required this.onRecentre,
  });

  final bool editing;
  final SafeZone? draft;
  final SafeZone? zone;
  final VoidCallback onStartEditing;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onRecentre;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: editing && draft != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.tapMapToMoveMiddle,
                        style: AppText.bodySmall.tint(AppColors.inkSoft)),
                    const SizedBox(height: Insets.xs),
                    Row(
                      children: <Widget>[
                        Text(l.howFarCanTheyGo, style: AppText.body.wght(700)),
                        const Spacer(),
                        Text('${draft!.radiusMetres.round()} m',
                            style: AppText.body.wght(800).tint(AppColors.primary)),
                      ],
                    ),
                    Slider(
                      value: draft!.radiusMetres,
                      min: SafeZone.minRadiusMetres,
                      max: SafeZone.maxRadiusMetres,
                      divisions: 39,
                      onChanged: onRadiusChanged,
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            child: Text(l.cancel),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: onSave,
                            child: Text(l.saveSafeZone),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onStartEditing,
                        icon: Icon(zone == null
                            ? Icons.add_location_alt_rounded
                            : Icons.edit_location_alt_rounded),
                        label: Text(zone == null ? 'Set a safe zone' : 'Change zone'),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    IconButton.filledTonal(
                      onPressed: onRecentre,
                      tooltip: 'Centre on them',
                      icon: const Icon(Icons.my_location_rounded),
                    ),
                    if (zone != null)
                      IconButton(
                        onPressed: onRemove,
                        tooltip: 'Remove the zone',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.outcome, required this.onRetry});

  final LocationPermissionOutcome outcome;
  final Future<LocationPermissionOutcome> Function({int distanceFilterMetres}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningTint,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_off_rounded, color: AppColors.warning),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(outcome.message,
                style: AppText.bodySmall.tint(const Color(0xFF8A5D08))),
          ),
          TextButton(onPressed: () => onRetry(), child: Text(AppLocalizations.of(context)!.retry)),
        ],
      ),
    );
  }
}
