import 'dart:math' as math;
import 'dart:ui' show PathMetric, PathMetrics, Tangent;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../models/clinical.dart';

/// Charts for MemoryMitra.
///
/// House rules, applied consistently: one value axis only, recessive grid and
/// axis ink, thin marks, direct labels instead of a number on every point, and
/// identity never carried by colour alone (a legend appears whenever more than
/// one series is drawn). Series colours come from [AppColors.chartSeries] in
/// fixed order.

// ─────────────────────────────────────────────────────────────────────────
// Trend line
// ─────────────────────────────────────────────────────────────────────────

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    this.color = AppColors.seriesTeal,
    this.height = 168,
    this.maxValue = 100,
    this.minValue = 0,
    this.showArea = true,
    this.showDots = true,
    this.labelEvery = 1,
    this.highlightLast = true,
    this.valueSuffix = '',
    this.band,
  });

  final List<SeriesPoint> points;
  final Color color;
  final double height;
  final double maxValue;
  final double minValue;
  final bool showArea;
  final bool showDots;
  final int labelEvery;
  final bool highlightLast;
  final String valueSuffix;

  /// Optional shaded reference band (e.g. the patient's typical range).
  final ({double low, double high})? band;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, _) {
          return CustomPaint(
            painter: _TrendPainter(
              points: points,
              color: color,
              progress: t,
              maxValue: maxValue,
              minValue: minValue,
              showArea: showArea,
              showDots: showDots,
              labelEvery: labelEvery,
              highlightLast: highlightLast,
              valueSuffix: valueSuffix,
              band: band,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.color,
    required this.progress,
    required this.maxValue,
    required this.minValue,
    required this.showArea,
    required this.showDots,
    required this.labelEvery,
    required this.highlightLast,
    required this.valueSuffix,
    required this.band,
  });

  final List<SeriesPoint> points;
  final Color color;
  final double progress;
  final double maxValue;
  final double minValue;
  final bool showArea;
  final bool showDots;
  final int labelEvery;
  final bool highlightLast;
  final String valueSuffix;
  final ({double low, double high})? band;

  static const double _axisGap = 26;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final double plotH = size.height - _axisGap - 14;
    final double plotW = size.width - 8;
    const double left = 4;
    const double top = 10;

    double yFor(double v) =>
        top + plotH - ((v - minValue) / (maxValue - minValue)).clamp(0.0, 1.0) * plotH;
    double xFor(int i) =>
        left + (points.length == 1 ? plotW / 2 : plotW * i / (points.length - 1));

    // reference band
    if (band != null) {
      canvas.drawRect(
        Rect.fromLTRB(left, yFor(band!.high), left + plotW, yFor(band!.low)),
        Paint()..color = color.withValues(alpha: 0.07),
      );
    }

    // recessive grid
    final Paint grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = top + plotH * i / 3;
      canvas.drawLine(Offset(left, y), Offset(left + plotW, y), grid);
    }

    // path
    final Path line = Path();
    final List<Offset> pts = <Offset>[
      for (int i = 0; i < points.length; i++) Offset(xFor(i), yFor(points[i].value)),
    ];
    line.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final Offset p0 = pts[i - 1];
      final Offset p1 = pts[i];
      final double cx = (p0.dx + p1.dx) / 2;
      line.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final _PathTrim holder = _PathTrim(line, progress);

    if (showArea) {
      final Path area = Path.from(holder.partial)
        ..lineTo(holder.endPoint.dx, top + plotH)
        ..lineTo(pts.first.dx, top + plotH)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[color.withValues(alpha: 0.24), color.withValues(alpha: 0.01)],
          ).createShader(Rect.fromLTWH(left, top, plotW, plotH)),
      );
    }

    canvas.drawPath(
      holder.partial,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // markers
    if (showDots) {
      for (int i = 0; i < pts.length; i++) {
        if (pts[i].dx > holder.endPoint.dx + 0.5) continue;
        final bool last = i == pts.length - 1;
        if (!last && i % math.max(1, labelEvery) != 0) continue;
        canvas.drawCircle(pts[i], last && highlightLast ? 6.5 : 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          pts[i],
          last && highlightLast ? 5 : 3.2,
          Paint()..color = color,
        );
      }
    }

    // direct label on the newest point only — never a number on every point
    if (highlightLast && progress > 0.92) {
      final Offset p = pts.last;
      _chip(canvas, '${points.last.value.round()}$valueSuffix', p, size, color);
    }

    // x labels
    for (int i = 0; i < points.length; i++) {
      if (i % math.max(1, labelEvery) != 0 && i != points.length - 1) continue;
      final TextPainter tp = _text(points[i].label, AppText.caption.sized(11.5));
      final double x = (xFor(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, top + plotH + 9));
    }
  }

  void _chip(Canvas canvas, String label, Offset at, Size size, Color c) {
    final TextPainter tp = _text(label, AppText.caption.sized(12).tint(Colors.white).wght(800));
    final double w = tp.width + 14;
    const double h = 22;
    double x = at.dx - w / 2;
    x = x.clamp(0.0, size.width - w);
    final double y = math.max(0, at.dy - h - 12);
    final RRect r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(11));
    canvas.drawRRect(r, Paint()..color = c);
    tp.paint(canvas, Offset(x + 7, y + 4));
  }

  TextPainter _text(String s, TextStyle style) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.progress != progress || old.points != points;
}

/// Small helper that trims a path to [progress] for the draw-on animation.
class _PathTrim {
  _PathTrim(Path source, double progress) {
    final PathMetrics metrics = source.computeMetrics();
    partial = Path();
    endPoint = Offset.zero;
    for (final PathMetric m in metrics) {
      final double len = m.length * progress.clamp(0.0, 1.0);
      partial.addPath(m.extractPath(0, len), Offset.zero);
      final Tangent? t = m.getTangentForOffset(len);
      if (t != null) endPoint = t.position;
    }
  }

  late final Path partial;
  late Offset endPoint;
}

// ─────────────────────────────────────────────────────────────────────────
// Bars
// ─────────────────────────────────────────────────────────────────────────

class BarSeriesChart extends StatelessWidget {
  const BarSeriesChart({
    super.key,
    required this.points,
    this.height = 150,
    this.color = AppColors.seriesTeal,
    this.maxValue = 100,
    this.highlightIndex,
    this.showValues = false,
    this.barColors,
  });

  final List<SeriesPoint> points;
  final double height;
  final Color color;
  final double maxValue;
  final int? highlightIndex;
  final bool showValues;
  final List<Color>? barColors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, _) => CustomPaint(
          painter: _BarPainter(
            points: points,
            progress: t,
            color: color,
            maxValue: maxValue,
            highlightIndex: highlightIndex,
            showValues: showValues,
            barColors: barColors,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.points,
    required this.progress,
    required this.color,
    required this.maxValue,
    required this.highlightIndex,
    required this.showValues,
    required this.barColors,
  });

  final List<SeriesPoint> points;
  final double progress;
  final Color color;
  final double maxValue;
  final int? highlightIndex;
  final bool showValues;
  final List<Color>? barColors;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const double axisGap = 24;
    final double topPad = showValues ? 20.0 : 6.0;
    final double plotH = size.height - axisGap - topPad;
    // a 2px surface gap sits between adjacent bars
    final double slot = size.width / points.length;
    final double barW = math.min(30, slot - 8);

    final Paint baseline = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, topPad + plotH), Offset(size.width, topPad + plotH), baseline);

    for (int i = 0; i < points.length; i++) {
      final double v = (points[i].value / maxValue).clamp(0.0, 1.0) * progress;
      final double h = math.max(3, v * plotH);
      final double x = slot * i + (slot - barW) / 2;
      final double y = topPad + plotH - h;
      final bool hi = highlightIndex == i;
      final Color c = barColors != null
          ? barColors![i % barColors!.length]
          : (hi ? color : color.withValues(alpha: 0.42));

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = c,
      );

      if (showValues && progress > 0.85) {
        _paintText(canvas, points[i].value.round().toString(),
            AppText.caption.sized(11.5).wght(800).tint(AppColors.inkSoft),
            Offset(slot * i + slot / 2, y - 16), slot);
      }
      _paintText(canvas, points[i].label, AppText.caption.sized(11.5),
          Offset(slot * i + slot / 2, topPad + plotH + 7), slot);
    }
  }

  void _paintText(Canvas canvas, String s, TextStyle style, Offset center, double maxW) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.progress != progress || old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────
// Radar (cognitive domain profile)
// ─────────────────────────────────────────────────────────────────────────

class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.values,
    this.size = 240,
    this.color = AppColors.seriesTeal,
    this.comparison,
    this.comparisonColor = AppColors.seriesBlue,
  });

  /// label → 0..100
  final Map<String, int> values;
  final double size;
  final Color color;
  final Map<String, int>? comparison;
  final Color comparisonColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, _) => CustomPaint(
          painter: _RadarPainter(
            values: values,
            progress: t,
            color: color,
            comparison: comparison,
            comparisonColor: comparisonColor,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.comparison,
    required this.comparisonColor,
  });

  final Map<String, int> values;
  final double progress;
  final Color color;
  final Map<String, int>? comparison;
  final Color comparisonColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = math.min(size.width, size.height) / 2 - 34;
    final int n = values.length;
    if (n < 3) return;

    double angle(int i) => -math.pi / 2 + i * 2 * math.pi / n;

    // web
    final Paint web = Paint()
      ..color = AppColors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int ring = 1; ring <= 4; ring++) {
      final Path p = Path();
      for (int i = 0; i < n; i++) {
        final double a = angle(i);
        final Offset o = c + Offset(math.cos(a), math.sin(a)) * (r * ring / 4);
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      p.close();
      canvas.drawPath(p, web);
    }
    for (int i = 0; i < n; i++) {
      final double a = angle(i);
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r, web);
    }

    Path shape(List<int> vals) {
      final Path p = Path();
      for (int i = 0; i < n; i++) {
        final double a = angle(i);
        final double v = (vals[i] / 100).clamp(0.0, 1.0) * progress;
        final Offset o = c + Offset(math.cos(a), math.sin(a)) * (r * v);
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      return p..close();
    }

    if (comparison != null) {
      final Path cp = shape(values.keys.map((String k) => comparison![k] ?? 0).toList());
      canvas.drawPath(
          cp,
          Paint()
            ..color = comparisonColor.withValues(alpha: 0.10)
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          cp,
          Paint()
            ..color = comparisonColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round);
    }

    final Path main = shape(values.values.toList());
    canvas.drawPath(main, Paint()..color = color.withValues(alpha: 0.20));
    canvas.drawPath(
        main,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round);

    // vertices + labels
    final List<String> keys = values.keys.toList();
    for (int i = 0; i < n; i++) {
      final double a = angle(i);
      final double v = (values[keys[i]]! / 100).clamp(0.0, 1.0) * progress;
      final Offset o = c + Offset(math.cos(a), math.sin(a)) * (r * v);
      canvas.drawCircle(o, 4.6, Paint()..color = Colors.white);
      canvas.drawCircle(o, 3.2, Paint()..color = color);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '${keys[i]}\n', style: AppText.caption.sized(11.5).wght(700)),
            TextSpan(
              text: '${values[keys[i]]}',
              style: AppText.caption.sized(13).wght(800).tint(color),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 66);
      final Offset lp = c + Offset(math.cos(a), math.sin(a)) * (r + 22);
      tp.paint(
        canvas,
        Offset(
          (lp.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
          (lp.dy - tp.height / 2).clamp(0.0, size.height - tp.height),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress || old.values != values;
}

// ─────────────────────────────────────────────────────────────────────────
// Sparkline
// ─────────────────────────────────────────────────────────────────────────

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.seriesTeal,
    this.width = 72,
    this.height = 30,
    this.fill = true,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(values, color, fill), size: Size.infinite),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values, this.color, this.fill);
  final List<double> values;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double lo = values.reduce(math.min);
    final double hi = values.reduce(math.max);
    final double span = (hi - lo).abs() < 0.001 ? 1 : hi - lo;

    final Path p = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double y = size.height - ((values[i] - lo) / span) * (size.height - 6) - 3;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    if (fill) {
      final Path a = Path.from(p)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(a, Paint()..color = color.withValues(alpha: 0.13));
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    final double lastX = size.width;
    final double lastY = size.height - ((values.last - lo) / span) * (size.height - 6) - 3;
    canvas.drawCircle(Offset(lastX - 2, lastY), 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────
// Weekly dot strip — a friendly, non-clinical week view for the caregiver
// ─────────────────────────────────────────────────────────────────────────

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.days, this.color = AppColors.seriesTeal});

  /// label → 0..1 completion
  final List<SeriesPoint> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < days.length; i++)
          Expanded(
            child: Column(
              children: <Widget>[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: days[i].value.clamp(0, 1)),
                  duration: Duration(milliseconds: 500 + i * 70),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double v, _) => Container(
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: Corners.r(10),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: math.max(0.08, v),
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: v > 0.7 ? 1 : 0.55),
                            borderRadius: Corners.r(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(days[i].label, style: AppText.caption.sized(11.5)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Legend row — always shown when a figure draws more than one series.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  final List<({String label, Color color})> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: <Widget>[
        for (final ({String label, Color color}) e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: e.color, borderRadius: Corners.r(3)),
              ),
              const SizedBox(width: 7),
              Text(e.label, style: AppText.caption.sized(12.5).wght(600)),
            ],
          ),
      ],
    );
  }
}
