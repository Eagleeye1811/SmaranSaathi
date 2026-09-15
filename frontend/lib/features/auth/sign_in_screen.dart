import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/auth_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';

/// Account setup, reached from the welcome screen.
///
/// This is caregiver/doctor-facing — a patient never types on it. Signing in
/// happens *before* the intake so that everything the person then answers can
/// be filed under their uid rather than under whichever device they happened
/// to use.
///
/// Two ways in, both supported: [onSignedIn] for the explicit
/// welcome → sign in → intake flow, and `AuthGate`, which swaps this screen
/// out on its own when the auth stream reports a user.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.authService,
    this.onSignedIn,
    this.onSkip,
  });

  final AuthService authService;

  /// Called with the successful result — the user, and whether the account
  /// was created just now. Null when an `AuthGate` above is driving
  /// navigation instead.
  final Future<void> Function(AuthResult result)? onSignedIn;

  /// Continue without an account.
  ///
  /// The app is offline-first and every screen works with no sign-in at all —
  /// an account only decides *whose* record the answers are filed under. Given
  /// that, a sign-in screen with no way past it would be a dead end for anyone
  /// with no connection, no email, or a project whose sign-in methods are not
  /// enabled yet. Null hides the option.
  final VoidCallback? onSkip;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

/// Which of the two things the form is doing right now.
enum _AuthMode { signIn, signUp }

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// Returning is the common case once a device has been set up, so the form
  /// opens on it; a first-time doctor or caregiver switches once.
  _AuthMode _mode = _AuthMode.signIn;
  bool get _isSignUp => _mode == _AuthMode.signUp;

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Creating an account and signing in used to be one button, on the
  /// reasoning that somebody setting a phone up for a parent should not have
  /// to know which they need. That works until the form has to collect
  /// something only a *new* account has — a name — which cannot sensibly be
  /// asked of someone who is only signing back in. So the two are separate
  /// now, and `signInOrCreate` still covers the ambiguous case underneath:
  /// choosing "Create account" for an email that already exists falls back to
  /// signing in rather than failing.
  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(
      () => _isSignUp
          ? widget.authService.signInOrCreate(
              email: _email.text,
              password: _password.text,
              displayName: _name.text,
            )
          : widget.authService.signIn(
              email: _email.text,
              password: _password.text,
            ),
    );
  }

  void _setMode(_AuthMode mode) {
    if (_mode == mode || _submitting) return;
    setState(() {
      _mode = mode;
      // Errors belong to the attempt that produced them, not to the form.
      _error = null;
      _notice = null;
    });
  }

  Future<void> _google() => _run(widget.authService.signInWithGoogle);

  /// One path for every sign-in method: disable the form, run it, show any
  /// error in the same place, and hand a successful user to the caller.
  Future<void> _run(Future<AuthResult> Function() attempt) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final AuthResult result = await attempt();

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = result.isSuccess ? null : result.error;
      _notice = result.isSuccess && result.isNewAccount
          ? 'Account created.'
          : null;
    });

    if (result.isSuccess && result.user != null) {
      // Either the caller routes onward, or an AuthGate above is listening to
      // authStateChanges and swaps this screen out on its own.
      //
      // The callback is asynchronous — it binds the account, which reads the
      // record off disk and asks the server for anything this device has not
      // seen. Firing and forgetting it raced the navigation that follows:
      // the caregiver shell decided there was no questionnaire answered yet
      // and opened the onboarding, moments before the answers arrived.
      await widget.onSignedIn?.call(result);
    }
  }

  /// The field-label-above-input pattern used everywhere else text is
  /// collected in this app (see `IntakeField` in `intake_kit.dart`) — a
  /// floating Material `labelText` was the one place in the whole app that
  /// still looked like generic Flutter rather than SmaranSaathi's own style.
  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: Insets.xs),
    child: Text(text, style: AppText.label),
  );

  /// Same filled, rounded, hairline-bordered recipe as `IntakeField` —
  /// duplicated rather than reused because `IntakeField` wraps a plain
  /// `TextField` with no validator/obscureText/autofillHints support, and
  /// this form needs all three.
  InputDecoration _fieldDecoration({Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: Corners.r(Corners.md),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: 16,
      ),
      suffixIcon: suffixIcon,
      border: border(AppColors.hairline, 1),
      enabledBorder: border(AppColors.hairline, 1),
      focusedBorder: border(AppColors.primary, 2),
      errorBorder: border(AppColors.danger, 1),
      focusedErrorBorder: border(AppColors.danger, 2),
      errorStyle: AppText.caption.copyWith(color: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MotifBackground(
        opacity: 0.055,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.9),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // Always shown — the brand mark lives in this fixed header,
              // not as the first item of the scrolling form below, so it
              // can't be distorted by Android's stretch-overscroll during a
              // drag the way it was here before, and it now shares a row
              // with the back arrow instead of sitting left-aligned beneath
              // it. The back arrow itself stays conditional: this screen is
              // also used as `AuthGate`'s own root when a build requires
              // sign-in, where a back arrow that does nothing would be worse
              // than none at all — but the header row, and the centring, stay
              // either way.
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.sm, 6, Insets.gutter, 8),
                child: Row(
                  children: <Widget>[
                    if (Navigator.of(context).canPop())
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(width: 48),
                    const Expanded(
                      child: Center(
                        child: BrandLockup(size: 38, center: true),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.gutter,
                      vertical: Insets.lg,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: _formKey,
                        // Live, as-you-type feedback once a field has been
                        // touched once, rather than only on submit — the one
                        // piece of this form that stayed purely reactive
                        // while every other input surface in the app (the
                        // intake questionnaire, the games) tells you
                        // something the moment you act, not after.
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            FadeInUp(
                              child: Center(
                                child: Companion(
                                  state: CompanionState.gentle,
                                  size: 84,
                                ),
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            FadeInUp(
                              delayMs: 60,
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    _isSignUp
                                        ? 'Create your account'
                                        : 'Care team sign-in',
                                    textAlign: TextAlign.center,
                                    style: AppText.h1.sized(26),
                                  ),
                                  const SizedBox(height: Insets.xs),
                                  Text(
                                    _isSignUp
                                        ? 'For a caregiver or a doctor. Your name is '
                                              'what the other side sees.'
                                        : 'Welcome back. The patient never needs to '
                                              'sign in here.',
                                    textAlign: TextAlign.center,
                                    style: AppText.body.copyWith(
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Insets.lg),
                            FadeInUp(
                              delayMs: 120,
                              child: MmCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _ModeToggle(
                                      mode: _mode,
                                      enabled: !_submitting,
                                      onChanged: _setMode,
                                    ),
                                    const SizedBox(height: Insets.lg),
                                    // Only a new account has a name to give;
                                    // asking a returning person for one would
                                    // be asking them to retype something the
                                    // account already knows.
                                    if (_isSignUp) ...<Widget>[
                                      _fieldLabel('Your name'),
                                      TextFormField(
                                        controller: _name,
                                        enabled: !_submitting,
                                        autofillHints: const <String>[
                                          AutofillHints.name,
                                        ],
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        style: AppText.bodyLarge,
                                        decoration: _fieldDecoration(),
                                        validator: (String? value) {
                                          if (!_isSignUp) return null;
                                          if ((value ?? '').trim().isEmpty) {
                                            return 'Enter your name.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: Insets.md),
                                    ],
                                    _fieldLabel('Email'),
                                    TextFormField(
                                      controller: _email,
                                      enabled: !_submitting,
                                      autofillHints: const <String>[
                                        AutofillHints.email,
                                      ],
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      style: AppText.bodyLarge,
                                      decoration: _fieldDecoration(),
                                      validator: (String? value) {
                                        final String v = value?.trim() ?? '';
                                        if (v.isEmpty) {
                                          return 'Enter an email address.';
                                        }
                                        if (!v.contains('@') ||
                                            !v.contains('.')) {
                                          return 'That doesn\'t look like an email.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: Insets.md),
                                    _fieldLabel('Password'),
                                    TextFormField(
                                      controller: _password,
                                      enabled: !_submitting,
                                      obscureText: _obscurePassword,
                                      autofillHints: const <String>[
                                        AutofillHints.password,
                                      ],
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      style: AppText.bodyLarge,
                                      decoration: _fieldDecoration(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: AppColors.inkMuted,
                                          ),
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      validator: (String? value) {
                                        if ((value ?? '').length < 6) {
                                          return 'At least 6 characters.';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_error != null) ...<Widget>[
                                      const SizedBox(height: Insets.md),
                                      Text(
                                        _error!,
                                        style: AppText.bodySmall.tint(
                                          AppColors.danger,
                                        ),
                                      ),
                                    ],
                                    if (_notice != null) ...<Widget>[
                                      const SizedBox(height: Insets.md),
                                      Text(
                                        _notice!,
                                        style: AppText.bodySmall.tint(
                                          AppColors.success,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: Insets.lg),
                                    BigButton(
                                      label: _submitting
                                          ? 'Please wait…'
                                          : (_isSignUp
                                                ? 'Create account'
                                                : 'Sign in'),
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: _submitting ? null : _submit,
                                    ),
                                    const SizedBox(height: Insets.sm),
                                    Text(
                                      _isSignUp
                                          ? 'Already have an account? Choose Sign in above.'
                                          : 'New here? Choose Create account above.',
                                      textAlign: TextAlign.center,
                                      style: AppText.caption.tint(
                                        AppColors.inkMuted,
                                      ),
                                    ),
                                    const SizedBox(height: Insets.md),
                                    const _OrDivider(),
                                    const SizedBox(height: Insets.md),
                                    _GoogleButton(
                                      onPressed: _submitting ? null : _google,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.onSkip != null) ...<Widget>[
                              const SizedBox(height: Insets.sm),
                              FadeInUp(
                                delayMs: 160,
                                child: TextButton(
                                  onPressed: _submitting ? null : widget.onSkip,
                                  child: Text(
                                    'Continue without an account',
                                    style: AppText.body.tint(AppColors.inkSoft),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

/// Sign in / Create account, as a two-segment switch.
///
/// A segmented control rather than a "don't have an account?" link at the
/// bottom: both states have to be visible at a glance here, because the form
/// above changes shape between them (the name field appears), and a person
/// who cannot see why it changed will think something went wrong.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _AuthMode mode;
  final bool enabled;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryTint.withValues(alpha: 0.45),
        borderRadius: Corners.r(Corners.md),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Segment(
              label: 'Sign in',
              selected: mode == _AuthMode.signIn,
              enabled: enabled,
              onTap: () => onChanged(_AuthMode.signIn),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Create account',
              selected: mode == _AuthMode.signUp,
              enabled: enabled,
              onTap: () => onChanged(_AuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: Corners.r(Corners.sm),
        elevation: selected ? 1 : 0,
        shadowColor: AppColors.ink.withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: Corners.r(Corners.sm),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "or" rule between the email form and the Google button.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: AppColors.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AppLocalizations.of(context).orText,
            style: AppText.caption,
          ),
        ),
        const Expanded(child: Divider(color: AppColors.hairline)),
      ],
    );
  }
}

/// Google's button, drawn rather than shipped as an asset.
///
/// The project holds no binary image assets — every mark in the app is vector
/// drawn — and Google's brand guidelines are explicit about the "G" being
/// reproduced in its four colours on a white surface, which a painter can do
/// exactly.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: onPressed,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Corners.pill),
            border: Border.all(color: AppColors.hairline, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(painter: _GoogleMarkPainter()),
              ),
              const SizedBox(width: 12),
              // Flexible so a longer translation shortens rather than
              // overflowing the button.
              Flexible(
                child: Text(
                  'Continue with Google',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.wght(700).tint(const Color(0xFF3C4043)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Rect ring = Rect.fromLTWH(0, 0, s, s).deflate(s * 0.09);
    final double stroke = s * 0.22;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs, clockwise from the gap at the right (0°, 3 o'clock) where
    // the bar sits — that gap previously opened at roughly 1 o'clock while
    // the bar was drawn at 3 o'clock, so the ring never actually had a
    // break where the bar met it and the mark read as a closed ring with a
    // stray rectangle rather than a "G".
    void sweep(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        ring,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        arc..color = color,
      );
    }

    sweep(15, 95, _blue);
    sweep(110, 90, _green);
    sweep(200, 70, _yellow);
    sweep(270, 75, _red);
    // Gap: 345° round to 15°, centered on the bar below.

    // The horizontal bar of the G, filling that gap.
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.41, s * 0.5 - s * 0.05, stroke * 0.95),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}

/// Wraps `child` (normally the existing role-selection flow, unchanged) with
/// a real Firebase sign-in gate. Not used unless `SmaranSaathiApp` is given a
/// real `authService` explicitly — see that widget's doc comment.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService, required this.child});

  final AuthService authService;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (BuildContext context, AsyncSnapshot<AuthUser?> snapshot) {
        if (snapshot.data == null) {
          return SignInScreen(authService: authService);
        }
        return AuthScope(authService: authService, child: child);
      },
    );
  }
}
