import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/auth_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';

/// Sits in front of `RoleSelectionScreen`, shown only when nobody is signed
/// in. This is caregiver/doctor-facing setup — a patient never sees or types
/// on this screen; once whoever manages the device has signed in, the
/// existing role picker (including "Patient") is reached exactly as before.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isSignUp = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final AuthResult result = _isSignUp
        ? await widget.authService.signUp(email: _email.text, password: _password.text)
        : await widget.authService.signIn(email: _email.text, password: _password.text);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = result.isSuccess ? null : result.error;
    });
    // On success there's nothing left to do here — AuthGate listens to
    // authStateChanges and swaps this screen out on its own.
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
                        'For the caregiver or doctor managing this device. '
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
                              autofillHints: <String>[
                                _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
                              ],
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
                            const SizedBox(height: 18),
                            BigButton(
                              label: _submitting
                                  ? 'Please wait…'
                                  : (_isSignUp ? 'Create account' : 'Sign in'),
                              onPressed: _submitting ? null : _submit,
                            ),
                            const SizedBox(height: 10),
                            SoftButton(
                              label: _isSignUp
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create an account',
                              onPressed: _submitting
                                  ? null
                                  : () => setState(() {
                                        _isSignUp = !_isSignUp;
                                        _error = null;
                                      }),
                            ),
                          ],
                        ),
                      ),
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

/// Wraps `child` (normally the existing role-selection flow, unchanged) with
/// a real Firebase sign-in gate. Not used unless `MemoryMitraApp` is given a
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
