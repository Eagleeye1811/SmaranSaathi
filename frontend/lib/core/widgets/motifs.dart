import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A whisper-quiet geometric motif inspired by the woven diamonds and combs of
/// Assamese gamosa and Manipuri phanek borders.
///
/// It sits behind the warm screens at very low opacity so the app carries a
/// regional identity without ever looking like a themed template.
class MotifBackground extends StatelessWidget {
  const MotifBackground({
    super.key,
    required this.child,
    this.opacity = 0.05,
    this.color,
    this.density = 1,
    this.showTopWash = true,
    this.washColors,
  });

  final Widget child;
  final double opacity;
  final Color? color;
  final double density;
  final bool showTopWash;
  final List<Color>? washColors;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _MotifPainter(
                  color: (color ?? AppColors.primary).withValues(alpha: opacity),
                  density: density,
                ),
              ),
            ),
          ),
          if (showTopWash)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 320,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: washColors ??
                          <Color>[
                            AppColors.primaryTint.withValues(alpha: 0.75),
                            AppColors.primaryTint.withValues(alpha: 0.0),
                          ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  const _MotifPainter({required this.color, required this.density});
  final Color color;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final double step = 54 / density;
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;

    final int cols = (size.width / step).ceil() + 1;
    final int rows = (size.height / step).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int col = 0; col < cols; col++) {
        final double cx = col * step + (r.isEven ? 0 : step / 2);
        final double cy = r * step;
        final double d = step * 0.3;
        // woven diamond
        final Path diamond = Path()
          ..moveTo(cx, cy - d)
          ..lineTo(cx + d, cy)
          ..lineTo(cx, cy + d)
          ..lineTo(cx - d, cy)
          ..close();
        canvas.drawPath(diamond, p);
        if ((r + col) % 3 == 0) {
          canvas.drawPath(
            Path()
              ..moveTo(cx, cy - d * 0.45)
              ..lineTo(cx + d * 0.45, cy)
              ..lineTo(cx, cy + d * 0.45)
              ..lineTo(cx - d * 0.45, cy)
              ..close(),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MotifPainter old) => old.color != color || old.density != density;
}

/// A decorative woven border strip — used as a divider / header accent.
class WovenStrip extends StatelessWidget {
  const WovenStrip({super.key, this.height = 12, this.colors, this.opacity = 1});

  final double height;
  final List<Color>? colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _StripPainter(
          colors ?? const <Color>[AppColors.terracotta, AppColors.accent, AppColors.primary],
          opacity,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter(this.colors, this.opacity);
  final List<Color> colors;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double d = size.height * 0.5;
    final int n = (size.width / (d * 1.6)).ceil() + 1;
    for (int i = 0; i < n; i++) {
      final double cx = i * d * 1.6 + d * 0.8;
      final Paint p = Paint()..color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.drawPath(
        Path()
          ..moveTo(cx, size.height / 2 - d)
          ..lineTo(cx + d * 0.7, size.height / 2)
          ..lineTo(cx, size.height / 2 + d)
          ..lineTo(cx - d * 0.7, size.height / 2)
          ..close(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => false;
}

/// The textile tile used by "Weaves of the Hills". Deterministic from [seed]
/// so the same seed always draws the same motif.
class WeaveTile extends StatelessWidget {
  const WeaveTile({
    super.key,
    required this.seed,
    required this.palette,
    this.size,
    this.radius = 10,
    this.faded = false,
  });

  final int seed;
  final List<Color> palette;
  final double? size;
  final double radius;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final Widget painted = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _WeavePainter(seed: seed, palette: palette, faded: faded),
        size: Size.infinite,
      ),
    );
    if (size == null) return AspectRatio(aspectRatio: 1, child: painted);
    return SizedBox(width: size, height: size, child: painted);
  }
}

class _WeavePainter extends CustomPainter {
  const _WeavePainter({required this.seed, required this.palette, required this.faded});
  final int seed;
  final List<Color> palette;
  final bool faded;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random rnd = math.Random(seed);
    final double w = size.width;
    final Color base = palette[0];
    final Color a = palette[1 % palette.length];
    final Color b = palette[2 % palette.length];
    final double op = faded ? 0.35 : 1.0;

    canvas.drawRect(Offset.zero & size, Paint()..color = base.withValues(alpha: op));

    final int variant = seed % 6;
    final Paint pa = Paint()..color = a.withValues(alpha: op);
    final Paint pb = Paint()..color = b.withValues(alpha: op);

    switch (variant) {
      case 0: // central diamond with inner eye
        _diamond(canvas, w / 2, w / 2, w * 0.38, pa);
        _diamond(canvas, w / 2, w / 2, w * 0.18, pb);
      case 1: // four corner triangles
        canvas.drawPath(_tri(<Offset>[Offset.zero, Offset(w * 0.5, 0), Offset(0, w * 0.5)]), pa);
        canvas.drawPath(_tri(<Offset>[Offset(w, 0), Offset(w, w * 0.5), Offset(w * 0.5, 0)]), pb);
        canvas.drawPath(_tri(<Offset>[Offset(0, w), Offset(w * 0.5, w), Offset(0, w * 0.5)]), pb);
        canvas.drawPath(_tri(<Offset>[Offset(w, w), Offset(w * 0.5, w), Offset(w, w * 0.5)]), pa);
      case 2: // horizontal bands
        canvas.drawRect(Rect.fromLTWH(0, w * 0.18, w, w * 0.16), pa);
        canvas.drawRect(Rect.fromLTWH(0, w * 0.44, w, w * 0.12), pb);
        canvas.drawRect(Rect.fromLTWH(0, w * 0.66, w, w * 0.16), pa);
      case 3: // comb / zigzag
        final Path z = Path()..moveTo(0, w * 0.72);
        for (int i = 0; i <= 4; i++) {
          z.lineTo(w * (i + 0.5) / 4, i.isEven ? w * 0.28 : w * 0.72);
        }
        canvas.drawPath(
            z,
            Paint()
              ..color = a.withValues(alpha: op)
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.12
              ..strokeJoin = StrokeJoin.miter);
        _diamond(canvas, w / 2, w * 0.5, w * 0.12, pb);
      case 4: // stacked chevrons
        for (int i = 0; i < 3; i++) {
          final Path p = Path()
            ..moveTo(w * 0.1, w * (0.28 + i * 0.22))
            ..lineTo(w * 0.5, w * (0.12 + i * 0.22))
            ..lineTo(w * 0.9, w * (0.28 + i * 0.22));
          canvas.drawPath(
              p,
              Paint()
                ..color = (i.isEven ? a : b).withValues(alpha: op)
                ..style = PaintingStyle.stroke
                ..strokeWidth = w * 0.1);
        }
      default: // eight-point star
        canvas.drawRect(Rect.fromLTWH(w * 0.12, w * 0.12, w * 0.76, w * 0.76), pa);
        _diamond(canvas, w / 2, w / 2, w * 0.44, pb);
        _diamond(canvas, w / 2, w / 2, w * 0.16, pa);
    }

    // subtle woven texture
    final Paint thread = Paint()
      ..color = Colors.white.withValues(alpha: faded ? 0.05 : 0.10)
      ..strokeWidth = 1;
    for (double y = 2; y < w; y += 5 + rnd.nextInt(2)) {
      canvas.drawLine(Offset(0, y), Offset(w, y), thread);
    }
  }

  void _diamond(Canvas c, double cx, double cy, double r, Paint p) {
    c.drawPath(
      Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close(),
      p,
    );
  }

  Path _tri(List<Offset> pts) {
    final Path p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final Offset o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_WeavePainter old) =>
      old.seed != seed || old.faded != faded || old.palette != palette;
}

/// A tile whose motif is hidden — a plain woven cloth back, so the patient
/// cannot read the answer through it and the grid still looks deliberate.
class CoveredTile extends StatelessWidget {
  const CoveredTile({super.key, this.radius = 8});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inkMuted.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: CustomPaint(painter: const _CoverPainter(), size: Size.infinite),
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint thread = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (double y = 3; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thread);
    }
    for (double x = 3; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), thread..color = Colors.white.withValues(alpha: 0.18));
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.09,
      Paint()..color = AppColors.inkMuted.withValues(alpha: 0.34),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) => false;
}
