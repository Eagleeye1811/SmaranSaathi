import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/core/models/auth_user.dart';
import 'package:memory_mitra/core/services/auth_service.dart';
import 'package:memory_mitra/features/auth/sign_in_screen.dart';

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

  FakeAuthService({this.me = const <String, dynamic>{}});

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthResult> signIn({required String email, required String password}) => _attempt(email);

  @override
  Future<AuthResult> signUp({required String email, required String password}) => _attempt(email);

  Future<AuthResult> _attempt(String email) async {
    if (nextError != null) {
      final String message = nextError!;
      nextError = null;
      return AuthResult.failure(message);
    }
    final AuthUser user = AuthUser(uid: 'fake-uid', email: email);
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
}
