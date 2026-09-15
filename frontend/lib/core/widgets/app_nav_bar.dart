import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

import 'voice_nav_host.dart';

class NavDestination {
  const NavDestination(this.label, this.icon, this.activeIcon, {this.badgeCount = 0});
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;
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
    this.showMic = true,
  });

  final List<NavDestination> destinations;
  final int index;
  final ValueChanged<int> onChanged;
  final bool large;
  final Color accent;
  final Color? background;
  final bool showMic;

  @override
  Widget build(BuildContext context) {
    final double barHeight = large ? 62 : 58;
    final VoiceNavHostState? voiceNav = VoiceNavScope.maybeOf(context);
    final bool enableMic = showMic && voiceNav != null;
    const double bulge = 22.0;
    const double micDiameter = 64.0;

    Widget navRow;
    if (enableMic && destinations.length == 4) {
      navRow = Row(
        children: <Widget>[
          Expanded(
            child: _NavItem(
              destination: destinations[0],
              selected: 0 == index,
              large: large,
              accent: accent,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              destination: destinations[1],
              selected: 1 == index,
              large: large,
              accent: accent,
              onTap: () => onChanged(1),
            ),
          ),
          // Wider than the mic's own footprint (64 diameter + 4+4 border =
          // 72), not just equal to it — with zero margin, the item on
          // either side only had to grow a few points at a larger text
          // size before its icon (a fixed size, not part of what shrinks
          // to fit) crossed into the mic's own space.
          const SizedBox(width: 96),
          Expanded(
            child: _NavItem(
              destination: destinations[2],
              selected: 2 == index,
              large: large,
              accent: accent,
              onTap: () => onChanged(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              destination: destinations[3],
              selected: 3 == index,
              large: large,
              accent: accent,
              onTap: () => onChanged(3),
            ),
          ),
        ],
      );
    } else {
      navRow = Row(
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
      );
    }

    final Widget barContent = Container(
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: SizedBox(
            height: barHeight,
            child: navRow,
          ),
        ),
      ),
    );

    if (!enableMic) {
      return barContent;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: bulge),
          child: barContent,
        ),
        Positioned(
          top: 0,
          child: VoiceMicButton(
            accent: accent,
            diameter: micDiameter,
            iconSize: 32,
            elevation: 6,
            borderWidth: 4.0,
            borderColor: background ?? Colors.white,
            onTap: voiceNav.openPanel,
          ),
        ),
      ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: Motion.normal,
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                    horizontal: large ? 10 : 8, vertical: large ? 4 : 3),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: Corners.r(Corners.pill),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Icon(
                      selected ? destination.activeIcon : destination.icon,
                      size: large ? 24 : 22,
                      color: color,
                    ),
                    if (destination.badgeCount > 0)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${destination.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: (large ? AppText.caption.sized(11) : AppText.caption.sized(10.5))
                        .tint(color)
                        .wght(selected ? 800 : 600),
                  ),
                ),
              ),
            ],
          ),
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
    final AppLocalizations l = AppLocalizations.of(context);
    final Color color = offline ? AppColors.warning : AppColors.success;
    final String label = offline
        ? (pending > 0 ? l.syncChipOfflineCount(pending) : l.syncChipOffline)
        : (syncing ? l.syncChipSyncing : (pending > 0 ? l.syncChipPending(pending) : l.syncChipOnline));

    return Tooltip(
      message: offline
          ? l.syncChipTooltipOffline
          : l.syncChipTooltipOnline,
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
    final AppLocalizations l = AppLocalizations.of(context);
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
                        Text(l.offlineBannerTitle,
                            style: AppText.body.wght(800).tint(const Color(0xFF8A5D08))),
                        const SizedBox(height: 2),
                        Text(
                          pending > 0
                              ? l.offlineBannerBodyPending(pending)
                              : l.offlineBannerBodyAllSynced,
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
