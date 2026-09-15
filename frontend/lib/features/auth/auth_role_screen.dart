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
import 'patient_sign_in_screen.dart';
import 'sign_in_screen.dart';

/// Signing in and choosing a role, on one screen.
///
/// One screen, in the order the person thinks in: *who am I*, then *let me
/// in*. The role is picked first because it is the question they can actually
/// answer — "am I the daughter or the patient" — and only then does the app
/// ask them to prove who they are.
///
/// Authentication is attempted, not demanded. An account decides *whose*
/// record the answers are filed under; every screen works without one. So
/// when no auth service is configured — no Firebase on this platform, a pure
/// demo build — the button continues straight through rather than stranding
/// someone in front of a form that cannot succeed.
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
  /// Set while a sign-out or an authentication is in flight, so nothing can
  /// be tapped twice into an inconsistent state.
  bool _busy = false;

  /// Chosen, but not yet acted on. Selecting a role is reversible right up
  /// until the button is pressed.
  AppRole? _selected;

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

  Widget _homeFor(AppRole role) => switch (role) {
        AppRole.caregiver => const CaregiverEntry(),
        AppRole.patient => const PatientShell(),
        AppRole.doctor => const DoctorShell(),
        AppRole.none => const SizedBox.shrink(),
      };

  String _labelFor(AppLocalizations l, AppRole role) => switch (role) {
        AppRole.caregiver => l.authRoleCaregiver,
        AppRole.patient => l.authRolePatient,
        AppRole.doctor => l.authRoleDoctor,
        AppRole.none => '',
      };

  /// Authenticate if we can, then open the chosen role's home.
  ///
  /// The role is recorded in three places — the auth service, so the backend
  /// can authorise by it; the app state; and the navigator. It is declared
  /// *after* a successful sign-in so a cancelled sign-in leaves nothing
  /// half-applied.
  Future<void> _authenticateAndContinue() async {
    final AppRole? role = _selected;
    if (role == null || _busy) return;

    // The patient doesn't authenticate here at all — there is no account for
    // them to sign into, so their whole "continue" is just opening the
    // pairing handshake their caregiver approves instead (see
    // `PatientSignInScreen`). Picking the card still only selects it, the
    // same as the other two roles — nothing here jumps ahead of the button.
    if (role == AppRole.patient) {
      Nav.push(context, const PatientSignInScreen());
      return;
    }

    final AuthService? auth = AuthScope.maybeOf(context);
    final AppState state = AppScope.read(context);

    // Caregiver and doctor carry an account; the patient does not, and signs
    // in through their caregiver instead (see `PatientSignInScreen`).
    final bool needsAccount = role == AppRole.caregiver || role == AppRole.doctor;

    if (needsAccount && auth != null && state.accountId == null) {
      setState(() => _busy = true);
      final AuthUser? existing = auth.currentUser;
      if (existing != null) {
        await state.signInAccount(existing.uid, roleHint: existing.role, displayName: existing.displayName, email: existing.email);
      } else {
        final bool signedIn = await _promptSignIn(auth, state);
        if (!mounted) return;
        setState(() => _busy = false);
        // Cancelled. Stay here with the role still selected rather than
        // pushing on as if nothing had been asked.
        if (!signedIn) return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }

    if (!mounted) return;
    AuthScope.maybeOf(context)?.declareRole(role.name);
    // Recorded against the account as well as the device, so the next launch
    // resumes straight into this role instead of asking again.
    state.setRole(role);
    // `rootTo`, not `push`: once someone is inside their app, backing out to
    // the role picker is backing out to a question they have answered.
    Nav.rootTo(context, _homeFor(role));
  }

  /// Opens the sign-in form and reports whether it produced an account.
  Future<bool> _promptSignIn(AuthService auth, AppState state) async {
    bool signedIn = false;
    await Nav.push(
      context,
      SignInScreen(
        authService: auth,
        onSignedIn: (AuthResult result) async {
          final AuthUser user = result.user!;
          // A freshly created account has nothing on this device or the
          // server, so the role claim is the only hint — and for a new
          // account there is not one yet either. Either way the role the
          // person just picked on this screen is applied after this returns.
          await state.signInAccount(user.uid, roleHint: user.role, displayName: user.displayName, email: user.email);
          signedIn = true;
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
    return signedIn;
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
                          const FadeInUp(child: BrandLockup(size: 40)),
                          SizedBox(height: tall ? 14 : 8),
                          FadeInUp(
                            delayMs: 60,
                            child: Center(
                              child: Companion(
                                state: CompanionState.happy,
                                // Smaller than the old 150/118: the mascot was
                                // the single largest thing on the screen, and
                                // trimming it is what actually gets the rest
                                // of the page to fit a typical phone without
                                // scrolling — see the class doc's "always a
                                // way back" note for why scrolling here is
                                // avoided rather than just tolerated.
                                size: tall ? 118 : 92,
                              ),
                            ),
                          ),
                          SizedBox(height: tall ? 10 : 6),
                          FadeInUp(
                            delayMs: 110,
                            child: Column(
                              children: <Widget>[
                                Text(
                                  l.authTitle,
                                  textAlign: TextAlign.center,
                                  style: AppText.hero.sized(tall ? 26 : 23),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l.authSubtitle,
                                  textAlign: TextAlign.center,
                                  style: AppText.body.tint(AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),

                          // ── the account, offered rather than demanded ──
                          if (auth != null && state.accountId != null) ...<Widget>[
                            SizedBox(height: tall ? 16 : 12),
                            FadeInUp(
                              delayMs: 140,
                              child: _AccountCard(
                                signedInEmail:
                                    auth.currentUser?.email ?? auth.currentUser?.uid ?? '',
                                busy: _busy,
                                onSignOut: () => _signOut(auth),
                              ),
                            ),
                          ],

                          SizedBox(height: tall ? 18 : 12),
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
                          const SizedBox(height: Insets.sm),

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
                              onTap: () => setState(() => _selected = AppRole.caregiver),
                              selected: _selected == AppRole.caregiver,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          FadeInUp(
                            delayMs: 240,
                            child: _RoleCard(
                              sceneId: 'portrait_aama',
                              title: l.authRolePatient,
                              who: l.authRolePatientWho,
                              description: l.authPatientEntryBody,
                              accent: AppColors.terracotta,
                              tint: AppColors.terracottaTint,
                              onTap: () => setState(() => _selected = AppRole.patient),
                              selected: _selected == AppRole.patient,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          FadeInUp(
                            delayMs: 280,
                            child: _RoleCard(
                              icon: Icons.medical_information_rounded,
                              title: l.authRoleDoctor,
                              who: l.authRoleDoctorWho,
                              description: l.authRoleDoctorDetail,
                              accent: AppColors.secondary,
                              tint: AppColors.secondaryTint,
                              onTap: () => setState(() => _selected = AppRole.doctor),
                              selected: _selected == AppRole.doctor,
                            ),
                          ),
                          SizedBox(height: tall ? 16 : 12),
                          FadeInUp(
                            delayMs: 300,
                            child: BigButton(
                              label: _selected == null
                                  ? l.authChooseRoleFirst
                                  : (_busy
                                      ? l.authSigningIn
                                      : l.authContinueAs(_labelFor(l, _selected!))),
                              icon: _selected == null
                                  ? Icons.touch_app_outlined
                                  : Icons.lock_open_rounded,
                              // Inert until a role is chosen: authenticating
                              // without knowing who they are would leave the
                              // app with an account and nowhere to send it.
                              onPressed: _selected == null || _busy
                                  ? null
                                  : _authenticateAndContinue,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          FadeInUp(
                            delayMs: 320,
                            child: Text(
                              auth == null ? l.authUnavailableHere : l.authRequiredBody,
                              textAlign: TextAlign.center,
                              style: AppText.caption.copyWith(height: 1.45),
                            ),
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
/// Shown only when there *is* an account, so its whole job is to say whose it
/// is and to offer a way out of it. Signing in happens on the button below the
/// role cards; two sign-in affordances on one screen is one too many.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.signedInEmail,
    required this.busy,
    required this.onSignOut,
  });

  final String signedInEmail;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    return MmCard(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
      color: AppColors.primaryTint,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      child: Row(
        children: <Widget>[
          const SoftIcon(
            icon: Icons.verified_user_rounded,
            size: 38,
            color: AppColors.primary,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l.authSignedInAs(signedInEmail),
                  style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(l.profileAnswersFiledUnderAccount, style: AppText.caption, maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          TextButton(
            onPressed: busy ? null : onSignOut,
            child: Text(
              l.authSignOut,
              style: AppText.bodySmall
                  .copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w800),
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
    this.selected = false,
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

  /// Chosen but not yet confirmed — the button below is what commits it.
  final bool selected;

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
      color: selected ? tint : null,
      border: selected
          ? Border.all(color: accent, width: 2.2)
          : (badge == null ? null : Border.all(color: accent.withValues(alpha: 0.5), width: 1.6)),
      shadow: AppColors.softShadow(y: 6, blur: 18, opacity: selected ? 0.09 : 0.055),
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
                decoration: BoxDecoration(
                  color: selected ? accent : tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 19,
                  color: selected ? Colors.white : accent,
                ),
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
