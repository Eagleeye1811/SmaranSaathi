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
import '../auth/auth_role_screen.dart';
import 'intake_kit.dart';
import '../caregiver/caregiver_entry.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_shell.dart';
import '../../l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

class AvatarVideoPlayer extends StatefulWidget {
  const AvatarVideoPlayer({super.key});

  @override
  State<AvatarVideoPlayer> createState() => _AvatarVideoPlayerState();
}

class _AvatarVideoPlayerState extends State<AvatarVideoPlayer> {
  late VideoPlayerController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/avatar_hi.mp4');
    try {
      await _controller.initialize();
      // On Web, volume 0.0 MUST be applied after initialize() so the HTML5
      // <video> element gets the 'muted' property required for Chrome autoplay.
      await _controller.setVolume(0.0);
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
        debugPrint('Video initialization error: $error');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text('Video Error:\n$_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
      );
    }
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          width: 350,
          height: 350,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF2EEE6),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            clipBehavior: Clip.antiAlias,
            child: Transform.scale(
              scale: 0.80,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
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
      await state.signInAccount(existing.uid, roleHint: existing.role, displayName: existing.displayName, email: existing.email);
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

  /// Each pillar carries its own hue.
  ///
  /// Three identically-tinted cards read as one repeated shape; three tints
  /// read as three distinct promises, which is what they are — and it costs
  /// nothing, because the palette already has these.
  static List<({IconData icon, Color tint, String title, String detail})> _pillars(
          AppLocalizations l) =>
      <({IconData icon, Color tint, String title, String detail})>[
    (
      icon: Icons.fact_check_outlined,
      tint: AppColors.primary,
      title: l.intakePillarUnderstandTitle,
      detail: l.intakePillarUnderstandDetail,
    ),
    (
      icon: Icons.timeline_rounded,
      tint: AppColors.secondary,
      title: l.intakePillarTrackTitle,
      detail: l.intakePillarTrackDetail,
    ),
    (
      icon: Icons.medical_information_outlined,
      tint: AppColors.terracotta,
      title: l.intakePillarSupportTitle,
      detail: l.intakePillarSupportDetail,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<({IconData icon, Color tint, String title, String detail})> pillars =
        _pillars(l);

    // Big on a phone, capped so it does not balloon on a tablet.
    final Size screen = MediaQuery.sizeOf(context);
    final double heroSize = (screen.width * 0.66).clamp(180.0, 300.0);


    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.05,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.85),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
                  children: <Widget>[
                    const FadeInUp(
                        child: Center(child: BrandLockup(size: 30, center: true))),
                    const SizedBox(height: Insets.sm),

                    // ── The hero ──────────────────────────────────────────
                    // The app's own companion rather than the generic bot in
                    // `avatar.json`: this is the character the patient meets on
                    // every screen after this one, and it is drawn in the
                    // brand's own green instead of a stock teal.
                    FadeInUp(
                      delayMs: 60,
                      child: Center(
                        child: SizedBox(
                          height: heroSize,
                          child: Companion(
                            state: CompanionState.gentle,
                            size: heroSize,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    FadeInUp(
                      delayMs: 130,
                      child: Text(
                        l.intakeWelcomeHeadline,
                        textAlign: TextAlign.center,
                        style: AppText.display,
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    // Three words, not three paragraphs. The detail lines said
                    // the same thing the intake is about to ask anyway, and
                    // they were what pushed the disclaimer off the screen.
                    FadeInUp(
                      delayMs: 190,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          for (final ({IconData icon, Color tint, String title, String detail}) p
                              in pillars)
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SoftIcon(icon: p.icon, color: p.tint, size: 46),
                                  const SizedBox(height: Insets.xs),
                                  Text(
                                    p.title,
                                    textAlign: TextAlign.center,
                                    style: AppText.label.copyWith(color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    // Kept: this is a medical-safety notice, not decoration.
                    const FadeInUp(
                      delayMs: 240,
                      child: NotADiagnosisNote(compact: true),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, Insets.xs, Insets.gutter, Insets.md),
                child: FadeInUp(
                  delayMs: 290,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
