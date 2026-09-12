import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../alerts/doctor_alerts_screen.dart';
import '../profile/doctor_profile_screen.dart';

/// Clinician typography — the warm palette's ink swapped for the cooler
/// clinical one, so the two experiences never look like the same product.
class CT {
  const CT._();
  static TextStyle get h1 => AppText.h1.tint(AppColors.clinicInk);
  static TextStyle get h2 => AppText.h2.tint(AppColors.clinicInk);
  static TextStyle get h3 => AppText.h3.tint(AppColors.clinicInk);
  static TextStyle get body => AppText.body.tint(AppColors.clinicInk);
  static TextStyle get bodySmall => AppText.bodySmall.tint(AppColors.clinicInkSoft);
  static TextStyle get label => AppText.label.tint(AppColors.clinicInkSoft);
  static TextStyle get overline => AppText.overline.tint(AppColors.clinicInkSoft);
  static TextStyle get caption => AppText.caption.tint(AppColors.clinicInkSoft);
  static TextStyle get stat => AppText.stat.tint(AppColors.clinicInk);
  static TextStyle get statLarge => AppText.statLarge.tint(AppColors.clinicInk);
}

/// Denser, cooler card for clinician surfaces.
class ClinicCard extends StatelessWidget {
  const ClinicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.onTap,
    this.accentEdge,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accentEdge;

  @override
  Widget build(BuildContext context) {
    // The status edge is painted inside the card rather than laid out beside
    // it: a `CrossAxisAlignment.stretch` Row would be handed an unbounded
    // height inside a scroll view.
    final Widget body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.clinicSurface,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.clinicHairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1B2430).withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: accentEdge == null
                ? padding
                : padding.add(const EdgeInsets.only(left: 10)),
            child: child,
          ),
          if (accentEdge != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accentEdge!),
            ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Pressable(onTap: onTap, scale: 0.99, child: body);
  }
}

/// Header for clinician screens, styled cleanly with circular Bell and Profile action buttons.
class ClinicTopBar extends StatelessWidget {
  const ClinicTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.showAlerts = true,
    this.showProfile = true,
    this.trailing,
    this.onAlerts,
    this.onProfile,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final bool showAlerts;
  final bool showProfile;
  final Widget? trailing;
  final VoidCallback? onAlerts;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);

    final bool hasAlerts = state.alerts.any((DoctorAlert a) => a.severity == AlertSeverity.urgent) ||
        state.connectionRequests.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 10),
      child: Row(
        children: <Widget>[
          if (showBack) ...<Widget>[
            _CircularBarButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: CT.h1.sized(26).wght(800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: CT.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            trailing!,
            const SizedBox(width: 10),
          ],
          if (showAlerts) ...<Widget>[
            _CircularBarButton(
              icon: Icons.notifications_none_rounded,
              tooltip: l.doctorTabAlerts,
              hasBadge: hasAlerts,
              onPressed: onAlerts ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DoctorAlertsScreen(),
                      ),
                    );
                  },
            ),
          ],
          if (showProfile) ...<Widget>[
            const SizedBox(width: 10),
            _CircularBarButton(
              icon: Icons.person_outline_rounded,
              tooltip: l.doctorTabProfile,
              onPressed: onProfile ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DoctorProfileScreen(),
                      ),
                    );
                  },
            ),
          ],
        ],
      ),
    );
  }
}

class _CircularBarButton extends StatelessWidget {
  const _CircularBarButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.hasBadge = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.clinicSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.clinicHairline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, size: 22, color: AppColors.clinicInk),
              if (hasBadge)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE55D3E),
                      shape: BoxShape.circle,
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

/// A compact KPI block.
class ClinicStat extends StatelessWidget {
  const ClinicStat({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.clinicAccent,
    this.caption,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(label.toUpperCase(),
                  style: CT.overline.sized(10), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(value, style: CT.statLarge.sized(27).tint(color)),
        if (caption != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(caption!, style: CT.caption.sized(11.5)),
        ],
      ],
    );
  }
}

/// Status colour used consistently across the clinician surfaces.
Color statusColor(ClinicalStatus s) => switch (s) {
      ClinicalStatus.stable => AppColors.success,
      ClinicalStatus.needsAttention => AppColors.danger,
      ClinicalStatus.followUp => AppColors.warning,
    };

Color trendColor(TrendDirection t) => switch (t) {
      TrendDirection.up => AppColors.success,
      TrendDirection.flat => AppColors.clinicInkSoft,
      TrendDirection.down => AppColors.danger,
    };

Color severityColor(AlertSeverity s) => switch (s) {
      AlertSeverity.info => AppColors.clinicAccent,
      AlertSeverity.watch => AppColors.warning,
      AlertSeverity.urgent => AppColors.danger,
    };

IconData severityIcon(AlertSeverity s) => switch (s) {
      AlertSeverity.info => Icons.info_outline_rounded,
      AlertSeverity.watch => Icons.visibility_rounded,
      AlertSeverity.urgent => Icons.priority_high_rounded,
    };

/// Status chip that always pairs colour with an icon and a word, never colour
/// alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final ClinicalStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color c = statusColor(status);
    final IconData icon = switch (status) {
      ClinicalStatus.stable => Icons.check_circle_rounded,
      ClinicalStatus.needsAttention => Icons.error_rounded,
      ClinicalStatus.followUp => Icons.schedule_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: Corners.r(Corners.pill),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(status.localizedLabel(l), style: CT.caption.sized(11.5).wght(700).tint(c)),
        ],
      ),
    );
  }
}
