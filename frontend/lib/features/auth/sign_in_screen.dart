import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/auth_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand.dart';
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

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _submitting = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// One button. The account is created if it is not there and signed in to
  /// if it is — see `AuthService.signInOrCreate` for why that is a single
  /// action rather than two the person has to choose between.
  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() => widget.authService
        .signInOrCreate(email: _email.text, password: _password.text));
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
      _notice = result.isSuccess && result.isNewAccount ? 'Account created.' : null;
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Center(child: BrandLockup(size: 40)),
                      const SizedBox(height: 8),
                      Text(
                        'Care team sign-in',
                        textAlign: TextAlign.center,
                        style: AppText.h2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'New here or coming back — one button does both. '
                        'The patient never needs to sign in here.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySmall.tint(AppColors.inkMuted),
                      ),
                      const SizedBox(height: 24),
                      MmCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextFormField(
                              controller: _email,
                              enabled: !_submitting,
                              autofillHints: const <String>[AutofillHints.email],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              validator: (String? value) {
                                final String v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Enter an email address.';
                                if (!v.contains('@') || !v.contains('.')) return 'That doesn\'t look like an email.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              enabled: !_submitting,
                              obscureText: true,
                              autofillHints: const <String>[AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                              validator: (String? value) {
                                if ((value ?? '').length < 6) return 'At least 6 characters.';
                                return null;
                              },
                            ),
                            if (_error != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Text(
                                _error!,
                                style: AppText.bodySmall.tint(AppColors.danger),
                              ),
                            ],
                            if (_notice != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Text(
                                _notice!,
                                style: AppText.bodySmall.tint(AppColors.success),
                              ),
                            ],
                            const SizedBox(height: 18),
                            BigButton(
                              label: _submitting ? 'Please wait…' : 'Continue',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _submitting ? null : _submit,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We will create your account if you do not have '
                              'one yet.',
                              textAlign: TextAlign.center,
                              style: AppText.caption.tint(AppColors.inkMuted),
                            ),
                            const SizedBox(height: 16),
                            const _OrDivider(),
                            const SizedBox(height: 16),
                            _GoogleButton(
                              onPressed: _submitting ? null : _google,
                            ),
                          ],
                        ),
                      ),
                      if (widget.onSkip != null) ...<Widget>[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _submitting ? null : widget.onSkip,
                          child: Text(
                            'Continue without an account',
                            style: AppText.body.tint(AppColors.inkSoft),
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
          child: Text(AppLocalizations.of(context)!.orText, style: AppText.caption),
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

    // Four arcs, in Google's order, starting from the right-hand bar.
    void sweep(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(ring, startDeg * math.pi / 180, sweepDeg * math.pi / 180,
          false, arc..color = color);
    }

    sweep(-50, 65, _blue);
    sweep(15, 75, _green);
    sweep(90, 100, _yellow);
    sweep(190, 110, _red);

    // The horizontal bar of the G.
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.41, s * 0.5 - s * 0.05, stroke * 0.86),
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
