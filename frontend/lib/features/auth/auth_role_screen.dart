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
import '../../core/widgets/illustration.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../caregiver/caregiver_entry.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_shell.dart';
import 'sign_in_screen.dart';

/// Signing in and choosing a role, on one screen.
///
/// These were two screens and are now one, because in this app they are one
/// decision. An account only decides *whose* record the answers are filed
/// under — every screen works without one — so a sign-in page standing alone
/// in front of the product was a gate in front of a door that was never
/// locked. Here the account is an offer at the top and the role is the choice
/// that actually moves you on.
///
/// Where each role goes:
///
///  - **Caregiver** opens the onboarding, because the onboarding is written
///    for someone answering about another person ("Who is helping to fill
///    this in?", "What can they still do well?"). This is the setup path, and
///    the card says so.
///  - **Patient** goes straight to their dashboard. Being handed fifteen
///    questions about your own decline is the wrong first thing to meet.
///  - **Doctor** goes straight to the clinician surface.
class AuthRoleScreen extends StatefulWidget {
  const AuthRoleScreen({super.key});

  @override
  State<AuthRoleScreen> createState() => _AuthRoleScreenState();
}

class _AuthRoleScreenState extends State<AuthRoleScreen> {
  /// Set while a sign-out is in flight, so the account row cannot be tapped
  /// twice into an inconsistent state.
  bool _busy = false;

  Future<void> _openSignIn(AuthService auth) async {
    final AppState state = AppScope.read(context);
    await Nav.push(
      context,
      SignInScreen(
        authService: auth,
        // No "skip" here: the role cards behind this screen already are the
        // way past it, so a second escape hatch would just be a second thing
        // to read.
        onSignedIn: (AuthUser user) async {
          await state.signInAccount(user.uid);
          if (!mounted) return;
          Navigator.of(context).pop();
          setState(() {});
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _signOut(AuthService auth) async {
    setState(() => _busy = true);
    final AppState state = AppScope.read(context);
    // Local first: the app must end up signed out even when the network is
    // gone, which on a rural connection it often is.
    await state.signOutAccount();
    try {
      await auth.signOut();
    } catch (error) {
      debugPrint('AuthRoleScreen: signing out of Firebase failed ($error)');
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Records the role in three places — the auth service (so the backend can
  /// authorise by it), the app state, and the navigator — and opens that
  /// role's home.
  void _choose(AppRole role, Widget home) {
    AuthScope.maybeOf(context)?.declareRole(role.name);
    AppScope.read(context).setRole(role);
    Nav.push(context, home);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    final AuthService? auth = AuthScope.maybeOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final bool tall = screen.height > 720;

    return Scaffold(
      body: MotifBackground(
        opacity: 0.055,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.9),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const FadeInUp(child: BrandLockup(size: 46)),
                          SizedBox(height: tall ? 20 : 12),
                          FadeInUp(
                            delayMs: 60,
                            child: Center(
                              child: Companion(
                                state: CompanionState.happy,
                                size: tall ? 150 : 118,
                              ),
                            ),
                          ),
                          SizedBox(height: tall ? 12 : 8),
                          FadeInUp(
                            delayMs: 110,
                            child: Column(
                              children: <Widget>[
                                Text(
                                  l.authTitle,
                                  textAlign: TextAlign.center,
                                  style: AppText.hero.sized(tall ? 28 : 25),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l.authSubtitle,
                                  textAlign: TextAlign.center,
                                  style: AppText.body.tint(AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),

                          // ── the account, offered rather than demanded ──
                          if (auth != null) ...<Widget>[
                            SizedBox(height: tall ? 22 : 16),
                            FadeInUp(
                              delayMs: 140,
                              child: _AccountCard(
                                signedInEmail: state.accountId == null
                                    ? null
                                    : (auth.currentUser?.email ?? auth.currentUser?.uid),
                                busy: _busy,
                                onSignIn: () => _openSignIn(auth),
                                onSignOut: () => _signOut(auth),
                              ),
                            ),
                          ],

                          SizedBox(height: tall ? 24 : 18),
                          FadeInUp(
                            delayMs: 170,
                            child: Row(
                              children: <Widget>[
                                const Expanded(child: Divider(color: AppColors.hairline)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(l.authWhoAreYou.toUpperCase(),
                                      style: AppText.overline),
                                ),
                                const Expanded(child: Divider(color: AppColors.hairline)),
                              ],
                            ),
                          ),
                          const SizedBox(height: Insets.md),

                          // ── the caregiver comes first ──────────────────
                          //
                          // Not alphabetical and not by importance of the
                          // person: the caregiver is the one who sets the
                          // profile up, so on a first launch theirs is the
                          // card that should be under the thumb.
                          FadeInUp(
                            delayMs: 200,
                            child: _RoleCard(
                              sceneId: 'portrait_priya',
                              title: l.authRoleCaregiver,
                              who: l.authRoleCaregiverWho,
                              description: l.authRoleCaregiverDetail,
                              accent: AppColors.primary,
                              tint: AppColors.primaryTint,
                              badge: state.intake.isComplete ? null : l.authStartHere,
                              footnote: l.authCaregiverSetsUp,
                              onTap: () => _choose(AppRole.caregiver, const CaregiverEntry()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FadeInUp(
                            delayMs: 240,
                            child: _RoleCard(
                              sceneId: 'portrait_aama',
                              title: l.authRolePatient,
                              who: l.authRolePatientWho,
                              description: l.authRolePatientDetail,
                              accent: AppColors.terracotta,
                              tint: AppColors.terracottaTint,
                              onTap: () => _choose(AppRole.patient, const PatientShell()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FadeInUp(
                            delayMs: 280,
                            child: _RoleCard(
                              icon: Icons.medical_information_rounded,
                              title: l.authRoleDoctor,
                              who: l.authRoleDoctorWho,
                              description: l.authRoleDoctorDetail,
                              accent: AppColors.secondary,
                              tint: AppColors.secondaryTint,
                              onTap: () => _choose(AppRole.doctor, const DoctorShell()),
                            ),
                          ),
                          SizedBox(height: tall ? 22 : 16),
                          FadeInUp(
                            delayMs: 320,
                            child: Text(
                              l.authDeviceOnlyNote,
                              textAlign: TextAlign.center,
                              style: AppText.caption.copyWith(height: 1.45),
                            ),
                          ),
                          SizedBox(height: tall ? 20 : 14),
                          const FadeInUp(
                            delayMs: 350,
                            child: WovenStrip(height: 10, opacity: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The account row. Deliberately quiet: an account is useful, not required,
/// and this screen should not read as a login wall.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.signedInEmail,
    required this.busy,
    required this.onSignIn,
    required this.onSignOut,
  });

  final String? signedInEmail;
  final bool busy;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool signedIn = signedInEmail != null;

    return MmCard(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
      color: signedIn ? AppColors.primaryTint : AppColors.surface,
      border: Border.all(color: signedIn ? AppColors.primary.withValues(alpha: 0.35) : AppColors.hairline),
      child: Row(
        children: <Widget>[
          SoftIcon(
            icon: signedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded,
            size: 38,
            color: signedIn ? AppColors.primary : AppColors.inkMuted,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  signedIn ? l.authSignedInAs(signedInEmail!) : l.profileNoAccount,
                  style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  signedIn ? l.profileAnswersFiledUnderAccount : l.profileSignInToKeepRecord,
                  style: AppText.caption,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          TextButton(
            onPressed: busy ? null : (signedIn ? onSignOut : onSignIn),
            child: Text(
              signedIn ? l.authSignOut : l.profileSignIn,
              style: AppText.bodySmall.copyWith(
                color: signedIn ? AppColors.inkSoft : AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.who,
    required this.description,
    required this.accent,
    required this.tint,
    required this.onTap,
    this.sceneId,
    this.icon,
    this.badge,
    this.footnote,
  });

  final String title;
  final String who;
  final String description;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;
  final String? sceneId;
  final IconData? icon;

  /// "Start here" on the caregiver card, until the profile has been set up.
  final String? badge;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: Corners.lg,
      border: badge == null ? null : Border.all(color: accent.withValues(alpha: 0.5), width: 1.6),
      shadow: AppColors.softShadow(y: 6, blur: 18, opacity: 0.055),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (sceneId != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: Corners.r(Corners.md),
                    boxShadow: AppColors.softShadow(y: 3, blur: 8),
                  ),
                  child: SceneImage(sceneId: sceneId!, size: 62, radius: Corners.md),
                )
              else
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(color: tint, borderRadius: Corners.r(Corners.md)),
                  child: Icon(icon, size: 30, color: accent),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(child: Text(title, style: AppText.h3.wght(800))),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 8),
                          PillTag(label: badge!, color: accent, dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      who,
                      style: AppText.caption.wght(800).tint(accent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(description, style: AppText.bodySmall, maxLines: 3),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_rounded, size: 19, color: accent),
              ),
            ],
          ),
          if (footnote != null) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(Icons.assignment_outlined, size: 15, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(footnote!,
                      style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
