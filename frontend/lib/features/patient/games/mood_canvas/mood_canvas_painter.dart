import 'package:flutter/material.dart';

/// One continuous pen-down-to-pen-up stroke.
class Stroke {
  Stroke({required this.color, required this.width}) : points = <Offset>[];

  final Color color;
  final double width;
  final List<Offset> points;
}

/// Paints whatever has been drawn so far.
///
/// Deliberately the only new gesture-driven canvas in the app — every other
/// `CustomPainter` here (see `core/widgets/illustration.dart`) is a pure
/// function of a fixed id, redrawn only when that id changes. This one
/// repaints on every point added, which `shouldRepaint` always answers `true`
/// to rather than diffing stroke lists on each frame — simplicity over a
/// micro-optimisation that a handful of strokes never needs.
class MoodCanvasPainter extends CustomPainter {
  const MoodCanvasPainter({required this.strokes, required this.background});

  final List<Stroke> strokes;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    // Painted opaque first: the saved PNG is shown later via `Image.memory`
    // on the doctor's screen, and a transparent background would show
    // whatever happens to sit behind that card instead of a blank page.
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    for (final Stroke stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          Paint()..color = stroke.color,
        );
        continue;
      }
      final Paint paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final Path path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final Offset point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(MoodCanvasPainter oldDelegate) => true;
}
