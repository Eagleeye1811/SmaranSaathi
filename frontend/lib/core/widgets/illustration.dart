import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

/// Procedurally drawn, flat-vector illustrations.
///
/// The prototype ships no binary image assets: every "photo", memory card and
/// game illustration is painted here. That keeps the app tiny, keeps the whole
/// product visually consistent, and means the North-Eastern imagery is drawn
/// rather than stock-sourced.
class Scenes {
  const Scenes._();

  /// Background wash for each scene.
  static const Map<String, List<Color>> _bg = <String, List<Color>>{
    'portrait_aama': <Color>[Color(0xFFFDF0DC), Color(0xFFF7DDBE)],
    'portrait_priya': <Color>[Color(0xFFE2F0EB), Color(0xFFC6E2D8)],
    'portrait_aarav': <Color>[Color(0xFFE3EDF8), Color(0xFFC7DBF0)],
    'portrait_bhaskar': <Color>[Color(0xFFEFEAF3), Color(0xFFDDD3E6)],
    'portrait_neighbour': <Color>[Color(0xFFFBE9E3), Color(0xFFF3D2C6)],
    'weaving': <Color>[Color(0xFFFBE7DF), Color(0xFFF2C9B6)],
    'gamosa': <Color>[Color(0xFFFDF6EC), Color(0xFFF3E4D0)],
    'pitha': <Color>[Color(0xFFFCEEDA), Color(0xFFF4D9B4)],
    'dhol': <Color>[Color(0xFFF8E4DC), Color(0xFFEDC4B4)],
    'pepa': <Color>[Color(0xFFEFF0E0), Color(0xFFDCDFBF)],
    'gogona': <Color>[Color(0xFFE6F1E5), Color(0xFFC9E2C8)],
    'bihu': <Color>[Color(0xFFFDEBD2), Color(0xFFF6C98E)],
    'village_home': <Color>[Color(0xFFE8F2E4), Color(0xFFC9E0C4)],
    'river': <Color>[Color(0xFFE2EFF6), Color(0xFFBBD9EA)],
    'tea_garden': <Color>[Color(0xFFE9F3E2), Color(0xFFC5DFB9)],
    'market': <Color>[Color(0xFFFCEFE0), Color(0xFFF4D6B6)],
    'hills': <Color>[Color(0xFFE7EEF6), Color(0xFFC3D6E8)],
    'bamboo': <Color>[Color(0xFFEAF3E6), Color(0xFFCBE3C4)],
    'rhino': <Color>[Color(0xFFEEF2E3), Color(0xFFD3DEBC)],
    'orchid': <Color>[Color(0xFFF6ECF4), Color(0xFFE6CFE4)],
    'japi': <Color>[Color(0xFFFAF0DB), Color(0xFFEEDBB2)],
    'xorai': <Color>[Color(0xFFFBEEDA), Color(0xFFF0D6A4)],
    'paddy': <Color>[Color(0xFFF6F1DA), Color(0xFFE6DCAE)],
    'festival': <Color>[Color(0xFFF7E7E0), Color(0xFFEDC9BC)],
  };

  static List<Color> background(String id) =>
      _bg[id] ?? const <Color>[Color(0xFFF1EDE5), Color(0xFFDFD8CB)];

  static const List<String> people = <String>[
    'portrait_aama',
    'portrait_priya',
    'portrait_aarav',
    'portrait_bhaskar',
    'portrait_neighbour',
  ];

  static const List<String> all = <String>[
    'portrait_aama',
    'portrait_priya',
    'portrait_aarav',
    'portrait_bhaskar',
    'portrait_neighbour',
    'weaving',
    'gamosa',
    'pitha',
    'dhol',
    'pepa',
    'gogona',
    'bihu',
    'village_home',
    'river',
    'tea_garden',
    'market',
    'hills',
    'bamboo',
    'rhino',
    'orchid',
    'japi',
    'xorai',
    'paddy',
    'festival',
  ];

  /// Draws [id] into a 100 × 100 logical box. Callers scale before calling.
  static void draw(Canvas c, String id) {
    switch (id) {
      case 'portrait_aama':
        _portrait(c,
            skin: const Color(0xFFE0B089),
            hair: const Color(0xFFD8D3CB),
            cloth: const Color(0xFFEDE6DA),
            border: const Color(0xFFC0392B),
            glasses: true,
            bun: true,
            bindi: true);
      case 'portrait_priya':
        _portrait(c,
            skin: const Color(0xFFD9A277),
            hair: const Color(0xFF2E2823),
            cloth: const Color(0xFF2E7D6B),
            border: const Color(0xFFE0913A),
            bun: true,
            bindi: true);
      case 'portrait_aarav':
        _portrait(c,
            skin: const Color(0xFFE3B792),
            hair: const Color(0xFF221E1A),
            cloth: const Color(0xFF4A7FA5),
            border: const Color(0xFFFFFFFF),
            young: true);
      case 'portrait_bhaskar':
        _portrait(c,
            skin: const Color(0xFFCB9468),
            hair: const Color(0xFF3A322B),
            cloth: const Color(0xFF6E7A8A),
            border: const Color(0xFFFFFFFF),
            moustache: true);
      case 'portrait_neighbour':
        _portrait(c,
            skin: const Color(0xFFD7A57C),
            hair: const Color(0xFF6B625A),
            cloth: const Color(0xFFC9694F),
            border: const Color(0xFFF3E4D0),
            bun: true,
            bindi: true);
      case 'weaving':
        _weaving(c);
      case 'gamosa':
        _gamosa(c);
      case 'pitha':
        _pitha(c);
      case 'dhol':
        _dhol(c);
      case 'pepa':
        _pepa(c);
      case 'gogona':
        _gogona(c);
      case 'bihu':
        _bihu(c);
      case 'village_home':
        _villageHome(c);
      case 'river':
        _river(c);
      case 'tea_garden':
        _teaGarden(c);
      case 'market':
        _market(c);
      case 'hills':
        _hills(c);
      case 'bamboo':
        _bamboo(c);
      case 'rhino':
        _rhino(c);
      case 'orchid':
        _orchid(c);
      case 'japi':
        _japi(c);
      case 'xorai':
        _xorai(c);
      case 'paddy':
        _paddy(c);
      case 'festival':
        _festival(c);
      default:
        _hills(c);
    }
  }

  // ── primitives ─────────────────────────────────────────────────────────
  static Paint _p(Color c, {PaintingStyle style = PaintingStyle.fill, double w = 2}) => Paint()
    ..color = c
    ..style = style
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static void _circle(Canvas c, double x, double y, double r, Color col) =>
      c.drawCircle(Offset(x, y), r, _p(col));

  static void _oval(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), _p(col));

  static void _rr(Canvas c, double l, double t, double w, double h, double r, Color col) =>
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)), _p(col));

  static void _poly(Canvas c, List<Offset> pts, Color col) {
    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final Offset o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    c.drawPath(path, _p(col));
  }

  static void _line(Canvas c, double x1, double y1, double x2, double y2, Color col, double w) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), _p(col, style: PaintingStyle.stroke, w: w));

  static void _arc(Canvas c, Rect r, double start, double sweep, Color col, double w) => c.drawArc(
      r, start, sweep, false, _p(col, style: PaintingStyle.stroke, w: w));

  // ── people ─────────────────────────────────────────────────────────────
  static void _portrait(
    Canvas c, {
    required Color skin,
    required Color hair,
    required Color cloth,
    required Color border,
    bool glasses = false,
    bool bun = false,
    bool bindi = false,
    bool moustache = false,
    bool young = false,
  }) {
    final double faceY = young ? 42 : 40;
    final double faceR = young ? 17 : 18.5;

    // shoulders / traditional drape
    final Path body = Path()
      ..moveTo(10, 100)
      ..quadraticBezierTo(14, 72, 34, 64)
      ..lineTo(66, 64)
      ..quadraticBezierTo(86, 72, 90, 100)
      ..close();
    c.drawPath(body, _p(cloth));
    // chador / border stripe over the shoulder
    final Path drape = Path()
      ..moveTo(30, 66)
      ..quadraticBezierTo(50, 82, 72, 70)
      ..lineTo(78, 79)
      ..quadraticBezierTo(52, 94, 26, 76)
      ..close();
    c.drawPath(drape, _p(border.withValues(alpha: 0.92)));
    for (int i = 0; i < 4; i++) {
      _line(c, 32.0 + i * 12, 70.0 + i * 1.5, 36.0 + i * 12, 78.0 + i * 1.5,
          Colors.white.withValues(alpha: 0.55), 1.2);
    }

    // neck
    _rr(c, 44, faceY + faceR - 6, 12, 14, 5, skin);
    // hair back
    if (!young) _circle(c, 50, faceY - 1, faceR + 3.2, hair);
    // face
    _oval(c, 50, faceY, faceR * 2, faceR * 2.18, skin);
    // hair front
    final Path fringe = Path()
      ..moveTo(50 - faceR - 1, faceY - 1)
      ..quadraticBezierTo(50, faceY - faceR * 1.9, 50 + faceR + 1, faceY - 1)
      ..quadraticBezierTo(50, faceY - faceR * 0.42, 50 - faceR - 1, faceY - 1)
      ..close();
    c.drawPath(fringe, _p(hair));
    if (bun) _circle(c, 50, faceY - faceR - 5.5, 7, hair);

    // eyes
    final Color eye = const Color(0xFF3A322B);
    _circle(c, 43.5, faceY + 1, 1.9, eye);
    _circle(c, 56.5, faceY + 1, 1.9, eye);
    // brows
    _arc(c, Rect.fromCenter(center: Offset(43.5, faceY - 2.6), width: 9, height: 7),
        math.pi * 1.08, math.pi * 0.84, hair, 1.5);
    _arc(c, Rect.fromCenter(center: Offset(56.5, faceY - 2.6), width: 9, height: 7),
        math.pi * 1.08, math.pi * 0.84, hair, 1.5);
    // smile
    _arc(c, Rect.fromCenter(center: Offset(50, faceY + 7), width: 13, height: 10),
        math.pi * 0.14, math.pi * 0.72, const Color(0xFF9C5B4A), 1.8);
    // cheeks
    _circle(c, 39.5, faceY + 6, 3.2, const Color(0x33C9694F));
    _circle(c, 60.5, faceY + 6, 3.2, const Color(0x33C9694F));

    if (bindi) _circle(c, 50, faceY - 10.5, 1.9, const Color(0xFFB8302A));
    if (moustache) {
      _arc(c, Rect.fromCenter(center: Offset(50, faceY + 3.6), width: 14, height: 8),
          math.pi * 0.12, math.pi * 0.76, hair, 2.4);
    }
    if (glasses) {
      final Color frame = const Color(0xFF6B625A);
      _arc(c, Rect.fromCircle(center: Offset(43.5, faceY + 1), radius: 6), 0, math.pi * 2, frame, 1.5);
      _arc(c, Rect.fromCircle(center: Offset(56.5, faceY + 1), radius: 6), 0, math.pi * 2, frame, 1.5);
      _line(c, 49.5, faceY + 1, 50.5, faceY + 1, frame, 1.5);
      _line(c, 37.5, faceY, 33, faceY - 1.5, frame, 1.5);
      _line(c, 62.5, faceY, 67, faceY - 1.5, frame, 1.5);
    }
  }

  // ── culture & objects ──────────────────────────────────────────────────
  static void _weaving(Canvas c) {
    // loom frame
    const Color wood = Color(0xFF9A6B45);
    const Color woodDark = Color(0xFF7A5233);
    _rr(c, 12, 20, 6, 68, 3, woodDark);
    _rr(c, 82, 20, 6, 68, 3, woodDark);
    _rr(c, 12, 20, 76, 6, 3, wood);
    // warp threads
    for (int i = 0; i < 13; i++) {
      _line(c, 21.0 + i * 4.8, 26, 21.0 + i * 4.8, 78, const Color(0xFFF6EBDC), 1.6);
    }
    // woven cloth with gamosa-red motif
    _rr(c, 19, 46, 62, 32, 2, const Color(0xFFFBF4E8));
    for (int i = 0; i < 4; i++) {
      _rr(c, 19, 49.0 + i * 7.5, 62, 2.4, 1, const Color(0xFFC0392B));
    }
    // diamond motifs
    for (int i = 0; i < 5; i++) {
      final double x = 26.0 + i * 12;
      _poly(c, <Offset>[Offset(x, 60), Offset(x + 4.5, 64.5), Offset(x, 69), Offset(x - 4.5, 64.5)],
          const Color(0xFFC0392B));
    }
    // shuttle
    _poly(c, <Offset>[
      const Offset(24, 40),
      const Offset(50, 34),
      const Offset(76, 40),
      const Offset(50, 44),
    ], const Color(0xFFB5794C));
    _circle(c, 50, 39, 3, const Color(0xFF2E7D6B));
  }

  static void _gamosa(Canvas c) {
    _rr(c, 16, 14, 68, 74, 4, const Color(0xFFFCF7EE));
    const Color red = Color(0xFFC0392B);
    _rr(c, 16, 20, 68, 4, 1, red);
    _rr(c, 16, 78, 68, 4, 1, red);
    for (int i = 0; i < 4; i++) {
      final double y = 32.0 + i * 12;
      for (int j = 0; j < 4; j++) {
        final double x = 26.0 + j * 16;
        _poly(c, <Offset>[Offset(x, y), Offset(x + 5, y + 5), Offset(x, y + 10), Offset(x - 5, y + 5)],
            i.isEven ? red : const Color(0xFFE0913A));
      }
    }
    // fringe
    for (int i = 0; i < 12; i++) {
      _line(c, 18.0 + i * 5.8, 88, 18.0 + i * 5.8, 94, const Color(0xFFE7DCC9), 1.6);
    }
  }

  static void _pitha(Canvas c) {
    // banana leaf
    final Path leaf = Path()
      ..moveTo(8, 62)
      ..quadraticBezierTo(50, 34, 92, 62)
      ..quadraticBezierTo(50, 88, 8, 62)
      ..close();
    c.drawPath(leaf, _p(const Color(0xFF4F8B47)));
    _line(c, 12, 62, 88, 62, const Color(0xFF3C6C36), 1.6);
    // rice cakes (til pitha rolls)
    _rr(c, 24, 48, 30, 12, 6, const Color(0xFFF3E3C6));
    _rr(c, 50, 54, 28, 12, 6, const Color(0xFFEFDBB8));
    _rr(c, 34, 62, 26, 11, 5.5, const Color(0xFFF6E9D2));
    for (int i = 0; i < 5; i++) {
      _circle(c, 30.0 + i * 6, 54, 0.9, const Color(0xFF6B4A2E));
      _circle(c, 56.0 + i * 5, 60, 0.9, const Color(0xFF6B4A2E));
    }
    // steam
    for (int i = 0; i < 3; i++) {
      _arc(c, Rect.fromCenter(center: Offset(38.0 + i * 12, 34), width: 10, height: 16),
          math.pi * 0.2, math.pi * 1.3, const Color(0x55FFFFFF), 2.4);
    }
  }

  static void _dhol(Canvas c) {
    const Color body = Color(0xFF8C5A34);
    final Path barrel = Path()
      ..moveTo(24, 32)
      ..quadraticBezierTo(14, 50, 24, 68)
      ..lineTo(76, 68)
      ..quadraticBezierTo(86, 50, 76, 32)
      ..close();
    c.drawPath(barrel, _p(body));
    _oval(c, 24, 50, 18, 40, const Color(0xFFF0E2CC));
    _oval(c, 76, 50, 16, 36, const Color(0xFFE6D5BB));
    _oval(c, 24, 50, 12, 28, const Color(0xFFDCCBAF));
    // lacing
    for (int i = 0; i < 7; i++) {
      _line(c, 26, 34.0 + i * 5.4, 74, 36.0 + i * 4.6, const Color(0xFFD9BE93), 1.2);
    }
    // sticks
    _line(c, 12, 82, 40, 66, const Color(0xFF7A5233), 2.6);
    _line(c, 88, 84, 62, 70, const Color(0xFF7A5233), 2.6);
    _circle(c, 12, 82, 3, const Color(0xFF5F3E27));
  }

  static void _pepa(Canvas c) {
    // buffalo-horn pipe
    final Path horn = Path()
      ..moveTo(20, 74)
      ..quadraticBezierTo(52, 78, 74, 50)
      ..quadraticBezierTo(84, 36, 76, 24)
      ..quadraticBezierTo(70, 40, 56, 52)
      ..quadraticBezierTo(40, 64, 20, 66)
      ..close();
    c.drawPath(horn, _p(const Color(0xFFE9E1CF)));
    _line(c, 24, 70, 62, 54, const Color(0xFFCEC3AA), 1.4);
    // reed
    _rr(c, 8, 66, 18, 7, 3.5, const Color(0xFF9BA05C));
    _circle(c, 10, 69.5, 3.2, const Color(0xFF7C8148));
    // notes
    _circle(c, 82, 18, 3.4, const Color(0xFF2E7D6B));
    _line(c, 85, 18, 85, 8, const Color(0xFF2E7D6B), 1.8);
    _circle(c, 66, 14, 2.6, const Color(0xFFE0913A));
    _line(c, 68.4, 14, 68.4, 6, const Color(0xFFE0913A), 1.6);
  }

  static void _gogona(Canvas c) {
    // bamboo jaw-harp: a slender forked blade
    const Color bamboo = Color(0xFFB9C46B);
    final Path blade = Path()
      ..moveTo(46, 84)
      ..lineTo(54, 84)
      ..lineTo(58, 34)
      ..lineTo(52, 34)
      ..lineTo(51, 62)
      ..lineTo(49, 62)
      ..lineTo(48, 34)
      ..lineTo(42, 34)
      ..close();
    c.drawPath(blade, _p(bamboo));
    _rr(c, 42, 78, 16, 4, 2, const Color(0xFF8E9A46));
    _line(c, 50, 34, 50, 24, const Color(0xFF8E9A46), 1.6);
    // vibration arcs
    for (int i = 1; i <= 3; i++) {
      _arc(c, Rect.fromCircle(center: const Offset(50, 50), radius: 16.0 + i * 8),
          -math.pi * 0.85, math.pi * 0.5, const Color(0x552E7D6B), 2.0);
      _arc(c, Rect.fromCircle(center: const Offset(50, 50), radius: 16.0 + i * 8),
          -math.pi * 0.35, math.pi * 0.5, const Color(0x552E7D6B), 2.0);
    }
  }

  static void _bihu(Canvas c) {
    _circle(c, 74, 26, 15, const Color(0xFFF3B85F));
    // dancers
    _dancer(c, 32, const Color(0xFFC0392B), const Color(0xFFFBF4E8));
    _dancer(c, 58, const Color(0xFF2E7D6B), const Color(0xFFF6E9D2));
    _rr(c, 0, 84, 100, 16, 0, const Color(0xFF6FA05C));
  }

  static void _dancer(Canvas c, double x, Color skirtBorder, Color skirt) {
    _circle(c, x, 40, 6, const Color(0xFFD9A277));
    _circle(c, x, 36.5, 6.4, const Color(0xFF2E2823));
    _poly(c, <Offset>[
      Offset(x - 12, 86),
      Offset(x - 5, 50),
      Offset(x + 5, 50),
      Offset(x + 12, 86),
    ], skirt);
    _rr(c, x - 12.5, 80, 25, 5, 2, skirtBorder);
    _rr(c, x - 9, 50, 18, 4, 2, skirtBorder);
    _line(c, x - 5, 54, x - 16, 42, const Color(0xFFD9A277), 3.2);
    _line(c, x + 5, 54, x + 16, 42, const Color(0xFFD9A277), 3.2);
  }

  static void _villageHome(Canvas c) {
    _rr(c, 0, 74, 100, 26, 0, const Color(0xFF7FAA63));
    // betel-nut trees
    for (final double x in <double>[12, 90]) {
      _line(c, x, 76, x - 1, 26, const Color(0xFF8A7A55), 3);
      for (int i = 0; i < 5; i++) {
        final double a = -math.pi / 2 + (i - 2) * 0.55;
        _line(c, x - 1, 26, x - 1 + math.cos(a) * 15, 26 + math.sin(a) * 13,
            const Color(0xFF4F8B47), 3.4);
      }
    }
    // thatched roof
    _poly(c, <Offset>[
      const Offset(20, 52),
      const Offset(50, 26),
      const Offset(80, 52),
    ], const Color(0xFFC79A5E));
    _poly(c, <Offset>[
      const Offset(20, 52),
      const Offset(80, 52),
      const Offset(83, 57),
      const Offset(17, 57),
    ], const Color(0xFFAF8248));
    // bamboo walls
    _rr(c, 26, 57, 48, 24, 2, const Color(0xFFE2CFA9));
    for (int i = 0; i < 7; i++) {
      _line(c, 28.0 + i * 6.7, 58, 28.0 + i * 6.7, 80, const Color(0xFFCBB68C), 1.2);
    }
    _rr(c, 44, 63, 12, 18, 1.5, const Color(0xFF7A5233));
    _rr(c, 31, 62, 8, 8, 1.5, const Color(0xFF9C7A4E));
    _rr(c, 61, 62, 8, 8, 1.5, const Color(0xFF9C7A4E));
  }

  static void _river(Canvas c) {
    _circle(c, 76, 24, 11, const Color(0xFFF6C56B));
    _poly(c, <Offset>[const Offset(0, 56), const Offset(28, 34), const Offset(56, 56)],
        const Color(0xFF8FA9BE));
    _poly(c, <Offset>[const Offset(40, 56), const Offset(70, 30), const Offset(100, 56)],
        const Color(0xFF7392AC));
    _rr(c, 0, 54, 100, 46, 0, const Color(0xFF7EB3D0));
    for (int i = 0; i < 5; i++) {
      _arc(c, Rect.fromCenter(center: Offset(20.0 + (i * 21) % 80, 68.0 + i * 6), width: 22, height: 8),
          math.pi, math.pi, const Color(0x66FFFFFF), 1.8);
    }
    // country boat
    final Path boat = Path()
      ..moveTo(30, 78)
      ..quadraticBezierTo(50, 90, 72, 78)
      ..close();
    c.drawPath(boat, _p(const Color(0xFF7A5233)));
    _line(c, 51, 78, 51, 56, const Color(0xFF5F3E27), 2);
    _poly(c, <Offset>[const Offset(52, 57), const Offset(68, 74), const Offset(52, 74)],
        const Color(0xFFF6EBDC));
  }

  static void _teaGarden(Canvas c) {
    _poly(c, <Offset>[const Offset(0, 40), const Offset(34, 18), const Offset(70, 40)],
        const Color(0xFFA9BFC9));
    _poly(c, <Offset>[const Offset(40, 40), const Offset(78, 22), const Offset(100, 40)],
        const Color(0xFF93AEBC));
    _rr(c, 0, 36, 100, 64, 0, const Color(0xFF8DB56A));
    for (int row = 0; row < 5; row++) {
      final double y = 46.0 + row * 12;
      for (int i = 0; i < 7; i++) {
        _oval(c, 8.0 + i * 14 + (row.isEven ? 0 : 7), y, 15, 10,
            row.isEven ? const Color(0xFF4F8B47) : const Color(0xFF5E9C52));
      }
    }
    _line(c, 84, 96, 84, 62, const Color(0xFF8A7A55), 2.4);
    _circle(c, 84, 58, 8, const Color(0xFF3C6C36));
  }

  static void _market(Canvas c) {
    _rr(c, 0, 76, 100, 24, 0, const Color(0xFFD9C7A6));
    // awnings
    for (int i = 0; i < 2; i++) {
      final double x = 8.0 + i * 46;
      _rr(c, x, 34, 44, 6, 2, const Color(0xFF7A5233));
      for (int j = 0; j < 5; j++) {
        _poly(c, <Offset>[
          Offset(x + j * 8.8, 40),
          Offset(x + j * 8.8 + 8.8, 40),
          Offset(x + j * 8.8 + 4.4, 48),
        ], j.isEven ? const Color(0xFFC0392B) : const Color(0xFFF6EBDC));
      }
      _line(c, x + 2, 40, x + 2, 76, const Color(0xFF8A7A55), 2);
      _line(c, x + 42, 40, x + 42, 76, const Color(0xFF8A7A55), 2);
    }
    // baskets of produce
    for (int i = 0; i < 4; i++) {
      final double x = 16.0 + i * 22;
      _poly(c, <Offset>[
        Offset(x - 9, 76),
        Offset(x + 9, 76),
        Offset(x + 7, 64),
        Offset(x - 7, 64),
      ], const Color(0xFFC9A567));
      final Color veg = <Color>[
        const Color(0xFF4F8B47),
        const Color(0xFFC0392B),
        const Color(0xFFE0913A),
        const Color(0xFF7A5680),
      ][i];
      for (int j = 0; j < 3; j++) {
        _circle(c, x - 4.0 + j * 4, 62, 3.2, veg);
      }
    }
  }

  static void _hills(Canvas c) {
    _circle(c, 24, 24, 9, const Color(0xFFF6E1B2));
    _poly(c, <Offset>[const Offset(-4, 74), const Offset(26, 36), const Offset(56, 74)],
        const Color(0xFF9FB6C6));
    _poly(c, <Offset>[const Offset(30, 74), const Offset(62, 28), const Offset(96, 74)],
        const Color(0xFF7E9AB0));
    _poly(c, <Offset>[const Offset(60, 74), const Offset(88, 44), const Offset(112, 74)],
        const Color(0xFF64809A));
    _poly(c, <Offset>[const Offset(54, 40), const Offset(62, 28), const Offset(70, 40)], Colors.white);
    // mist
    _rr(c, 6, 66, 60, 5, 2.5, const Color(0x77FFFFFF));
    _rr(c, 40, 58, 46, 4, 2, const Color(0x55FFFFFF));
    _rr(c, 0, 74, 100, 26, 0, const Color(0xFF6E9A62));
  }

  static void _bamboo(Canvas c) {
    for (int i = 0; i < 4; i++) {
      final double x = 18.0 + i * 21;
      final Color col = i.isEven ? const Color(0xFF7FA557) : const Color(0xFF97B96C);
      _rr(c, x, 4, 8, 96, 4, col);
      for (int j = 0; j < 6; j++) {
        _line(c, x, 14.0 + j * 16, x + 8, 14.0 + j * 16, const Color(0xFF5F7F3E), 1.6);
      }
      for (int j = 0; j < 3; j++) {
        final double y = 24.0 + j * 26;
        final Path leaf = Path()
          ..moveTo(x + 8, y)
          ..quadraticBezierTo(x + 22, y - 8, x + 28, y + 2)
          ..quadraticBezierTo(x + 18, y + 5, x + 8, y)
          ..close();
        c.drawPath(leaf, _p(const Color(0xFF4F8B47)));
      }
    }
  }

  static void _rhino(Canvas c) {
    _rr(c, 0, 72, 100, 28, 0, const Color(0xFF8CA85E));
    const Color hide = Color(0xFF8E8B84);
    final Path body = Path()
      ..moveTo(20, 74)
      ..quadraticBezierTo(16, 48, 40, 46)
      ..lineTo(66, 46)
      ..quadraticBezierTo(86, 48, 84, 66)
      ..quadraticBezierTo(82, 76, 74, 74)
      ..close();
    c.drawPath(body, _p(hide));
    // head
    final Path head = Path()
      ..moveTo(16, 60)
      ..quadraticBezierTo(4, 58, 6, 68)
      ..quadraticBezierTo(10, 76, 24, 74)
      ..close();
    c.drawPath(head, _p(const Color(0xFF7F7C76)));
    _poly(c, <Offset>[const Offset(6, 60), const Offset(4, 50), const Offset(12, 58)],
        const Color(0xFFD9CDBA));
    _circle(c, 18, 62, 1.6, const Color(0xFF2A2622));
    _rr(c, 20, 52, 4, 6, 2, const Color(0xFF6E6B66));
    // armour plates
    _line(c, 40, 47, 40, 74, const Color(0xFF77746E), 2);
    _line(c, 62, 47, 62, 74, const Color(0xFF77746E), 2);
    // legs
    _rr(c, 26, 70, 9, 14, 3, const Color(0xFF7F7C76));
    _rr(c, 66, 70, 9, 14, 3, const Color(0xFF7F7C76));
    // grass
    for (int i = 0; i < 10; i++) {
      _line(c, 4.0 + i * 10, 84, 6.0 + i * 10, 74, const Color(0xFF6E8C46), 1.8);
    }
  }

  static void _orchid(Canvas c) {
    _line(c, 50, 96, 50, 40, const Color(0xFF5E8C4A), 3);
    for (int i = 0; i < 3; i++) {
      final Path leaf = Path()
        ..moveTo(50, 80.0 - i * 14)
        ..quadraticBezierTo(28.0 + i * 22, 70.0 - i * 16, 18.0 + i * 34, 84.0 - i * 12)
        ..quadraticBezierTo(34.0 + i * 12, 82.0 - i * 12, 50, 80.0 - i * 14)
        ..close();
      c.drawPath(leaf, _p(const Color(0xFF4F8B47)));
    }
    // foxtail orchid blooms
    for (int i = 0; i < 5; i++) {
      final double y = 22.0 + i * 9;
      final double x = 50 + (i.isEven ? -11 : 11);
      _flower(c, x, y, i.isEven ? const Color(0xFFD9A0C8) : const Color(0xFFE7B8D8));
    }
    _flower(c, 50, 14, const Color(0xFFC98CBB));
  }

  static void _flower(Canvas c, double x, double y, Color col) {
    for (int i = 0; i < 5; i++) {
      final double a = i * math.pi * 2 / 5 - math.pi / 2;
      _oval(c, x + math.cos(a) * 5, y + math.sin(a) * 5, 7, 5.4, col);
    }
    _circle(c, x, y, 2.6, const Color(0xFFF3D06B));
  }

  static void _japi(Canvas c) {
    // conical bamboo sun-hat, decorated
    final Path cone = Path()
      ..moveTo(50, 18)
      ..quadraticBezierTo(92, 58, 92, 70)
      ..quadraticBezierTo(50, 84, 8, 70)
      ..quadraticBezierTo(8, 58, 50, 18)
      ..close();
    c.drawPath(cone, _p(const Color(0xFFE0C48A)));
    for (int i = 1; i < 5; i++) {
      _arc(c, Rect.fromCenter(center: Offset(50, 18.0 + i * 13), width: 20.0 + i * 18, height: 14.0 + i * 6),
          math.pi * 0.08, math.pi * 0.84, const Color(0xFFC5A468), 1.6);
    }
    for (int i = 0; i < 6; i++) {
      final double a = math.pi * 0.16 + i * math.pi * 0.136;
      _line(c, 50, 22, 50 + math.cos(a) * 44, 22 + math.sin(a) * 50, const Color(0xFFC5A468), 1.2);
    }
    // ceremonial red / green motifs
    for (int i = 0; i < 5; i++) {
      final double x = 22.0 + i * 14;
      _poly(c, <Offset>[Offset(x, 60), Offset(x + 4, 65), Offset(x, 70), Offset(x - 4, 65)],
          i.isEven ? const Color(0xFFC0392B) : const Color(0xFF2E7D6B));
    }
    _circle(c, 50, 18, 4, const Color(0xFFC0392B));
  }

  static void _xorai(Canvas c) {
    const Color brass = Color(0xFFC9A227);
    const Color brassDark = Color(0xFFA8851B);
    // base
    _poly(c, <Offset>[
      const Offset(28, 88),
      const Offset(72, 88),
      const Offset(64, 70),
      const Offset(36, 70),
    ], brassDark);
    _rr(c, 24, 86, 52, 8, 4, brass);
    // stem
    _rr(c, 44, 58, 12, 14, 3, brassDark);
    // tray
    final Path tray = Path()
      ..moveTo(14, 56)
      ..quadraticBezierTo(50, 70, 86, 56)
      ..quadraticBezierTo(50, 48, 14, 56)
      ..close();
    c.drawPath(tray, _p(brass));
    // cover / dome
    final Path dome = Path()
      ..moveTo(22, 52)
      ..quadraticBezierTo(50, 8, 78, 52)
      ..close();
    c.drawPath(dome, _p(brass));
    _arc(c, Rect.fromCenter(center: const Offset(50, 44), width: 44, height: 34),
        math.pi, math.pi, brassDark, 1.8);
    _arc(c, Rect.fromCenter(center: const Offset(50, 50), width: 54, height: 30),
        math.pi, math.pi, brassDark, 1.8);
    _circle(c, 50, 12, 3.4, brassDark);
    // offering: gamosa fold
    _rr(c, 34, 52, 32, 5, 2, const Color(0xFFFCF7EE));
    _rr(c, 34, 54, 32, 2, 1, const Color(0xFFC0392B));
  }

  static void _paddy(Canvas c) {
    _rr(c, 0, 0, 100, 100, 0, const Color(0xFFF6F1DA));
    _poly(c, <Offset>[const Offset(0, 34), const Offset(40, 16), const Offset(84, 34)],
        const Color(0xFFA9BFC9));
    for (int band = 0; band < 4; band++) {
      final double y = 34.0 + band * 17;
      _rr(c, 0, y, 100, 17, 0,
          <Color>[
            const Color(0xFFD8CB84),
            const Color(0xFFC8BC72),
            const Color(0xFFBBAF64),
            const Color(0xFFA9A056)
          ][band]);
      for (int i = 0; i < 9; i++) {
        final double x = 6.0 + i * 11 + (band.isEven ? 0 : 5);
        _line(c, x, y + 14, x, y + 4, const Color(0xFF8C8434), 1.4);
        _circle(c, x, y + 3, 2, const Color(0xFFE8DE9A));
      }
    }
  }

  static void _festival(Canvas c) {
    _rr(c, 0, 0, 100, 100, 0, const Color(0x00000000));
    // string of lamps
    _arc(c, Rect.fromCenter(center: const Offset(50, 8), width: 110, height: 44),
        math.pi * 0.12, math.pi * 0.76, const Color(0xFF8A7A55), 1.6);
    for (int i = 0; i < 5; i++) {
      final double x = 14.0 + i * 18;
      final double y = 22 + math.sin(i * 0.8) * 4;
      _poly(c, <Offset>[Offset(x - 6, y), Offset(x + 6, y), Offset(x, y + 12)],
          <Color>[
            const Color(0xFFC0392B),
            const Color(0xFFE0913A),
            const Color(0xFF2E7D6B),
            const Color(0xFF4A7FA5),
            const Color(0xFF7A5680)
          ][i]);
      _circle(c, x, y + 14, 2, const Color(0xFFF3D06B));
    }
    // rangoli-like ground motif
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4;
      _oval(c, 50 + math.cos(a) * 18, 68 + math.sin(a) * 12, 16, 10,
          i.isEven ? const Color(0x66C0392B) : const Color(0x66E0913A));
    }
    _circle(c, 50, 68, 8, const Color(0xFFF3D06B));
    _circle(c, 50, 68, 4, const Color(0xFFC0392B));
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.sceneId);
  final String sceneId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 100, 100));
    Scenes.draw(canvas, sceneId);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.sceneId != sceneId;
}

/// A framed illustration — the app's stand-in for a photograph.
class SceneImage extends StatelessWidget {
  const SceneImage({
    super.key,
    required this.sceneId,
    this.size,
    this.radius = Corners.md,
    this.circle = false,
    this.borderColor,
    this.borderWidth = 0,
    this.fit = true,
  });

  final String sceneId;
  final double? size;
  final double radius;
  final bool circle;
  final Color? borderColor;
  final double borderWidth;
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final List<Color> bg = Scenes.background(sceneId);
    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bg,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : Corners.r(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? Colors.white, width: borderWidth)
            : null,
      ),
      child: ClipRRect(
        borderRadius: circle ? Corners.r(999) : Corners.r(radius),
        child: CustomPaint(painter: _ScenePainter(sceneId), size: Size.infinite),
      ),
    );

    if (size != null) return SizedBox(width: size, height: size, child: content);
    return fit ? AspectRatio(aspectRatio: 1, child: content) : content;
  }
}

/// Illustration + name, used across memory grids and family lists.
class SceneAvatar extends StatelessWidget {
  const SceneAvatar({
    super.key,
    required this.sceneId,
    required this.label,
    this.sublabel,
    this.size = 74,
    this.onTap,
  });

  final String sceneId;
  final String label;
  final String? sublabel;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Corners.r(Corners.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: AppColors.softShadow(y: 4, blur: 12)),
              child: SceneImage(
                sceneId: sceneId,
                size: size,
                circle: true,
                borderColor: Colors.white,
                borderWidth: 3,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: size + 14,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.wght(700),
              ),
            ),
            if (sublabel != null)
              SizedBox(
                width: size + 14,
                child: Text(
                  sublabel!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
