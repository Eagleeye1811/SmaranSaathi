import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Gentle confetti for game completions. Deliberately soft and slow — this is
/// a celebration for an elderly user, not an arcade payout.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.count = 46,
    this.duration = const Duration(milliseconds: 3200),
    this.seed = 7,
  });

  final int count;
  final Duration duration;
  final int seed;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..forward();
    final math.Random r = math.Random(widget.seed);
    const List<Color> palette = <Color>[
      AppColors.accent,
      AppColors.primarySoft,
      AppColors.terracotta,
      AppColors.secondarySoft,
      AppColors.plum,
      Color(0xFFF3D06B),
    ];
    _pieces = List<_Piece>.generate(widget.count, (int i) {
      return _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        size: 6 + r.nextDouble() * 8,
        drift: (r.nextDouble() - 0.5) * 0.34,
        spin: (r.nextDouble() - 0.5) * 7,
        color: palette[i % palette.length],
        shape: i % 3,
        speed: 0.72 + r.nextDouble() * 0.5,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, _) =>
              CustomPaint(painter: _ConfettiPainter(_pieces, _c.value), size: Size.infinite),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.size,
    required this.drift,
    required this.spin,
    required this.color,
    required this.shape,
    required this.speed,
  });

  final double x;
  final double delay;
  final double size;
  final double drift;
  final double spin;
  final Color color;
  final int shape;
  final double speed;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Piece p in pieces) {
      final double local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final double eased = local * p.speed;
      final double y = -30 + eased * (size.height + 90);
      if (y > size.height + 30) continue;
      final double x = size.width * p.x + math.sin(local * math.pi * 2.2) * p.drift * size.width;
      final double fade = local > 0.82 ? (1 - local) / 0.18 : 1.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin * math.pi);
      final Paint paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0, 1));
      switch (p.shape) {
        case 0:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
              const Radius.circular(2),
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
        default:
          canvas.drawPath(
            Path()
              ..moveTo(0, -p.size * 0.5)
              ..lineTo(p.size * 0.5, 0)
              ..lineTo(0, p.size * 0.5)
              ..lineTo(-p.size * 0.5, 0)
              ..close(),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// An animated tick that draws itself inside a growing circle.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({
    super.key,
    this.size = 84,
    this.color = AppColors.success,
    this.background,
  });

  final double size;
  final Color color;
  final Color? background;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 760))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, _) => CustomPaint(
          painter: _CheckPainter(
            t: _c.value,
            color: widget.color,
            background: widget.background ?? widget.color.withValues(alpha: 0.14),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.t, required this.color, required this.background});
  final double t;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final double pop = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    canvas.drawCircle(c, r * pop.clamp(0, 1), Paint()..color = background);

    final double stroke = ((t - 0.28) / 0.72).clamp(0.0, 1.0);
    if (stroke <= 0) return;
    final Path p = Path()
      ..moveTo(c.dx - r * 0.34, c.dy + r * 0.03)
      ..lineTo(c.dx - r * 0.08, c.dy + r * 0.28)
      ..lineTo(c.dx + r * 0.36, c.dy - r * 0.26);

    final PathMetric m = p.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * Curves.easeOutCubic.transform(stroke)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

/// A soft pulsing halo used to draw the eye to the next thing to tap.
class AttentionPulse extends StatefulWidget {
  const AttentionPulse({super.key, required this.child, this.color = AppColors.accent, this.active = true});

  final Widget child;
  final Color color;
  final bool active;

  @override
  State<AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<AttentionPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final double t = _c.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: (1 - t) * 0.32),
                blurRadius: 6 + t * 20,
                spreadRadius: t * 8,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
