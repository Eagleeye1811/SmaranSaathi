import 'package:flutter/material.dart';

/// The MemoryMitra palette.
///
/// Warm, calm and non-clinical. Greens and teals carry the product identity,
/// warm ochre/terracotta accents come from North-Eastern textile dyes, and the
/// backgrounds stay off-white so screens never feel cold or hospital-like.
class AppColors {
  const AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2E7D6B); // deep muted teal-green
  static const Color primarySoft = Color(0xFF5CA890);
  static const Color primaryTint = Color(0xFFE3F0EA);
  static const Color primaryDeep = Color(0xFF1E5B4E);

  static const Color secondary = Color(0xFF4A7FA5); // gentle blue
  static const Color secondarySoft = Color(0xFF7FAFCE);
  static const Color secondaryTint = Color(0xFFE4EEF5);

  // ── Warm accents (textile dyes of the region) ──────────────────────────
  static const Color accent = Color(0xFFE0913A); // turmeric / warm yellow
  static const Color accentSoft = Color(0xFFF3C583);
  static const Color accentTint = Color(0xFFFCF0DE);

  static const Color terracotta = Color(0xFFC9694F); // madder red
  static const Color terracottaTint = Color(0xFFFAE8E2);

  static const Color indigo = Color(0xFF3F5B86);
  static const Color indigoTint = Color(0xFFE7EBF3);

  static const Color plum = Color(0xFF7A5680);
  static const Color plumTint = Color(0xFFF1E9F3);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFBF7F1); // warm off-white
  static const Color backgroundAlt = Color(0xFFF5EFE6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F2EA);

  static const Color ink = Color(0xFF2A2622); // warm near-black
  static const Color inkSoft = Color(0xFF5C544A);
  static const Color inkMuted = Color(0xFF8C8377);
  static const Color hairline = Color(0xFFE9E1D5);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF3E9268);
  static const Color successTint = Color(0xFFE2F1E9);
  static const Color warning = Color(0xFFD9962B);
  static const Color warningTint = Color(0xFFFBF0DA);
  static const Color danger = Color(0xFFC0503F);
  static const Color dangerTint = Color(0xFFFBE7E3);

  // ── Clinician surface (cooler, more professional) ──────────────────────
  static const Color clinicBackground = Color(0xFFF4F6F9);
  static const Color clinicSurface = Color(0xFFFFFFFF);
  static const Color clinicInk = Color(0xFF1B2430);
  static const Color clinicInkSoft = Color(0xFF5A6779);
  static const Color clinicHairline = Color(0xFFE2E7EF);
  static const Color clinicAccent = Color(0xFF2F6D8F);

  // ── High contrast overrides (patient accessibility mode) ───────────────
  static const Color hcBackground = Color(0xFFFFFFFF);
  static const Color hcInk = Color(0xFF000000);
  static const Color hcPrimary = Color(0xFF0F5A48);
  static const Color hcHairline = Color(0xFF1B1B1B);

  // ── Chart series ───────────────────────────────────────────────────────
  // The UI palette above is deliberately muted, which makes it unsafe for
  // encoding *identity*. These six are the chromatic siblings of the brand
  // hues, assigned in fixed order and never cycled. Verified for lightness
  // band, chroma floor and colour-vision-deficiency separation; the ochre
  // slot sits just under 3:1 on white, so charts always carry direct labels
  // or a legend rather than relying on colour alone.
  static const Color seriesTeal = Color(0xFF12876A);
  static const Color seriesOchre = Color(0xFFD98A16);
  static const Color seriesBlue = Color(0xFF2F7FB8);
  static const Color seriesClay = Color(0xFFD2553A);
  static const Color seriesPlum = Color(0xFF8B4E96);
  static const Color seriesLeaf = Color(0xFF5FA33A);

  static const List<Color> chartSeries = <Color>[
    seriesTeal,
    seriesOchre,
    seriesBlue,
    seriesClay,
    seriesPlum,
    seriesLeaf,
  ];

  /// Sequential ramp (one hue, light → dark) for magnitude encodings.
  static const List<Color> sequentialTeal = <Color>[
    Color(0xFFD6EDE5),
    Color(0xFF9FD4C3),
    Color(0xFF63B79C),
    Color(0xFF2E9077),
    Color(0xFF12876A),
    Color(0xFF0B5C48),
  ];

  /// A soft, non-gaudy shadow used on every raised card.
  static List<BoxShadow> softShadow({double y = 8, double blur = 24, double opacity = 0.06}) {
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF3A2E1E).withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
  }

  static List<BoxShadow> liftShadow() => <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF3A2E1E).withValues(alpha: 0.10),
          blurRadius: 34,
          offset: const Offset(0, 14),
        ),
      ];
}
