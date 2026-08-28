import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Navigation helpers. The prototype uses imperative navigation with a couple
/// of shared, deliberately gentle transitions — nothing in the app should snap
/// or slide aggressively.
class Nav {
  const Nav._();

  /// Soft fade-through: the default for moving between major surfaces.
  static Route<T> fade<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      transitionDuration: duration ?? const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, Animation<double> a, __, Widget child) {
        final Animation<double> curved =
            CurvedAnimation(parent: a, curve: Motion.enter, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Used when entering an activity: the new screen rises from below.
  static Route<T> rise<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 440),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, Animation<double> a, __, Widget child) {
        final Animation<double> curved =
            CurvedAnimation(parent: a, curve: Motion.enter, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<T?> push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(fade<T>(page));

  static Future<T?> open<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(rise<T>(page));

  static Future<T?> replace<T>(BuildContext context, Widget page) =>
      Navigator.of(context).pushReplacement<T, dynamic>(fade<T>(page));

  static void rootTo(BuildContext context, Widget page) {
    Navigator.of(context).pushAndRemoveUntil(fade<void>(page), (Route<dynamic> r) => false);
  }
}
