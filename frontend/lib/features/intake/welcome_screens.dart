import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/auth_user.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/role_selection_screen.dart';
import '../auth/sign_in_screen.dart';
import 'intake_kit.dart';

/// The first thing anyone sees. Two seconds, then out of the way.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.next});

  /// What to show once the splash finishes. Defaults to the welcome screen.
  final Widget? next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Nav.rootTo(context, widget.next ?? const WelcomeScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.05,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Companion(state: CompanionState.idle, size: 132),
              const SizedBox(height: Insets.lg),
              const BrandLockup(size: 34, center: true, showTagline: false),
              const SizedBox(height: Insets.sm),
              Text('Understand. Track. Support.',
                  style: AppText.body.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: Insets.xxl),
              const SizedBox(
                width: 120,
                child: MeterBar(value: 1, height: 4, color: AppColors.primarySoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the product is, before anyone signs anything.
///
/// The single most important line on this screen is the last one: an app that
/// looks like it might diagnose dementia has to say that it does not, before
/// the first tap rather than in a settings page.
///
/// This is also where account setup happens. Sign-in sits *after* the welcome
/// and *before* the intake, so a person sees what the product is before being
/// asked for an email, and every answer they then give is filed under their
/// uid. When no auth service is configured — no Firebase, or a pure demo
/// build — the sign-in step is skipped and the journey is unchanged.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onGetStarted});

  final VoidCallback? onGetStarted;

  /// Sign in if we can, then continue to the role picker.
  ///
  /// Already signed in from a previous launch? The account is re-bound and the
  /// sign-in screen is skipped — nobody types their password twice a day.
  static Future<void> continueFrom(BuildContext context) async {
    final AuthService? auth = AuthScope.maybeOf(context);
    final AppState state = AppScope.read(context);

    if (auth == null) {
      Nav.rootTo(context, const RoleSelectionScreen());
      return;
    }

    final AuthUser? existing = auth.currentUser;
    if (existing != null) {
      await state.signInAccount(existing.uid);
      if (!context.mounted) return;
      Nav.rootTo(context, const RoleSelectionScreen());
      return;
    }

    Nav.push(
      context,
      SignInScreen(
        authService: auth,
        onSkip: () => Nav.rootTo(context, const RoleSelectionScreen()),
        onSignedIn: (AuthUser user) async {
          // Bind the assessment to this uid *before* the intake opens, so the
          // first answer is already filed under the right account.
          await state.signInAccount(user.uid);
          if (!context.mounted) return;
          Nav.rootTo(context, const RoleSelectionScreen());
        },
      ),
    );
  }

  static const List<({IconData icon, String title, String detail})> _pillars =
      <({IconData icon, String title, String detail})>[
    (
      icon: Icons.fact_check_outlined,
      title: 'Understand',
      detail: 'Structured questions about symptoms, daily life and health history',
    ),
    (
      icon: Icons.timeline_rounded,
      title: 'Track',
      detail: 'Six cognitive activities, measured against your own baseline over time',
    ),
    (
      icon: Icons.medical_information_outlined,
      title: 'Support',
      detail: 'A plain-language explanation, and a summary you can take to a doctor',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.04,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.xl, Insets.gutter, Insets.lg),
                  children: <Widget>[
                    const BrandLockup(),
                    const SizedBox(height: Insets.xl),
                    Text('Understand your\ncognitive health.', style: AppText.display),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Notice a change, track what it does over time, and take '
                      'something useful to your doctor.',
                      style: AppText.bodyLarge.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: Insets.xl),
                    for (final ({IconData icon, String title, String detail}) p in _pillars)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: MmCard(
                          padding: const EdgeInsets.all(Insets.md),
                          child: ListRow(
                            leading: SoftIcon(icon: p.icon),
                            title: p.title,
                            subtitle: p.detail,
                          ),
                        ),
                      ),
                    const SizedBox(height: Insets.md),
                    const NotADiagnosisNote(
                      message:
                          'MemoryMitra supports monitoring and understanding. It does '
                          'not detect, diagnose or treat dementia, and it does not '
                          'replace a professional assessment.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.lg),
                child: Column(
                  children: <Widget>[
                    BigButton(
                      label: 'Get started',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: onGetStarted ?? () => continueFrom(context),
                    ),
                    const SizedBox(height: Insets.xs),
                    TextButton(
                      onPressed: () => continueFrom(context),
                      child: Text('I already have an account',
                          style: AppText.body.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
