import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/ui_kit.dart';

/// Colour for a direction of change.
///
/// Note what is *not* here: a red for "bad". A score moving down is a signal
/// to look at, not a failure, and colouring it like an error turns a
/// monitoring app into an alarm the person stops opening.
Color trendColor(TrendDirection t) => switch (t) {
      TrendDirection.up => AppColors.success,
      TrendDirection.flat => AppColors.inkMuted,
      TrendDirection.down => AppColors.accent,
    };

/// One domain: where it is now, where it started, and which way it moved.
class DomainRow extends StatelessWidget {
  const DomainRow({
    super.key,
    required this.reading,
    this.showSparkline = true,
    this.onTap,
  });

  final DomainReading reading;
  final bool showSparkline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = trendColor(reading.trend);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: MmCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                SoftIcon(
                  icon: reading.domain.icon,
                  size: 42,
                  color: AppColors.primary,
                  background: AppColors.primaryTint,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(reading.domain.clinicalLabel,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        reading.hasReading ? reading.deltaLabel : 'Not yet assessed',
                        style: AppText.caption.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                if (showSparkline && reading.history.length > 1) ...<Widget>[
                  Sparkline(values: reading.history, color: color, width: 58, height: 26),
                  const SizedBox(width: Insets.md),
                ],
                Text(
                  reading.hasReading ? '${reading.current!.round()}' : '—',
                  style: AppText.stat,
                ),
                const SizedBox(width: 6),
                Icon(reading.trend.icon, size: 18, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An observed pattern with its reasoning always visible.
class PatternRow extends StatelessWidget {
  const PatternRow({super.key, required this.pattern});

  final ObservedPattern pattern;

  Color get _color => switch (pattern.level) {
        PatternLevel.notPresent => AppColors.inkMuted,
        PatternLevel.low => AppColors.secondary,
        PatternLevel.moderate => AppColors.accent,
        PatternLevel.high => AppColors.terracotta,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: MmCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(pattern.label,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ),
                PillTag(label: pattern.level.label, color: _color, dense: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(pattern.rationale, style: AppText.caption.copyWith(height: 1.45)),
          ],
        ),
      ),
    );
  }
}

/// The headline card: overall direction, in one sentence, with the caveat
/// attached rather than a screen away.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.snapshot, this.onViewProfile});

  final MonitoringSnapshot snapshot;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final Color color = trendColor(snapshot.statusTrend);
    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      color: AppColors.surface,
      border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Wrap rather than Row: at extra-large text the label and the trend
          // pill together are wider than a small phone, and the pill dropping
          // to a second line is better than either being clipped.
          Wrap(
            spacing: Insets.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Cognitive health', style: AppText.overline),
              PillTag(
                label: snapshot.statusLabel,
                color: color,
                icon: snapshot.statusTrend.icon,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                snapshot.overallCurrent == null
                    ? '—'
                    : '${snapshot.overallCurrent!.round()}',
                style: AppText.statHuge,
              ),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    snapshot.overallBaseline == null
                        ? 'first result'
                        : 'vs baseline ${snapshot.overallBaseline!.round()}',
                    style: AppText.bodySmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(snapshot.headline, style: AppText.body.copyWith(height: 1.5)),
          if (onViewProfile != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            SoftButton(
              label: 'View cognitive profile',
              icon: Icons.insights_rounded,
              onPressed: onViewProfile,
            ),
          ],
        ],
      ),
    );
  }
}
