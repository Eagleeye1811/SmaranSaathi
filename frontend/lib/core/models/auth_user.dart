import 'package:flutter/foundation.dart';

/// Who is signed in, from the app's point of view — a thin projection over
/// whatever `AuthService` implementation is active, so nothing outside
/// `core/services/` needs to know it's really a `firebase_auth.User`.
@immutable
class AuthUser {
  const AuthUser({required this.uid, this.email, this.displayName, this.role});

  final String uid;
  final String? email;

  /// The name the person gave when they created the account, as stored on
  /// their Firebase profile. Null for accounts made before the sign-up form
  /// asked for one, and for a Google sign-in that carries no name — callers
  /// fall back to deriving something from the email.
  final String? displayName;

  /// The `role` custom claim on the user's Firebase ID token, if any has
  /// been set yet (`patient` | `caregiver` | `doctor`). `null` until the
  /// user has picked a role at least once — see
  /// `AuthService.declareRole` and `backend/app/api/v1/auth.py`'s
  /// `POST /auth/role`.
  final String? role;

  AuthUser copyWith({String? role, String? displayName}) => AuthUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
      );
}
