import 'package:flutter/foundation.dart';

/// Who is signed in, from the app's point of view — a thin projection over
/// whatever `AuthService` implementation is active, so nothing outside
/// `core/services/` needs to know it's really a `firebase_auth.User`.
@immutable
class AuthUser {
  const AuthUser({required this.uid, this.email, this.role});

  final String uid;
  final String? email;

  /// The `role` custom claim on the user's Firebase ID token, if any has
  /// been set yet (`patient` | `caregiver` | `doctor`). `null` until the
  /// user has picked a role at least once — see
  /// `AuthService.declareRole` and `backend/app/api/v1/auth.py`'s
  /// `POST /auth/role`.
  final String? role;

  AuthUser copyWith({String? role}) => AuthUser(uid: uid, email: email, role: role ?? this.role);
}
