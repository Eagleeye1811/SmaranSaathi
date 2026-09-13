import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

/// The SmaranSaathi mark — the shipped app icon, so the logo on screen and the
/// icon on the home screen are the same image.
///
/// The painted mark (a woven gamosa diamond holding a small warm heart) stays
/// as the fallback: it needs no asset, so a build with the image missing
/// degrades to a drawn logo rather than a grey box.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.light = false});

  static const String asset = 'assets/images/app_icon.png';

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            CustomPaint(painter: _MarkPainter(light: light)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.light});
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);

    final RRect shell = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 96, 96), const Radius.circular(30));
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3E9C82), Color(0xFF1E5B4E)],
        ).createShader(const Rect.fromLTWH(2, 2, 96, 96)),
    );

    Path diamond(double r) => Path()
      ..moveTo(50, 50 - r)
      ..lineTo(50 + r, 50)
      ..lineTo(50, 50 + r)
      ..lineTo(50 - r, 50)
      ..close();

    canvas.drawPath(
      diamond(33),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      diamond(21),
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );

    // heart
    final Path heart = Path()
      ..moveTo(50, 60)
      ..cubicTo(36, 50, 40, 38, 50, 45)
      ..cubicTo(60, 38, 64, 50, 50, 60)
      ..close();
    canvas.drawPath(heart, Paint()..color = const Color(0xFFE8705C));
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.light != light;
}

/// Wordmark + optional tagline.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.size = 44,
    this.showTagline = true,
    this.center = false,
    this.onDark = false,
  });

  final double size;
  final bool showTagline;
  final bool center;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color ink = onDark ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      children: <Widget>[
        BrandMark(size: size),
        const SizedBox(width: 12),
        Flexible(
          fit: center ? FlexFit.loose : FlexFit.tight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'Smaran',
                      style: AppText.h2.sized(size * 0.52).wght(800).tint(ink),
                    ),
                    TextSpan(
                      text: 'Saathi',
                      style: AppText.h2
                          .sized(size * 0.52)
                          .wght(800)
                          .tint(onDark ? AppColors.accentSoft : AppColors.primary),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showTagline) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  'A gentle companion for every memory',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption
                      .sized(size * 0.27)
                      .tint(onDark ? Colors.white70 : AppColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The identity strip carrying the brand into screens that used to show no
/// branding at all — the app's own mark, plus whatever belongs on the same
/// line beside it.
///
/// Brand on the left, [trailing] on the right, a `Spacer` between: real,
/// non-overlapping layout rather than centering the lockup against the
/// strip's full width. A strip that also carries action buttons cannot
/// afford true centering — the middle of the *whole* strip can sit closer
/// to those buttons than the lockup's own width allows, overlapping them
/// instead of sitting beside them. The plain, centered version of this
/// lockup (no competing content) is what the authentication screens use
/// directly, and stays as it is.
class BrandHeaderBar extends StatelessWidget {
  const BrandHeaderBar({
    super.key,
    this.leading,
    this.trailing,
    this.size = 32,
  });

  final Widget? leading;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, 6, Insets.gutter, 6),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 10)],
          BrandLockup(size: size, center: true, showTagline: false),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

