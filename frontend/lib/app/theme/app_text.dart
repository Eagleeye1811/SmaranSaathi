import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography for SmaranSaathi.
///
/// Nunito ships as a single variable font file, so weight is applied through
/// `fontVariations` (a plain `fontWeight` would be ignored by the shaper).
/// Always build styles through [AppText] or the [WeightedTextStyle] extension
/// so weight stays consistent everywhere.
class AppText {
  const AppText._();

  static const String family = 'Nunito';

  /// Nunito is Latin-only. Hindi/Marathi (Devanagari) and Assamese (Bengali
  /// script) glyphs fall through to these instead of whatever the OS's
  /// default font happens to be — regional-language text stays legible and
  /// visually consistent instead of silently switching typeface mid-app.
  static const List<String> familyFallback = <String>[
    'NotoSansDevanagari',
    'NotoSansBengali',
  ];

  static TextStyle _s(double size, double weight, {double? height, double? tracking, Color? color}) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: familyFallback,
      fontSize: size,
      height: height ?? 1.28,
      letterSpacing: tracking,
      color: color ?? AppColors.ink,
      fontWeight: _fw(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
    );
  }

  static FontWeight _fw(double w) {
    if (w >= 850) return FontWeight.w900;
    if (w >= 750) return FontWeight.w800;
    if (w >= 650) return FontWeight.w700;
    if (w >= 550) return FontWeight.w600;
    if (w >= 450) return FontWeight.w500;
    if (w >= 350) return FontWeight.w400;
    return FontWeight.w300;
  }

  // ── Display / hero ─────────────────────────────────────────────────────
  static TextStyle get display => _s(40, 800, height: 1.12, tracking: -0.9);
  static TextStyle get hero => _s(32, 800, height: 1.14, tracking: -0.6);

  // ── Headings ───────────────────────────────────────────────────────────
  static TextStyle get h1 => _s(27, 800, height: 1.18, tracking: -0.4);
  static TextStyle get h2 => _s(22, 700, height: 1.22, tracking: -0.2);
  static TextStyle get h3 => _s(19, 700, height: 1.26);

  // ── Body ───────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => _s(18, 500, height: 1.45);
  static TextStyle get body => _s(16, 500, height: 1.45);
  static TextStyle get bodySmall => _s(14.5, 500, height: 1.4, color: AppColors.inkSoft);

  // ── Supporting ─────────────────────────────────────────────────────────
  static TextStyle get label => _s(13.5, 700, tracking: 0.2, color: AppColors.inkSoft);
  static TextStyle get overline => _s(11.5, 800, tracking: 1.4, color: AppColors.inkMuted);
  static TextStyle get caption => _s(12.5, 500, color: AppColors.inkMuted);

  // ── Numerals (dashboards, results) ─────────────────────────────────────
  static TextStyle get statHuge => _s(48, 800, height: 1.0, tracking: -1.4);
  static TextStyle get statLarge => _s(30, 800, height: 1.05, tracking: -0.7);
  static TextStyle get stat => _s(22, 800, height: 1.05, tracking: -0.3);

  /// Patient-facing text: bigger, calmer, more generous line height.
  static TextStyle get patientTitle => _s(30, 800, height: 1.2, tracking: -0.5);
  static TextStyle get patientBody => _s(20, 500, height: 1.5);
  static TextStyle get patientButton => _s(20, 700, height: 1.2);
  static TextStyle get companionSpeech => _s(22, 600, height: 1.42);

  static TextTheme textTheme() => TextTheme(
        displayLarge: display,
        displayMedium: hero,
        displaySmall: h1,
        headlineLarge: h1,
        headlineMedium: h2,
        headlineSmall: h3,
        titleLarge: h3,
        titleMedium: _s(16, 700),
        titleSmall: _s(14, 700),
        bodyLarge: bodyLarge,
        bodyMedium: body,
        bodySmall: bodySmall,
        labelLarge: _s(15, 700),
        labelMedium: label,
        labelSmall: overline,
      );
}

extension WeightedTextStyle on TextStyle {
  /// Sets a variable-font weight (and a matching [FontWeight] for fallbacks).
  TextStyle wght(double w) => copyWith(
        fontWeight: AppText._fw(w),
        fontVariations: <FontVariation>[FontVariation('wght', w)],
      );

  TextStyle tint(Color c) => copyWith(color: c);

  TextStyle sized(double s) => copyWith(fontSize: s);
}
