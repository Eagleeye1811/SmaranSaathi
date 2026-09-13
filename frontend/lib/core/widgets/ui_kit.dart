import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

/// Scales its child down slightly while pressed — the app's single, consistent
/// tactile feedback gesture.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.968,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The app's one card. Every raised surface in SmaranSaathi is one of these.
class MmCard extends StatelessWidget {
  const MmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.color,
    this.gradient,
    this.radius = Corners.lg,
    this.onTap,
    this.border,
    this.shadow,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Theme.of(context).colorScheme.surface) : null,
        gradient: gradient,
        borderRadius: Corners.r(radius),
        border: border ?? Border.all(color: AppColors.hairline.withValues(alpha: 0.9)),
        boxShadow: shadow ?? AppColors.softShadow(),
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );
    if (onTap == null) return body;
    return Pressable(onTap: onTap, child: body);
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.icon,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: (dense ? AppText.h3 : AppText.h2).tint(ink)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppText.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(action!),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small status / category chip.
class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.background,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 12, vertical: dense ? 4 : 7),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: Corners.r(Corners.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 13 : 15, color: color),
            const SizedBox(width: 5),
          ],
          // Flexible so a long label shrinks instead of overflowing the row
          // it sits in — tags carry patient-authored text in several places.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? AppText.caption : AppText.label).tint(color).wght(700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon inside a soft tinted rounded square.
class SoftIcon extends StatelessWidget {
  const SoftIcon({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background,
    this.size = 46,
    this.iconSize,
    this.radius,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double? iconSize;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: Corners.r(radius ?? size * 0.34),
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}

/// Animated ring gauge with free-form centre content.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.stroke = 10,
    this.color = AppColors.primary,
    this.trackColor,
    this.center,
    this.duration = const Duration(milliseconds: 900),
  });

  /// 0..1
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color? trackColor;
  final Widget? center;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double v, Widget? child) {
          return CustomPaint(
            painter: _RingPainter(
              value: v,
              stroke: stroke,
              color: color,
              track: trackColor ?? color.withValues(alpha: 0.13),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(stroke + 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: center,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(stroke / 2);
    final Paint bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, 6.2832, false, bg);

    final Paint fg = Paint()
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: <Color>[color.withValues(alpha: 0.65), color],
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -1.5708, 6.2832 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Animated linear meter.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color = AppColors.primary,
    this.background,
    this.duration = const Duration(milliseconds: 800),
  });

  final double value;
  final double height;
  final Color color;
  final Color? background;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Corners.r(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double v, _) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: background ?? color.withValues(alpha: 0.14)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[color.withValues(alpha: 0.72), color],
                        ),
                        borderRadius: Corners.r(height),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A metric with a label, big number and optional meter.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.meter,
    this.color = AppColors.primary,
    this.icon,
    this.trailing,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final double? meter;
  final Color color;
  final IconData? icon;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(label,
                  style: AppText.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact ? AppText.stat : AppText.statLarge).tint(color),
              ),
            ),
            if (suffix != null) ...<Widget>[
              const SizedBox(width: 3),
              Text(suffix!, style: AppText.label.tint(color.withValues(alpha: 0.75))),
            ],
          ],
        ),
        if (meter != null) ...<Widget>[
          const SizedBox(height: 10),
          MeterBar(value: meter!, color: color, height: 7),
        ],
      ],
    );
  }
}

/// ●●○○○ difficulty indicator.
class DifficultyDots extends StatelessWidget {
  const DifficultyDots({
    super.key,
    required this.level,
    this.max = 5,
    this.color = AppColors.primary,
    this.size = 9,
  });

  final int level;
  final int max;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(max, (int i) {
        final bool on = i < level;
        return AnimatedContainer(
          duration: Motion.normal,
          margin: EdgeInsets.only(right: i == max - 1 ? 0 : size * 0.45),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? color : color.withValues(alpha: 0.18),
          ),
        );
      }),
    );
  }
}

/// The oversized, high-contrast button used everywhere in patient mode.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.foreground = Colors.white,
    this.outlined = false,
    this.expand = true,
    this.height = 68,
    this.emoji,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool outlined;
  final bool expand;
  final double height;
  final String? emoji;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget content = Container(
      constraints: BoxConstraints(minHeight: subtitle == null ? height : 0),
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: outlined ? Colors.white : (enabled ? color : color.withValues(alpha: 0.35)),
        borderRadius: Corners.r(Corners.pill),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.45), width: 2) : null,
        boxShadow: outlined || !enabled
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (emoji != null) ...<Widget>[
            Text(emoji!, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, color: outlined ? color : foreground, size: 24),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  textAlign: subtitle == null ? TextAlign.center : TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.patientButton.tint(outlined ? color : foreground),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: AppText.bodySmall
                          .tint((outlined ? color : foreground).withValues(alpha: 0.82))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return Pressable(onTap: onPressed, scale: 0.975, child: content);
  }
}

/// Compact secondary action used inside cards.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: Corners.r(Corners.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: filled ? Colors.white : color),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.wght(700).tint(filled ? Colors.white : color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row entry with an illustration/icon on the left.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: AppText.body.wght(700).tint(Theme.of(context).colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: AppText.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, scale: 0.985, child: row);
  }
}

/// Slide-and-fade entrance used to stagger content on screen load.
class FadeInUp extends StatelessWidget {
  const FadeInUp({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offset = 18,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final int delayMs;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + Duration(milliseconds: delayMs),
      curve: Interval(
        delayMs / (duration.inMilliseconds + delayMs),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (BuildContext context, double t, Widget? c) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: c),
        );
      },
      child: child,
    );
  }
}

/// A friendly empty state — never a bare screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome_rounded,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SoftIcon(icon: icon, size: 72, color: AppColors.primarySoft),
            const SizedBox(height: Insets.lg),
            Text(title, style: AppText.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppText.bodySmall, textAlign: TextAlign.center),
            if (action != null) ...<Widget>[const SizedBox(height: Insets.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// Screen scaffold with a large warm title and consistent gutters.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(eyebrow!.toUpperCase(), style: AppText.overline),
                  const SizedBox(height: 5),
                ],
                Text(title, style: AppText.h1.tint(ink)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppText.body.tint(AppColors.inkSoft)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Circular icon button used for back / close actions.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 48,
    this.color,
    this.background,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? background;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = Pressable(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppColors.softShadow(y: 3, blur: 10, opacity: 0.05),
        ),
        child: Icon(icon, size: size * 0.48, color: color ?? AppColors.ink),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Trend pill shown on cognitive domain cards.
/// [direction]: 1 = improving, 0 = stable, -1 = needs attention.
class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key, required this.direction, this.dense = false});

  final int direction; // 1 up, 0 flat, -1 down
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color color = direction > 0
        ? AppColors.success
        : direction < 0
            ? AppColors.warning
            : AppColors.secondary;
    final IconData icon = direction > 0
        ? Icons.trending_up_rounded
        : direction < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final String label = direction > 0
        ? 'Improving'
        : direction < 0
            ? 'Worth watching'
            : 'Stable';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: Corners.r(Corners.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: dense ? 13 : 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: (dense ? AppText.caption : AppText.label).wght(700).tint(color)),
          ],
        ),
      ),
    );
  }
}

/// A card section that surfaces an AI-generated insight with a transparent label
/// and disclaimer footer so the user always knows it is AI, not a diagnosis.
class AiInsightBanner extends StatelessWidget {
  const AiInsightBanner({
    super.key,
    required this.insight,
    this.color = AppColors.primary,
    this.disclaimer =
        'AI-observed pattern, for context only. Not a medical diagnosis.',
  });

  final String insight;
  final Color color;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Text('AI Insight', style: AppText.label.wght(800).tint(color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(insight, style: AppText.bodySmall),
          const SizedBox(height: 8),
          Text(disclaimer,
              style: AppText.caption.tint(AppColors.inkMuted).copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// Small inline chip showing offline / sync status.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.label, this.isOffline = false});

  final String label;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final Color color = isOffline ? AppColors.warning : AppColors.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: Corners.r(Corners.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
              size: 12,
              color: color),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption.tint(color)),
        ],
      ),
    );
  }
}

