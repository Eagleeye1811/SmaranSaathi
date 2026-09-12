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
import '../auth/auth_role_screen.dart';
import '../caregiver/caregiver_entry.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_shell.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';

/// What the product is, before anyone signs anything.
///
/// The single most important line on this screen is the last one: an app that
/// looks like it might diagnose dementia has to say that it does not, before
/// the first tap rather than in a settings page.
///
/// This is the greeting, and the only thing it asks for is a tap. Signing in
/// and choosing a role both happen on the next screen, [AuthRoleScreen], so a
/// person sees what the product is before being asked who they are — and the
/// account stays an offer rather than a gate, because every screen in this app
/// works without one.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onGetStarted});

  final VoidCallback? onGetStarted;

  /// Continue to the authentication and role screen.
  ///
  /// Already signed in from a previous launch? The account is re-bound and,
  /// if that account already chose a role, the screen is skipped entirely —
  /// nobody answers the same question twice a day. Everyone else lands on
  /// [AuthRoleScreen], which offers the account and takes the role together.
  static Future<void> continueFrom(BuildContext context) async {
    final AuthService? auth = AuthScope.maybeOf(context);
    final AppState state = AppScope.read(context);

    final AuthUser? existing = auth?.currentUser;
    if (existing != null) {
      // Bind the assessment to this uid *before* anything is answered, so the
      // first answer is already filed under the right account. The role the
      // account already belongs to comes back with it.
      await state.signInAccount(existing.uid, roleHint: existing.role);
      if (!context.mounted) return;
      Nav.rootTo(context, sessionHome(state));
      return;
    }

    // No account to re-bind — but a role this device already knows is still
    // an answer, so a returning patient (who never signs in with an email) or
    // anyone on a build without Firebase goes straight back in.
    if (state.canResumeSession) {
      Nav.rootTo(context, sessionHome(state));
      return;
    }

    Nav.rootTo(context, const AuthRoleScreen());
  }

  /// Where a signed-in person belongs.
  ///
  /// A returning account already chose a role, and asking again is asking a
  /// question the app can answer itself. Only an account with no role yet
  /// sees the authentication screen.
  ///
  /// The caregiver goes through [CaregiverEntry] rather than straight to the
  /// shell, so a returning caregiver who abandoned the onboarding half way
  /// resumes it instead of landing on a dashboard with nothing behind it.
  static Widget sessionHome(AppState state) => switch (state.role) {
        AppRole.patient => const PatientShell(),
        AppRole.caregiver => const CaregiverEntry(),
        AppRole.doctor => const DoctorShell(),
        AppRole.none => const AuthRoleScreen(),
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
