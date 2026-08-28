import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import 'auth_service.dart';

/// The real implementation — real Firebase sign-in/sign-up, a real ID token,
/// and a real round trip to the backend to self-declare a role (see
/// `AuthService.declareRole`'s doc comment for why that needs a server call).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({required String backendBaseUrl, http.Client? client})
      : _backendBaseUrl =
            backendBaseUrl.endsWith('/') ? backendBaseUrl.substring(0, backendBaseUrl.length - 1) : backendBaseUrl,
        _client = client ?? http.Client(),
        _auth = fb.FirebaseAuth.instance;

  final String _backendBaseUrl;
  final http.Client _client;
  final fb.FirebaseAuth _auth;

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
      _attempt(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));

  Future<AuthResult> _attempt(Future<fb.UserCredential> Function() action) async {
    try {
      final fb.UserCredential credential = await action();
      final fb.User? user = credential.user;
      if (user == null) return const AuthResult.failure('Sign-in did not return a user.');
      return AuthResult.success(AuthUser(uid: user.uid, email: user.email));
    } on fb.FirebaseAuthException catch (error) {
      return AuthResult.failure(_readableMessage(error));
    } catch (error) {
      return const AuthResult.failure('Something went wrong. Please try again.');
    }
  }

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
        return 'An account already exists with that email — try signing in instead.';
      case 'weak-password':
        return 'Please choose a longer password (at least 6 characters).';
      case 'network-request-failed':
        return 'No connection right now — please check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Sign-in failed. Please try again.';
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
