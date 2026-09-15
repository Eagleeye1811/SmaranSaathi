import 'package:flutter/widgets.dart';

import '../models/auth_user.dart';

/// Result of a sign-in/sign-up attempt: either the resulting [AuthUser], or
/// a short, patient/caregiver-readable [error] message — never a raw
/// exception string.
class AuthResult {
  const AuthResult.success(this.user, {this.isNewAccount = false}) : error = null;
  const AuthResult.failure(String this.error)
      : user = null,
        isNewAccount = false;

  final AuthUser? user;
  final String? error;

  /// True when this call *created* the account rather than signing in to one
  /// that already existed. The caller routes on it: a brand-new caregiver has
  /// a profile to build, a returning one does not.
  final bool isNewAccount;

  bool get isSuccess => user != null;
}

/// Firebase-user authentication for the caregiver/doctor-facing dashboard
/// surface — separate from the patient's device-level sync auth
/// (`HttpSyncTransport`/`backend/app/core/device_auth.py`), which stays
/// exactly as it was and needs no login at all.
///
/// Two implementations: [FirebaseAuthService] (real, wraps `firebase_auth`)
/// and [NoAuthRequiredService] (the default — skips the gate entirely, so
/// every existing test, every `--dart-define=MM_START=...` demo boot, and
/// any build without Firebase configured keeps working exactly as before).
abstract class AuthService {
  /// Emits the current user on every sign-in/sign-out, and once immediately
  /// with whatever the current state already is.
  Stream<AuthUser?> get authStateChanges;

  AuthUser? get currentUser;

  Future<AuthResult> signIn({required String email, required String password});

  Future<AuthResult> signUp({required String email, required String password});

  /// One button for "I am new here" and "I have been here before".
  ///
  /// Asking somebody to know in advance whether they have an account is
  /// asking the wrong person: they are setting a phone up for a parent, they
  /// may have started this weeks ago, and getting it wrong meant an error
  /// message and a second attempt. So the account is created if it is not
  /// there and signed in to if it is, in one press.
  ///
  /// Create-then-fall-back rather than sign-in-then-fall-back, because
  /// `email-already-in-use` is unambiguous while a failed sign-in is not:
  /// with email-enumeration protection on, Firebase reports an unknown email
  /// and a wrong password identically, so "no such account, let me make one"
  /// could not be told apart from "you mistyped your password".
  Future<AuthResult> signInOrCreate({required String email, required String password});

  /// Google sign-in.
  ///
  /// Offered alongside email/password because the people who set this device
  /// up — a caregiver, a health worker at a clinic — usually already have a
  /// Google account on the phone and should not have to invent and remember
  /// another password.
  ///
  /// Returns a failure (never throws) when the account picker is dismissed,
  /// so a cancelled sign-in is an ordinary outcome rather than an error state.
  Future<AuthResult> signInWithGoogle();

  Future<void> signOut();

  /// A fresh Firebase ID token for the signed-in user, or `null` if nobody
  /// is signed in. `forceRefresh` picks up a role claim set moments ago by
  /// `declareRole` (Firebase caches ID tokens for up to an hour otherwise).
  Future<String?> idToken({bool forceRefresh = false});

  /// Self-declares which of the three roles this account is — called once,
  /// the first time a freshly-signed-up user picks a role on
  /// `RoleSelectionScreen`. Backed by `POST /api/v1/auth/role`, which sets
  /// the `role` custom claim server-side (a client can't set its own custom
  /// claims directly — only the Admin SDK can). Best-effort: failures are
  /// swallowed by callers so a network hiccup never blocks picking a role.
  Future<void> declareRole(String role);

  /// Round-trips through the real backend — `GET /api/v1/auth/me`, which
  /// only answers with a `200` if the bearer token this service attached
  /// actually verified server-side via Firebase Admin. A non-null result
  /// here is the proof that ID-token acquisition, transmission, and
  /// backend-side verification are all genuinely wired, not just that the
  /// client believes it's signed in. Returns `null` on any failure.
  Future<Map<String, dynamic>?> fetchMe();
}

/// The default. No gate, no login screen, no Firebase involved at all —
/// `authStateChanges` reports a single synthetic "already signed in" user
/// forever, so wrapping `SmaranSaathiApp` in an `AuthGate` with this service
/// (or, equivalently, passing no `authService` at all) is a no-op.
class NoAuthRequiredService implements AuthService {
  const NoAuthRequiredService();

  static const AuthUser _demoUser = AuthUser(uid: 'no-auth-required', role: 'caregiver');

  @override
  Stream<AuthUser?> get authStateChanges => Stream<AuthUser?>.value(_demoUser);

  @override
  AuthUser? get currentUser => _demoUser;

  @override
  Future<AuthResult> signIn({required String email, required String password}) async =>
      const AuthResult.success(_demoUser);

  @override
  Future<AuthResult> signInWithGoogle() async => const AuthResult.success(_demoUser);

  @override
  Future<AuthResult> signUp({required String email, required String password}) async =>
      const AuthResult.success(_demoUser);

  @override
  Future<AuthResult> signInOrCreate({required String email, required String password}) async =>
      const AuthResult.success(_demoUser);

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> declareRole(String role) async {}

  @override
  Future<Map<String, dynamic>?> fetchMe() async => null;
}

/// Makes the active [AuthService] reachable from anywhere below `AuthGate`
/// (role selection's "declare my role on first pick", a profile screen's
/// "log out" action) without threading it through every constructor —
/// same shape as `AppScope`/`LocaleScope`, just over a plain reference
/// rather than a `ChangeNotifier`, since auth state itself already streams
/// through `authStateChanges`.
class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.authService, required super.child});

  final AuthService authService;

  /// `null` when there's no `AuthGate` above this point in the tree (i.e.
  /// `SmaranSaathiApp` was built without an `authService` — see that
  /// widget's doc comment) — callers should treat that the same as
  /// "nothing to declare/log out of".
  static AuthService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.authService;

  @override
  bool updateShouldNotify(AuthScope oldWidget) => authService != oldWidget.authService;
}
