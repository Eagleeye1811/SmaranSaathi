import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';

/// The very first thing shown on launch — brand + Mitra, briefly, before
/// handing off to [next] (the sign-in gate when one is active, or role
/// selection directly otherwise). Bootstrapping (Hive, Firebase, the
/// previous session) has already finished by the time `main()` calls
/// `runApp` — this isn't covering real loading time, it's a deliberate,
/// short beat so the app doesn't feel like it just snaps into place.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Driven by a vsync'd AnimationController rather than `Future.delayed` /
  // `Timer` on purpose: those run on the real OS clock, which
  // `WidgetTester.pump(duration)` does not fast-forward — a widget test
  // would otherwise have to burn a real 1.1 real-world seconds (or hang,
  // since a single `pump()` call never actually waits that long) to see
  // past this screen. A ticker-driven animation advances with the virtual
  // clock `pump(duration)` controls, so tests move through it instantly.
  late final AnimationController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) setState(() => _ready = true);
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.next;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.055,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.9),
          AppColors.background.withValues(alpha: 0),
        ],
        child: Center(
          child: FadeInUp(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Companion(state: CompanionState.gentle, size: 132),
                const SizedBox(height: 20),
                const BrandLockup(size: 44, center: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
