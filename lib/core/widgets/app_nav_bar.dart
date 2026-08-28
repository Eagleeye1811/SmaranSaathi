import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

class NavDestination {
  const NavDestination(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// The app's bottom navigation.
///
/// Patient mode uses [large] — bigger icons, always-visible labels and a
/// generous 76 px bar — because small tab bars are one of the first things an
/// elderly user loses the ability to hit reliably.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.index,
    required this.onChanged,
    this.large = false,
    this.accent = AppColors.primary,
    this.background,
  });

  final List<NavDestination> destinations;
  final int index;
  final ValueChanged<int> onChanged;
  final bool large;
  final Color accent;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final double barHeight = large ? 78 : 64;
    return Container(
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        border: Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF3A2E1E).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == index,
                    large: large,
                    accent: accent,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.large,
    required this.accent,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool large;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? accent : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.r(Corners.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: Motion.normal,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                  horizontal: large ? 18 : 14, vertical: large ? 6 : 4),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: Corners.r(Corners.pill),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                size: large ? 27 : 23,
                color: color,
              ),
            ),
            SizedBox(height: large ? 5 : 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (large ? AppText.caption.sized(12.5) : AppText.caption.sized(11))
                  .tint(color)
                  .wght(selected ? 800 : 600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small connectivity pill. Tapping it toggles the simulated network so the
/// offline-first story can be demonstrated live.
class ConnectivityChip extends StatelessWidget {
  const ConnectivityChip({
    super.key,
    required this.offline,
    required this.pending,
    required this.onTap,
    this.syncing = false,
    this.dark = false,
  });

  final bool offline;
  final int pending;
  final VoidCallback onTap;
  final bool syncing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color color = offline ? AppColors.warning : AppColors.success;
    final String label = offline
        ? (pending > 0 ? 'Offline · $pending' : 'Offline')
        : (syncing ? 'Syncing…' : (pending > 0 ? '$pending to sync' : 'Online'));

    return Tooltip(
      message: offline
          ? 'Simulated offline mode — tap to reconnect'
          : 'Connected — tap to simulate going offline',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.normal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: dark ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.12),
            borderRadius: Corners.r(Corners.pill),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (syncing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(
                  offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                  size: 15,
                  color: color,
                ),
              const SizedBox(width: 6),
              Text(label, style: AppText.caption.sized(12).wght(700).tint(color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width banner shown under the header while offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pending, this.visible = true});

  final int pending;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.normal,
      curve: Curves.easeOutCubic,
      child: visible
          ? Container(
              margin: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: Corners.r(Corners.md),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Offline mode',
                            style: AppText.body.wght(800).tint(const Color(0xFF8A5D08))),
                        const SizedBox(height: 2),
                        Text(
                          pending > 0
                              ? 'Everything still works. $pending activities are waiting to sync.'
                              : 'Everything still works. All activities are saved on this device.',
                          style: AppText.bodySmall.tint(const Color(0xFF8A5D08)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
