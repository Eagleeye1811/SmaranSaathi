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
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/ui_kit.dart';

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
            title: Text(AppLocalizations.of(context).removeSafeZoneConfirm),
            content: const Text(
              'You will stop being told when they leave. You can draw a new '
              'zone at any time.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(context).keepIt),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(AppLocalizations.of(context).remove),
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
    // No `Scaffold` and no `AppBar`: `CaregiverShell` already draws the
    // header above every page it hosts, and this screen wearing one of its
    // own put two titles on top of each other.
    //
    // The map is the page. It fills every pixel below the header — no wash,
    // no gutter, no card stacked above it pushing it down — and everything
    // else floats on top of it. A map of where someone is should not be a
    // panel in the middle of a screen about a map of where someone is.
    return AnimatedBuilder(
      animation: _monitor,
      builder: (BuildContext context, _) {
        final SafeZone? shown = _editing ? _draft : _monitor.zone;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: _MapView(
                controller: _map,
                zone: shown,
                fix: _monitor.lastFix,
                outside: _monitor.isOutside,
                // Tapping only moves the centre while editing, so a caregiver
                // panning the map cannot silently redraw the boundary they
                // are trying to look at.
                onTap: _editing
                    ? (GeoPoint p) => setState(() => _draft = _draft?.copyWith(centre: p))
                    : null,
              ),
            ),

            // ── Floating over the top ────────────────────────────────────
            //
            // Only what has something to say. With no zone drawn yet there is
            // nothing here at all: the button below already reads "Set a safe
            // zone", and a card repeating that in longer words was covering
            // the map to tell the caregiver what the map was for.
            Positioned(
              top: Insets.sm,
              left: Insets.gutter,
              right: Insets.gutter,
              // No top inset: this screen only ever renders inside
              // `CaregiverShell`, whose own header already clears the
              // status bar — the `Insets.sm` offset above is the only gap
              // this card needs from it.
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: <Widget>[
                    if (_monitor.permission != null && !_monitor.permission!.isGranted) ...<Widget>[
                      _PermissionNotice(
                        outcome: _monitor.permission!,
                        onRetry: _monitor.start,
                      ),
                      const SizedBox(height: Insets.sm),
                    ],
                    _StatusOverlay(monitor: _monitor),
                    if (_editing) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      const _HintPill(),
                    ],
                  ],
                ),
              ),
            ),

            // ── The map's own controls, then the sheet ───────────────────
            //
            // One bottom-anchored column, not two overlapping `Positioned`s.
            // The controls sheet is drawn last and is full width, so a
            // recentre button pinned to `bottom` sat *behind* it — present in
            // the tree, invisible on the screen. Stacking them means the
            // button clears the sheet whatever height it happens to be, which
            // changes between the idle and editing states.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, Insets.gutter, Insets.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _MapButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Zoom in',
                          onPressed: () => _map.move(_map.camera.center, _map.camera.zoom + 1),
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Zoom out',
                          onPressed: () => _map.move(_map.camera.center, _map.camera.zoom - 1),
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Centre on them',
                          onPressed: () {
                            final GeoPoint? here = _monitor.lastFix?.point;
                            if (here != null) {
                              _map.move(ll.LatLng(here.latitude, here.longitude), 16);
                            }
                          },
                        ),
                      ],
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
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A round control floating on the map: white, lifted, thumb-sized.
class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppColors.softShadow(y: 3, blur: 12, opacity: 0.18),
      ),
      child: RoundIconButton(
        icon: icon,
        size: 46,
        background: AppColors.surface,
        color: AppColors.primary,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// The tiles themselves — the only widget that knows `flutter_map` exists.
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

/// What the caregiver came to find out, floating over the map.
///
/// Deliberately small, and absent entirely when there is nothing to report.
/// A zone that has never been drawn says nothing here — the button at the
/// bottom of the screen already offers to draw one, and a card explaining
/// that was covering the very map it was explaining.
class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({required this.monitor});

  final SafeZoneMonitor monitor;

  @override
  Widget build(BuildContext context) {
    // Nothing drawn yet: the map speaks for itself.
    if (monitor.zone == null) return const SizedBox.shrink();

    // ── Out of bounds — the one state that earns a full-width alarm ─────
    if (monitor.isOutside) {
      return MmCard(
        padding: const EdgeInsets.all(Insets.md),
        color: AppColors.dangerTint,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        shadow: AppColors.softShadow(y: 4, blur: 16, opacity: 0.14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Outside the safe zone',
                      style: AppText.body.wght(800).tint(AppColors.danger)),
                  const SizedBox(height: 2),
                  Text(
                    '${monitor.metresOutside!.round()} m beyond ${monitor.zone!.label}.',
                    style: AppText.caption.tint(AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Everything else is one quiet line ───────────────────────────────
    final bool searching = monitor.lastFix == null;
    final Color color = searching ? AppColors.inkMuted : AppColors.success;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: Corners.r(Corners.pill),
          boxShadow: AppColors.softShadow(y: 3, blur: 12, opacity: 0.14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              searching
                  ? Icons.location_searching_rounded
                  : Icons.check_circle_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                searching
                    ? 'Looking for them…'
                    : 'Inside ${monitor.zone!.label} · ${_ago(monitor.lastFix!.at)}',
                style: AppText.caption.wght(700).tint(AppColors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

/// Says what a tap does, while a tap does something.
class _HintPill extends StatelessWidget {
  const _HintPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.95),
        borderRadius: Corners.r(Corners.pill),
        boxShadow: AppColors.softShadow(y: 3, blur: 12, opacity: 0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.touch_app_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Tap the map to move the middle',
              style: AppText.caption.wght(700).tint(Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom sheet of controls.
///
/// A rounded card lifted off the page rather than a flat white slab, and the
/// app's own buttons instead of Material's defaults, so the one screen that
/// used stock `FilledButton`/`OutlinedButton` now matches the rest.
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
  });

  final bool editing;
  final SafeZone? draft;
  final SafeZone? zone;
  final VoidCallback onStartEditing;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  /// The three distances a family actually picks between: the house and its
  /// yard, the street, the neighbourhood. The slider still covers everything
  /// in between — these just save a caregiver dragging to find them.
  static const List<(String, double)> _presets = <(String, double)>[
    ('House', 100),
    ('Street', 200),
    ('Area', 500),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Corners.lg)),
        boxShadow: AppColors.softShadow(y: -4, blur: 22, opacity: 0.08),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.md, Insets.gutter, Insets.md),
          child: editing && draft != null ? _editor(context) : _idle(context),
        ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final double radius = draft!.radiusMetres;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('How far can they go?', style: AppText.body.wght(800)),
            ),
            Text('${radius.round()} m',
                style: AppText.h3.sized(19).tint(AppColors.primary)),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Row(
          children: <Widget>[
            for (final (String label, double metres) preset in _presets)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _PresetChip(
                  label: preset.$1,
                  metres: preset.$2,
                  selected: radius.round() == preset.$2.round(),
                  onTap: () => onRadiusChanged(preset.$2),
                ),
              ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            trackHeight: 6,
          ),
          child: Slider(
            value: radius,
            min: SafeZone.minRadiusMetres,
            max: SafeZone.maxRadiusMetres,
            divisions: 39,
            onChanged: onRadiusChanged,
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftButton(
                label: 'Cancel',
                color: AppColors.inkSoft,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              flex: 2,
              child: BigButton(
                label: 'Save safe zone',
                icon: Icons.check_rounded,
                height: 54,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _idle(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BigButton(
          label: zone == null ? 'Set a safe zone' : 'Change zone',
          icon: zone == null
              ? Icons.add_location_alt_rounded
              : Icons.edit_location_alt_rounded,
          height: 54,
          onPressed: onStartEditing,
        ),
        if (zone != null) ...<Widget>[
          const SizedBox(height: Insets.xs),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            label: const Text('Remove the zone'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.metres,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double metres;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.normal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: Corners.r(Corners.pill),
        ),
        child: Text(
          '$label · ${metres.round()} m',
          style: AppText.caption
              .wght(800)
              .tint(selected ? Colors.white : AppColors.primary),
        ),
      ),
    );
  }
}

/// Location is off, and nothing on this screen can work until it is not.
class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.outcome, required this.onRetry});

  final LocationPermissionOutcome outcome;
  final Future<LocationPermissionOutcome> Function({int distanceFilterMetres}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      color: const Color(0xFFFEF3C7),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_off, color: Color(0xFFD97706)),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(outcome.message,
                style: AppText.bodySmall.tint(const Color(0xFF8A5D08))),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }
}
