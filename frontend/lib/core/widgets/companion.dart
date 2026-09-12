import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

/// The moods of Saathi, the companion.
enum CompanionState { idle, happy, thinking, encouraging, celebrating, listening, gentle }

extension CompanionStateX on CompanionState {
  Color get glow => switch (this) {
        CompanionState.celebrating => AppColors.accent,
        CompanionState.thinking => AppColors.secondary,
        CompanionState.listening => AppColors.plum,
        CompanionState.gentle => AppColors.terracotta,
        _ => AppColors.primarySoft,
      };
}

/// Saathi — a warm, hand-drawn companion that breathes, blinks and reacts.
///
/// Drawn entirely with a [CustomPainter] so it scales crisply from a 44 px
/// chat bubble avatar to a 260 px hero on the patient home screen.
class Companion extends StatefulWidget {
  const Companion({
    super.key,
    this.state = CompanionState.happy,
    this.size = 180,
    this.animate = true,
  });

  final CompanionState state;
  final double size;
  final bool animate;

  @override
  State<Companion> createState() => _CompanionState();
}

class _CompanionState extends State<Companion> with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _blink;
  late final AnimationController _react;

  /// The blink occupies the final slice of a long, slow cycle, so no timers
  /// are needed — the whole character is driven by three controllers.
  static const double _blinkWindow = 0.05;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: Motion.breathe)..repeat(reverse: true);
    _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    // Stagger the blink per instance so two companions on screen never blink
    // in lockstep.
    final double offset = math.Random(widget.size.round()).nextDouble();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))
      ..value = offset
      ..repeat();
  }

  double get _blinkAmount {
    if (!widget.animate) return 1;
    final double t = _blink.value;
    if (t < 1 - _blinkWindow) return 1;
    final double u = (t - (1 - _blinkWindow)) / _blinkWindow;
    return u < 0.5 ? 1 - u * 2 : (u - 0.5) * 2;
  }

  @override
  void dispose() {
    _breath.dispose();
    _blink.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_breath, _react, _blink]),
        builder: (BuildContext context, _) {
          final double breath = widget.animate
              ? Curves.easeInOut.transform(_breath.value)
              : 0.5;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _CompanionPainter(
                state: widget.state,
                breath: breath,
                phase: _react.value,
                blink: _blinkAmount,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompanionPainter extends CustomPainter {
  _CompanionPainter({
    required this.state,
    required this.breath,
    required this.phase,
    required this.blink,
  });

  final CompanionState state;
  final double breath;
  final double phase;
  final double blink;

  static const Color _shellTop = Color(0xFF63B79C);
  static const Color _shellBottom = Color(0xFF2E7D6B);
  static const Color _visor = Color(0xFF17453A);
  static const Color _eye = Color(0xFFEAFBF3);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final double bob = (breath - 0.5) * 2.6;
    final double squish = 1 + (breath - 0.5) * 0.022;

    _auraAndSparkles(canvas);

    canvas.save();
    canvas.translate(50, 52 + bob);
    canvas.scale(1 / squish, squish);
    canvas.translate(-50, -52);

    _body(canvas);
    _head(canvas);
    _face(canvas);

    canvas.restore();
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  // ── ambience ───────────────────────────────────────────────────────────
  void _auraAndSparkles(Canvas c) {
    final Color glow = state.glow;
    c.drawCircle(const Offset(50, 52), 46 + breath * 3, _fill(glow.withValues(alpha: 0.09)));
    c.drawCircle(const Offset(50, 52), 39 + breath * 2, _fill(glow.withValues(alpha: 0.09)));

    if (state == CompanionState.listening) {
      for (int i = 0; i < 3; i++) {
        final double t = ((phase + i / 3) % 1.0);
        c.drawCircle(
          const Offset(50, 52),
          34 + t * 22,
          _stroke(AppColors.plum.withValues(alpha: (1 - t) * 0.35), 2.2),
        );
      }
    }

    if (state == CompanionState.celebrating) {
      for (int i = 0; i < 8; i++) {
        final double a = i * math.pi / 4 + phase * math.pi * 2;
        final double r = 40 + math.sin(phase * math.pi * 2 + i) * 6;
        _sparkle(c, 50 + math.cos(a) * r, 50 + math.sin(a) * r * 0.85,
            2.6 + math.sin(phase * math.pi * 2 + i) * 1.2,
            i.isEven ? AppColors.accent : AppColors.terracotta);
      }
    }

    if (state == CompanionState.thinking) {
      for (int i = 0; i < 3; i++) {
        final double t = ((phase + i * 0.22) % 1.0);
        c.drawCircle(
          Offset(72 + i * 7.5, 20 - t * 5 - i * 2.0),
          2.0 + i * 0.7,
          _fill(AppColors.secondary.withValues(alpha: 0.25 + (1 - t) * 0.5)),
        );
      }
    }
  }

  void _sparkle(Canvas c, double x, double y, double r, Color col) {
    final Path p = Path()
      ..moveTo(x, y - r)
      ..quadraticBezierTo(x + r * 0.28, y - r * 0.28, x + r, y)
      ..quadraticBezierTo(x + r * 0.28, y + r * 0.28, x, y + r)
      ..quadraticBezierTo(x - r * 0.28, y + r * 0.28, x - r, y)
      ..quadraticBezierTo(x - r * 0.28, y - r * 0.28, x, y - r)
      ..close();
    c.drawPath(p, _fill(col));
  }

  // ── construction ───────────────────────────────────────────────────────
  void _body(Canvas c) {
    // shoulders
    final Path body = Path()
      ..moveTo(26, 96)
      ..quadraticBezierTo(27, 76, 50, 74)
      ..quadraticBezierTo(73, 76, 74, 96)
      ..close();
    c.drawPath(body, _fill(const Color(0xFF4E9C85)));

    // gamosa scarf — the companion wears the region's cloth
    final Path scarf = Path()
      ..moveTo(31, 78)
      ..quadraticBezierTo(50, 88, 69, 78)
      ..lineTo(71, 85)
      ..quadraticBezierTo(50, 95, 29, 85)
      ..close();
    c.drawPath(scarf, _fill(const Color(0xFFFBF4E8)));
    final Path stripe = Path()
      ..moveTo(30, 82)
      ..quadraticBezierTo(50, 91.5, 70, 82)
      ..lineTo(71, 85)
      ..quadraticBezierTo(50, 95, 29, 85)
      ..close();
    c.drawPath(stripe, _fill(const Color(0xFFC0392B)));
    for (int i = 0; i < 3; i++) {
      final double x = 40.0 + i * 10;
      final Path d = Path()
        ..moveTo(x, 84.5)
        ..lineTo(x + 2.4, 87)
        ..lineTo(x, 89.5)
        ..lineTo(x - 2.4, 87)
        ..close();
      c.drawPath(d, _fill(const Color(0xFFFBF4E8)));
    }
  }

  void _head(Canvas c) {
    // antenna
    c.drawLine(const Offset(50, 18), const Offset(50, 9), _stroke(const Color(0xFF4E9C85), 3));
    final double pulse = 0.6 + breath * 0.4;
    c.drawCircle(const Offset(50, 7), 6.5, _fill(state.glow.withValues(alpha: 0.22 * pulse)));
    c.drawCircle(const Offset(50, 7), 3.6, _fill(state.glow));
    c.drawCircle(const Offset(48.7, 5.8), 1.2, _fill(Colors.white.withValues(alpha: 0.85)));

    // side ears
    for (final double x in <double>[13.5, 86.5]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, 50), width: 8, height: 20), const Radius.circular(4)),
        _fill(const Color(0xFF4E9C85)),
      );
      c.drawCircle(Offset(x, 50), 2.2, _fill(const Color(0xFFEAFBF3)));
    }

    // head shell
    final RRect shell = RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 18, 66, 60), const Radius.circular(25));
    c.drawRRect(
      shell.shift(const Offset(0, 2.5)),
      _fill(const Color(0x22203A32)),
    );
    c.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_shellTop, _shellBottom],
        ).createShader(const Rect.fromLTWH(17, 18, 66, 60))
        ..isAntiAlias = true,
    );
    // top highlight
    final Path gloss = Path()
      ..moveTo(26, 34)
      ..quadraticBezierTo(34, 22, 52, 22)
      ..quadraticBezierTo(38, 26, 31, 38)
      ..close();
    c.drawPath(gloss, _fill(Colors.white.withValues(alpha: 0.28)));

    // visor
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(23.5, 27, 53, 39), const Radius.circular(19)),
      _fill(_visor),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(23.5, 27, 53, 39), const Radius.circular(19)),
      _stroke(Colors.white.withValues(alpha: 0.14), 1.4),
    );
  }

  void _face(Canvas c) {
    final double lookX = switch (state) {
      CompanionState.thinking => 3.2,
      CompanionState.listening => -1.0,
      _ => 0,
    };
    final double lookY = switch (state) {
      CompanionState.thinking => -2.4,
      _ => 0,
    };

    const double lx = 39.5, rx = 60.5, ey = 44;
    final Paint eyePaint = _fill(_eye);

    switch (state) {
      case CompanionState.celebrating:
        _happyArcEye(c, lx, ey + 1, 8.4);
        _happyArcEye(c, rx, ey + 1, 8.4);
      case CompanionState.encouraging:
        _happyArcEye(c, lx, ey + 1, 7.6);
        _happyArcEye(c, rx, ey + 1, 7.6);
      case CompanionState.listening:
        _roundEye(c, lx + lookX, ey, 6.4, blink, eyePaint);
        _roundEye(c, rx + lookX, ey, 6.4, blink, eyePaint);
      case CompanionState.gentle:
        _roundEye(c, lx, ey + 0.5, 5.2, blink * 0.72, eyePaint);
        _roundEye(c, rx, ey + 0.5, 5.2, blink * 0.72, eyePaint);
      default:
        _roundEye(c, lx + lookX, ey + lookY, 5.8, blink, eyePaint);
        _roundEye(c, rx + lookX, ey + lookY, 5.8, blink, eyePaint);
    }

    // cheeks
    if (state == CompanionState.happy ||
        state == CompanionState.celebrating ||
        state == CompanionState.encouraging) {
      c.drawCircle(const Offset(31.5, 54), 4.2, _fill(const Color(0x44FF9E7A)));
      c.drawCircle(const Offset(68.5, 54), 4.2, _fill(const Color(0x44FF9E7A)));
    }

    // mouth
    switch (state) {
      case CompanionState.celebrating:
        final Path m = Path()
          ..moveTo(42, 55)
          ..quadraticBezierTo(50, 68, 58, 55)
          ..quadraticBezierTo(50, 58, 42, 55)
          ..close();
        c.drawPath(m, _fill(_eye));
      case CompanionState.listening:
        c.drawCircle(const Offset(50, 58), 3.6, _fill(_eye.withValues(alpha: 0.9)));
      case CompanionState.thinking:
        c.drawLine(const Offset(45, 58), const Offset(55, 57), _stroke(_eye, 2.6));
      case CompanionState.gentle:
        c.drawArc(Rect.fromCenter(center: const Offset(50, 54), width: 14, height: 8), 0.28,
            math.pi * 0.72 - 0.1, false, _stroke(_eye, 2.6));
      default:
        c.drawArc(Rect.fromCenter(center: const Offset(50, 53), width: 18, height: 13), 0.2,
            math.pi - 0.4, false, _stroke(_eye, 2.8));
    }
  }

  void _roundEye(Canvas c, double x, double y, double r, double open, Paint p) {
    final double h = (r * 2) * open.clamp(0.06, 1.0);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: r * 1.85, height: h), Radius.circular(r)),
      p,
    );
    if (open > 0.6) {
      c.drawCircle(Offset(x + r * 0.4, y - r * 0.4), r * 0.28,
          _fill(Colors.white.withValues(alpha: 0.9)));
    }
  }

  void _happyArcEye(Canvas c, double x, double y, double w) {
    c.drawArc(
      Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.9),
      math.pi + 0.25,
      math.pi - 0.5,
      false,
      _stroke(_eye, 2.8),
    );
  }

  @override
  bool shouldRepaint(_CompanionPainter old) =>
      old.breath != breath || old.state != state || old.blink != blink || old.phase != phase;
}

/// Saathi saying something, with a soft speech bubble. Used everywhere the
/// companion talks to the patient.
class CompanionSpeech extends StatelessWidget {
  const CompanionSpeech({
    super.key,
    required this.message,
    this.state = CompanionState.happy,
    this.companionSize = 84,
    this.compact = false,
    this.trailing,
  });

  final String message;
  final CompanionState state;
  final double companionSize;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Companion(state: state, size: companionSize),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: compact ? 14 : 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(compact ? 6 : 8),
                topRight: Radius.circular(Corners.lg),
                bottomLeft: Radius.circular(Corners.lg),
                bottomRight: Radius.circular(Corners.lg),
              ),
              border: Border.all(color: AppColors.hairline),
              boxShadow: AppColors.softShadow(y: 5, blur: 16, opacity: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: Motion.normal,
                  child: Text(
                    message,
                    key: ValueKey<String>(message),
                    style: compact ? AppText.body.wght(600) : AppText.companionSpeech,
                  ),
                ),
                if (trailing != null) ...<Widget>[const SizedBox(height: 12), trailing!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
