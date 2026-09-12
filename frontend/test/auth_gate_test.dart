import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/app.dart';
import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/models/auth_user.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/services/auth_service.dart';
import 'package:smaran_saathi/features/auth/role_selection_screen.dart';
import 'package:smaran_saathi/features/auth/sign_in_screen.dart';
import 'package:smaran_saathi/features/intake/welcome_screens.dart';
import 'package:smaran_saathi/features/patient/profile/patient_profile_screen.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

/// A fake, in-memory `AuthService` — the same "swap the real thing for a
/// controllable fake" pattern already used for `ConnectivityService`
/// (`ManualConnectivityService`) and `SyncTransport` (`LoopbackTransport`).
/// Exercises `AuthGate`/`SignInScreen` without touching real Firebase.
class FakeAuthService implements AuthService {
  final StreamController<AuthUser?> _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  final Map<String, dynamic> me;

  /// Set to a message to make the next sign-in/sign-up attempt fail.
  String? nextError;

  /// The uid handed back on a successful attempt — varied so a test can sign
  /// in as two different people on the same device.
  String uid;

  FakeAuthService({this.me = const <String, dynamic>{}, this.uid = 'fake-uid'});

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthResult> signIn({required String email, required String password}) => _attempt(email);

  @override
  Future<AuthResult> signUp({required String email, required String password}) => _attempt(email);

  /// Set to make the next Google attempt behave like a dismissed picker.
  bool googleCancelled = false;

  @override
  Future<AuthResult> signInWithGoogle() async {
    if (googleCancelled) {
      googleCancelled = false;
      return const AuthResult.failure('Google sign-in was cancelled.');
    }
    return _attempt('google-user@example.com');
  }

  Future<AuthResult> _attempt(String email) async {
    if (nextError != null) {
      final String message = nextError!;
      nextError = null;
      return AuthResult.failure(message);
    }
    final AuthUser user = AuthUser(uid: uid, email: email);
    _current = user;
    _controller.add(user);
    return AuthResult.success(user);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => _current == null ? null : 'fake-token';

  @override
  Future<void> declareRole(String role) async {
    _current = _current?.copyWith(role: role);
  }

  @override
  Future<Map<String, dynamic>?> fetchMe() async => _current == null ? null : me;
}

void main() {
  testWidgets('unauthenticated: shows the sign-in screen, not role selection', (WidgetTester tester) async {
    final FakeAuthService auth = FakeAuthService();

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(authService: auth, child: const Text('Role selection reached')),
    ));

    expect(find.text('Care team sign-in'), findsOneWidget);
    expect(find.text('Role selection reached'), findsNothing);
  });

  testWidgets('a successful sign-in reveals the gated child', (WidgetTester tester) async {
    final FakeAuthService auth = FakeAuthService();

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(authService: auth, child: const Text('Role selection reached')),
    ));

    await tester.enterText(find.byType(TextFormField).first, 'caregiver@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'correcthorse');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Role selection reached'), findsOneWidget);
    expect(find.text('Care team sign-in'), findsNothing);
  });

  testWidgets('a failed sign-in shows the error and stays on the sign-in screen', (WidgetTester tester) async {
    final FakeAuthService auth = FakeAuthService()..nextError = 'Incorrect email or password.';

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(authService: auth, child: const Text('Role selection reached')),
    ));

    await tester.enterText(find.byType(TextFormField).first, 'caregiver@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpassword');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Role selection reached'), findsNothing);
  });

  testWidgets('empty fields are rejected client-side before any sign-in attempt', (WidgetTester tester) async {
    final FakeAuthService auth = FakeAuthService();

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(authService: auth, child: const Text('Role selection reached')),
    ));

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(find.text('Role selection reached'), findsNothing);
  });

  testWidgets('signing out returns to the sign-in screen', (WidgetTester tester) async {
    final FakeAuthService auth = FakeAuthService();
    await auth.signIn(email: 'caregiver@example.com', password: 'correcthorse');

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(authService: auth, child: const Text('Role selection reached')),
    ));
    expect(find.text('Role selection reached'), findsOneWidget);

    await auth.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Care team sign-in'), findsOneWidget);
  });

  // ── Sign-in as a step in the journey, not a gate in front of it ─────────

  testWidgets('the welcome screen routes into sign-in and on to role selection',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeAuthService auth = FakeAuthService();
    final AppState state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: AuthScope(
          authService: auth,
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The welcome screen comes first — nobody is asked for an email before
    // being told what the product is.
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'priya@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign in').last);
    // Signing in now loads the account's whole record — profile, questionnaire,
    // baseline, history — before it navigates, so let those reads settle.
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Signed in, the assessment is bound to the uid, and the journey continues.
    expect(state.accountId, 'fake-uid');
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('Welcome to SmaranSaathi'), findsOneWidget);
  });

  testWidgets('an already signed-in user skips the sign-in screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeAuthService auth = FakeAuthService();
    await auth.signIn(email: 'priya@example.com', password: 'x');
    final AppState state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: AuthScope(
          authService: auth,
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(SignInScreen), findsNothing);
    expect(state.accountId, 'fake-uid');
  });

  testWidgets('sign-in is reachable from the welcome screen the app really pushes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The whole app, not a hand-assembled subtree — this is the only way to
    // catch a scope that covers the first route but not the pushed ones.
    final FakeAuthService auth = FakeAuthService();
    final AppState state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(SmaranSaathiApp(state: state, authService: auth));
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Get started'), findsOneWidget,
        reason: 'the splash should hand over to the welcome screen');

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(SignInScreen), findsOneWidget,
        reason: 'the welcome screen must see the AuthScope through the push');
  });

  group('Google sign-in', () {
    testWidgets('signs in and binds the account, without touching the form',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FakeAuthService auth = FakeAuthService(uid: 'uid-google');
      final AppState state = AppState();
      addTearDown(state.dispose);
      AuthUser? signedIn;

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: AuthScope(
            authService: auth,
            child: MaterialApp(
              home: SignInScreen(
                authService: auth,
                onSignedIn: (AuthUser user) => signedIn = user,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The email fields are left empty on purpose: Google sign-in must not
      // be blocked by the form's validators.
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(signedIn?.uid, 'uid-google');
      expect(auth.currentUser?.email, 'google-user@example.com');
    });

    testWidgets('a dismissed account picker reports a cancellation, not a failure',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FakeAuthService auth = FakeAuthService()..googleCancelled = true;
      bool routed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(
            authService: auth,
            onSignedIn: (AuthUser _) => routed = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Stays put, says what happened, and does not route onward.
      expect(routed, isFalse);
      expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  testWidgets('sign-in can be skipped, and the journey still works',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeAuthService auth = FakeAuthService();
    final AppState state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: AuthScope(
          authService: auth,
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Continue without an account'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.tap(find.text('Continue without an account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // On to the journey, with the assessment left unbound rather than filed
    // under someone else's uid.
    expect(find.byType(SignInScreen), findsNothing);
    expect(state.accountId, isNull);
    expect(auth.currentUser, isNull);
  });

  group('there is always a way back to the role picker', () {
    // A plain `test`, not `testWidgets`: `signInAccount` awaits repository
    // reads, and inside testWidgets' fake async those futures only complete
    // while the tester pumps.
    test('signing out clears the role, so the picker is reachable', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      // The real order: sign in, then choose a role. (A fresh uid with no
      // stored profile resets the role on purpose, so setting it first would
      // be testing nothing.)
      await state.signInAccount('uid-1');
      state.setRole(AppRole.patient);
      expect(state.role, AppRole.patient);

      await state.signOutAccount();

      // The role went with the account. Without this, `sessionHome` sent the
      // next sign-in straight back into the patient app and the role picker
      // could never be reached again.
      expect(state.role, AppRole.none);
      expect(WelcomeScreen.sessionHome(state), isA<RoleSelectionScreen>());
    });

    testWidgets('"Switch role" reaches the picker even from a root patient app',
        (WidgetTester tester) async {
      // Generous, because this test is about navigation and the destination
      // screen's own layout at small sizes is not what is under test.
      tester.view.physicalSize = const Size(834, 1180) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);

      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);

      // The patient profile as the *root* route, which is what signing in
      // produces: `sessionHome` arrives through `Nav.rootTo`, so there is
      // nothing underneath to pop and the old `maybePop` did nothing at all.
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
          theme: AppTheme.warm(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The screen's own Switch needs a Material ancestor that a bare
          // `home:` does not provide.
          home: const Material(child: PatientProfileScreen()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final Finder switchRole = find.text('Switch role');
      await tester.scrollUntilVisible(switchRole, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(switchRole);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(state.role, AppRole.none);
    });
  });
}
