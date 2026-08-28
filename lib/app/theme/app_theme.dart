import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Shared spacing / radius scale. Generous by design — elderly users need air.
class Insets {
  const Insets._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 30;
  static const double xxl = 42;

  /// Standard horizontal page padding.
  static const double gutter = 20;
}

class Corners {
  const Corners._();
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double xl = 34;
  static const double pill = 999;

  static BorderRadius r(double v) => BorderRadius.circular(v);
}

class Motion {
  const Motion._();
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);
  static const Duration breathe = Duration(milliseconds: 3400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve emphatic = Curves.easeOutBack;
  static const Curve gentle = Curves.easeInOutCubic;
}

class AppTheme {
  const AppTheme._();

  static const SystemUiOverlayStyle warmOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// The warm patient / caregiver theme.
  static ThemeData warm({bool highContrast = false}) {
    final Color bg = highContrast ? AppColors.hcBackground : AppColors.background;
    final Color primary = highContrast ? AppColors.hcPrimary : AppColors.primary;
    final Color ink = highContrast ? AppColors.hcInk : AppColors.ink;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryTint,
      tertiary: AppColors.accent,
      tertiaryContainer: AppColors.accentTint,
      surface: highContrast ? Colors.white : AppColors.surface,
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surfaceMuted,
      surfaceContainer: AppColors.backgroundAlt,
      error: AppColors.danger,
      errorContainer: AppColors.dangerTint,
      outline: highContrast ? AppColors.hcHairline : AppColors.hairline,
      outlineVariant: highContrast ? AppColors.hcHairline : AppColors.hairline,
    );

    return _base(scheme, bg, ink, AppText.textTheme());
  }

  /// Cooler, denser theme for the clinician experience.
  static ThemeData clinic() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.clinicAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.clinicAccent,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE1EDF4),
      onPrimaryContainer: const Color(0xFF17475E),
      secondary: AppColors.primary,
      surface: AppColors.clinicSurface,
      onSurface: AppColors.clinicInk,
      outline: AppColors.clinicHairline,
      outlineVariant: AppColors.clinicHairline,
      error: AppColors.danger,
    );

    final TextTheme t = AppText.textTheme().apply(
      bodyColor: AppColors.clinicInk,
      displayColor: AppColors.clinicInk,
    );
    return _base(scheme, AppColors.clinicBackground, AppColors.clinicInk, t);
  }

  static ThemeData _base(ColorScheme scheme, Color bg, Color ink, TextTheme text) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      fontFamily: AppText.family,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.h2.tint(ink),
        iconTheme: IconThemeData(color: ink, size: 26),
        systemOverlayStyle: warmOverlay,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.lg)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.pill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline, width: 1.6),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.pill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        labelStyle: text.labelMedium,
        border: OutlineInputBorder(
          borderRadius: Corners.r(Corners.md),
          borderSide: BorderSide(color: scheme.outline, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.r(Corners.md),
          borderSide: BorderSide(color: scheme.outline, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.r(Corners.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.md)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(color: scheme.outline),
        labelStyle: text.labelMedium!,
        shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.pill)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionBuilder(),
          TargetPlatform.macOS: _FadeThroughTransitionBuilder(),
        },
      ),
    );
  }
}

class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final CurvedAnimation curved =
        CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
