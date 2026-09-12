import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/auth_user.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/role_selection_screen.dart';
import '../caregiver/caregiver_shell.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_entry.dart';
import '../auth/sign_in_screen.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';

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
      Nav.rootTo(context, sessionHome(state));
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
          Nav.rootTo(context, sessionHome(state));
        },
      ),
    );
  }

  /// Where a signed-in person belongs.
  ///
  /// A returning account already chose a role, and asking again is asking a
  /// question the app can answer itself. Only an account with no role yet
  /// sees the picker.
  static Widget sessionHome(AppState state) => switch (state.role) {
        AppRole.patient => const PatientEntry(),
        AppRole.caregiver => const CaregiverShell(),
        AppRole.doctor => const DoctorShell(),
        AppRole.none => const RoleSelectionScreen(),
      };

  static List<({IconData icon, String title, String detail})> _pillars(AppLocalizations l) =>
      <({IconData icon, String title, String detail})>[
    (
      icon: Icons.fact_check_outlined,
      title: l.intakePillarUnderstandTitle,
      detail: l.intakePillarUnderstandDetail,
    ),
    (
      icon: Icons.timeline_rounded,
      title: l.intakePillarTrackTitle,
      detail: l.intakePillarTrackDetail,
    ),
    (
      icon: Icons.medical_information_outlined,
      title: l.intakePillarSupportTitle,
      detail: l.intakePillarSupportDetail,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
                    Text(l.intakeWelcomeHeadline, style: AppText.display),
                    const SizedBox(height: Insets.md),
                    Text(
                      l.intakeWelcomeSubtitle,
                      style: AppText.bodyLarge.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: Insets.xl),
                    for (final ({IconData icon, String title, String detail}) p in _pillars(l))
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
                          'SmaranSaathi supports monitoring and understanding. It does '
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
                      label: l.intakeGetStarted,
                      icon: Icons.arrow_forward_rounded,
                      onPressed: onGetStarted ?? () => continueFrom(context),
                    ),
                    const SizedBox(height: Insets.xs),
                    TextButton(
                      onPressed: () => continueFrom(context),
                      child: Text(l.intakeAlreadyHaveAccount,
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
