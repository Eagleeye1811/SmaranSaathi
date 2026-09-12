import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import 'auth_service.dart';

/// The real implementation — real Firebase sign-in/sign-up, a real ID token,
/// and a real round trip to the backend to self-declare a role (see
/// `AuthService.declareRole`'s doc comment for why that needs a server call).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    required String backendBaseUrl,
    http.Client? client,
    GoogleSignIn? googleSignIn,
  })  : _backendBaseUrl =
            backendBaseUrl.endsWith('/') ? backendBaseUrl.substring(0, backendBaseUrl.length - 1) : backendBaseUrl,
        _client = client ?? http.Client(),
        _auth = fb.FirebaseAuth.instance,
        _google = googleSignIn ??
            GoogleSignIn(
              scopes: const <String>['email'],
              // Only needed where the platform cannot read the client id from
              // a bundled config file (`google-services.json` /
              // `GoogleService-Info.plist`). Supplied by
              // `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` so no client id is
              // committed, matching how the Gemini key and the sync URL are
              // handled. Empty means "read it from the platform config".
              serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
            );

  static const String _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  final String _backendBaseUrl;
  final http.Client _client;
  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().asyncMap(_toAuthUser);

  @override
  AuthUser? get currentUser {
    final fb.User? user = _auth.currentUser;
    return user == null ? null : AuthUser(uid: user.uid, email: user.email);
  }

  Future<AuthUser?> _toAuthUser(fb.User? user) async {
    if (user == null) return null;
    // Cached-token claims are enough here — a screen that needs the very
    // latest role right after `declareRole` should await that call's own
    // `idToken(forceRefresh: true)`, not rely on this stream re-firing.
    String? role;
    try {
      final fb.IdTokenResult result = await user.getIdTokenResult();
      final Object? claim = result.claims?['role'];
      if (claim is String) role = claim;
    } catch (error) {
      debugPrint('FirebaseAuthService: reading role claim failed ($error)');
    }
    return AuthUser(uid: user.uid, email: user.email, role: role);
  }

  @override
  Future<AuthResult> signIn({required String email, required String password}) =>
      _attempt(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<AuthResult> signUp({required String email, required String password}) =>
      _attempt(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password),
          isNewAccount: true);

  @override
  Future<AuthResult> signInOrCreate({
    required String email,
    required String password,
  }) async {
    final AuthResult created = await signUp(email: email, password: password);
    if (created.isSuccess) return created;

    // The only outcome that means "you already have one of these". Every
    // other failure — a malformed email, too short a password, no network —
    // is a real problem the person has to see, not a reason to try again as
    // a sign-in and report a confusing second error.
    if (created.error != _emailInUseMessage) return created;

    return signIn(email: email, password: password);
  }

  /// Google sign-in, exchanged for a Firebase credential.
  ///
  /// Three steps, and each one can end the flow benignly: the person can
  /// dismiss the account picker, the tokens can come back empty, or Firebase
  /// can reject the credential. Only the last is an error worth showing — a
  /// dismissed picker is reported as a plain cancellation so the screen does
  /// not accuse anyone of failing.
  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      // A stale cached session survives an uninstall on Android and makes the
      // picker skip straight to the wrong account, so start clean.
      await _google.signOut();

      final GoogleSignInAccount? account = await _google.signIn();
      if (account == null) {
        return const AuthResult.failure('Google sign-in was cancelled.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.idToken == null && auth.accessToken == null) {
        return const AuthResult.failure(
            'Google did not return a usable token. Please try again.');
      }

      final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      return _attempt(() => _auth.signInWithCredential(credential));
    } on fb.FirebaseAuthException catch (error) {
      return AuthResult.failure(_readableMessage(error));
    } catch (error) {
      debugPrint('FirebaseAuthService: Google sign-in failed ($error)');
      return const AuthResult.failure(
          'Google sign-in is not available on this device yet. '
          'You can sign in with an email address instead.');
    }
  }

  Future<AuthResult> _attempt(
    Future<fb.UserCredential> Function() action, {
    bool isNewAccount = false,
  }) async {
    try {
      final fb.UserCredential credential = await action();
      final fb.User? user = credential.user;
      if (user == null) return const AuthResult.failure('Sign-in did not return a user.');
      return AuthResult.success(
        AuthUser(uid: user.uid, email: user.email),
        // Firebase says so itself for a federated sign-in; for email/password
        // the caller knows which method it used.
        isNewAccount: isNewAccount || (credential.additionalUserInfo?.isNewUser ?? false),
      );
    } on fb.FirebaseAuthException catch (error) {
      return AuthResult.failure(_readableMessage(error));
    } catch (error) {
      return const AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Matched by [signInOrCreate], so it is a constant rather than a literal
  /// repeated in two places that could drift apart.
  static const String _emailInUseMessage =
      'An account already exists with that email — signing you in instead.';

  String _readableMessage(fb.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return _emailInUseMessage;
      case 'weak-password':
        return 'Please choose a longer password (at least 6 characters).';
      case 'network-request-failed':
        return 'No connection right now — please check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. '
            'Sign in with the email and password you used before.';
      case 'operation-not-allowed':
        return 'That sign-in method is not enabled for this project yet.';
      default:
        return error.message ?? 'Sign-in failed. Please try again.';
    }
  }

  @override
  Future<void> signOut() async {
    // Both, or the next Google sign-in silently reuses the same account.
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) => _auth.currentUser?.getIdToken(forceRefresh) ??
      Future<String?>.value();

  @override
  Future<void> declareRole(String role) async {
    final String? token = await idToken();
    if (token == null) return;
    try {
      final http.Response response = await _client.post(
        Uri.parse('$_backendBaseUrl/api/v1/auth/role'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, String>{'role': role}),
      );
      if (response.statusCode >= 400) {
        debugPrint('FirebaseAuthService: declareRole failed (${response.statusCode}) ${response.body}');
        return;
      }
      // The token just changed server-side (a new custom claim) — refresh
      // the cached one so the next protected call carries the new role.
      await idToken(forceRefresh: true);
    } catch (error) {
      debugPrint('FirebaseAuthService: declareRole request failed ($error)');
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchMe() async {
    final String? token = await idToken();
    if (token == null) return null;
    try {
      final http.Response response = await _client.get(
        Uri.parse('$_backendBaseUrl/api/v1/auth/me'),
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      debugPrint('FirebaseAuthService: fetchMe failed ($error)');
      return null;
    }
  }
}
