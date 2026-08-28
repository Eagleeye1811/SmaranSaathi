import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/ui_kit.dart';

/// Header shared by every caregiver screen.
class CaregiverTopBar extends StatelessWidget {
  const CaregiverTopBar({super.key, this.title, this.subtitle, this.showBrand = true});

  final String? title;
  final String? subtitle;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (showBrand) ...<Widget>[
            const BrandMark(size: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title ?? 'MemoryMitra',
                    style: AppText.h3.wght(800), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: AppText.caption),
                ],
              ],
            ),
          ),
          ConnectivityChip(
            offline: state.offline,
            pending: state.pendingSync,
            syncing: state.syncing,
            onTap: () {
              final bool goingOnline = state.offline;
              state.setOffline(!state.offline);
              if (goingOnline) state.syncNow();
            },
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.logout_rounded,
            size: 38,
            tooltip: 'Switch role',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// A labelled figure used across the caregiver dashboard.
class OverviewRow extends StatelessWidget {
  const OverviewRow({
    super.key,
    required this.label,
    required this.value,
    this.meter,
    this.color = AppColors.primary,
    this.icon,
    this.badge,
  });

  final String label;
  final String value;
  final double? meter;
  final Color color;
  final IconData? icon;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    // Label and value share the first line; the meter gets its own full-width
    // line below so long labels never have to compete with it.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(label,
                    style: AppText.body.wght(600).tint(AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              if (badge != null)
                badge!
              else
                Text(value, style: AppText.body.wght(800).tint(color)),
            ],
          ),
          if (meter != null) ...<Widget>[
            const SizedBox(height: 9),
            MeterBar(value: meter!, color: color, height: 7),
          ],
        ],
      ),
    );
  }
}
