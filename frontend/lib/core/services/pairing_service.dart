import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Linking a patient's own phone to the profile their caregiver built.
///
/// The patient never holds a credential. Their caregiver claims a short
/// username for them; a device that knows that username can *ask* to become
/// that patient, and only the caregiver's device can say yes. Asking someone
/// with memory loss to remember a password is asking them to do the one thing
/// the app exists because they cannot.
///
/// Auth is the same device token the sync transport mints — the patient's
/// phone has no account yet, so there is no user token to present. What
/// protects the account is that the backend only lets the caregiver who
/// claimed the username decide.
@immutable
class PairingClaim {
  const PairingClaim({
    required this.username,
    required this.patientId,
    required this.caregiverUid,
    this.patientName = '',
    this.alreadyClaimed = false,
  });

  final String username;
  final String patientId;
  final String caregiverUid;
  final String patientName;
  final bool alreadyClaimed;

  static PairingClaim fromJson(Map<String, dynamic> j) => PairingClaim(
        username: j['username'] as String? ?? '',
        patientId: j['patientId'] as String? ?? '',
        caregiverUid: j['caregiverUid'] as String? ?? '',
        patientName: j['patientName'] as String? ?? '',
        alreadyClaimed: j['alreadyClaimed'] as bool? ?? false,
      );
}

enum PairingStatus { pending, approved, declined, expired, unknown }

@immutable
class PairingRequest {
  const PairingRequest({
    required this.requestId,
    required this.username,
    required this.patientId,
    required this.deviceId,
    required this.status,
    this.deviceLabel = '',
  });

  final String requestId;
  final String username;
  final String patientId;
  final String deviceId;
  final PairingStatus status;
  final String deviceLabel;

  static PairingRequest fromJson(Map<String, dynamic> j) => PairingRequest(
        requestId: j['requestId'] as String? ?? '',
        username: j['username'] as String? ?? '',
        patientId: j['patientId'] as String? ?? '',
        deviceId: j['deviceId'] as String? ?? '',
        deviceLabel: j['deviceLabel'] as String? ?? '',
        status: switch (j['status'] as String?) {
          'pending' => PairingStatus.pending,
          'approved' => PairingStatus.approved,
          'declined' => PairingStatus.declined,
          'expired' => PairingStatus.expired,
          _ => PairingStatus.unknown,
        },
      );
}

/// Raised when a username is already spoken for by a different caregiver.
class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

/// Raised when nobody has claimed the username the patient typed.
class UnknownUsernameException implements Exception {
  const UnknownUsernameException();
}

/// Raised when a backend answered but has no pairing endpoints.
///
/// Distinct from "cannot reach the server" on purpose: a deployment that
/// predates this feature is reachable, healthy, and still cannot pair — and
/// telling someone to check their connection when the connection is fine
/// sends them looking in the wrong place.
class PairingUnsupportedException implements Exception {
  const PairingUnsupportedException();
}

/// Raised when every candidate in `_session`'s ladder failed or timed out.
///
/// Distinct from a generic `StateError` so the UI can show copy that
/// actually matches the likely cause: on a real device this almost always
/// means the one real backend is asleep and taking longer than the wait
/// allowed, not that the device has no connection at all — telling someone
/// "you're offline" when they demonstrably are not is what turned a single
/// slow cold start into "I had to enter it two or three times."
class PairingUnreachableException implements Exception {
  const PairingUnreachableException();
}

class PairingService {
  PairingService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _deviceToken;
  String? _resolvedRoot;

  static String _trim(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// The explicitly configured backend first, then the same dev-loopback
  /// fallbacks [HttpSyncTransport] walks — reversed from that transport's own
  /// order on purpose. A loopback address only ever resolves to something
  /// real on a developer's own machine (an emulator, or `adb reverse`); on
  /// every other device it either refuses instantly or — worse, on some
  /// mobile/VPN networks — is silently dropped rather than refused, which
  /// used to burn a full timeout on three addresses that were never going to
  /// answer before this method ever tried the one backend actually
  /// configured to serve real traffic. That configured backend is also the
  /// only one worth waiting out a slow cold start for, which is why it alone
  /// gets the long timeout below.
  ///
  /// Pairing adds a second requirement the sync transport does not have. The
  /// deployed backend is reachable and healthy but predates these endpoints,
  /// so "answered on /auth/device" is not enough — a candidate only counts if
  /// it actually serves /pairing. Without that check the app talks happily to
  /// a server that 404s every pairing call, and reports it as being offline.
  List<({String url, Duration timeout})> get _candidates {
    final List<({String url, Duration timeout})> list = <({String url, Duration timeout})>[];
    final Set<String> seen = <String>{};
    void add(String u, Duration timeout) {
      final String t = _trim(u);
      if (t.isEmpty || !seen.add(t)) return;
      list.add((url: t, timeout: timeout));
    }

    // A backend cold-starting from idle can take well past 5 seconds to wake
    // on its first request in a while — 20 seconds is generous enough to
    // ride that out without leaving a broken connection hanging forever.
    const Duration primaryTimeout = Duration(seconds: 20);
    // These three are opportunistic dev conveniences, never a real device's
    // actual path — a short timeout keeps a network that silently drops
    // rather than refuses from stalling the whole attempt.
    const Duration devTimeout = Duration(seconds: 4);

    if (_resolvedRoot != null) add(_resolvedRoot!, primaryTimeout);
    add(baseUrl, primaryTimeout);
    add('http://127.0.0.1:8000', devTimeout);
    add('http://localhost:8000', devTimeout);
    add('http://10.0.2.2:8000', devTimeout);
    return list;
  }

  /// Finds a backend that can actually pair, and remembers it.
  Future<({String root, String token})> _session() async {
    final String? root = _resolvedRoot;
    final String? token = _deviceToken;
    if (root != null && token != null) return (root: root, token: token);

    bool sawBackendWithoutPairing = false;

    for (final (:String url, :Duration timeout) in _candidates) {
      try {
        final http.Response minted = await _client
            .post(
              Uri.parse('$url/api/v1/auth/device'),
              headers: const <String, String>{'Content-Type': 'application/json'},
              body: jsonEncode(const <String, dynamic>{}),
            )
            .timeout(timeout);
        if (minted.statusCode != 200) continue;

        final String fresh =
            (jsonDecode(minted.body) as Map<String, dynamic>)['token'] as String;

        // Does this one serve pairing at all? A harmless read is enough.
        final http.Response probe = await _client
            .get(
              Uri.parse('$url/api/v1/pairing/requests?caregiverUid=__probe__'),
              headers: <String, String>{'Authorization': 'Bearer $fresh'},
            )
            .timeout(timeout);
        if (probe.statusCode == 404) {
          sawBackendWithoutPairing = true;
          continue;
        }

        _resolvedRoot = url;
        _deviceToken = fresh;
        return (root: url, token: fresh);
      } catch (_) {
        // Try the next candidate.
      }
    }

    if (sawBackendWithoutPairing) throw const PairingUnsupportedException();
    throw const PairingUnreachableException();
  }

  Future<Map<String, String>> _headers() async => <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${(await _session()).token}',
      };

  Future<String> get _root async => (await _session()).root;

  /// The caregiver names their patient's account.
  Future<PairingClaim> claim({
    required String username,
    required String patientId,
    required String caregiverUid,
    String patientName = '',
  }) async {
    final http.Response r = await _client
        .post(
          Uri.parse('${await _root}/api/v1/pairing/claim'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'username': username,
            'patientId': patientId,
            'caregiverUid': caregiverUid,
            'patientName': patientName,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 409) throw const UsernameTakenException();
    if (r.statusCode != 200) throw StateError('Could not claim (${r.statusCode}).');
    return PairingClaim.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// The patient's phone asks to be let in.
  Future<PairingRequest> requestAccess({
    required String username,
    required String deviceId,
    String deviceLabel = '',
  }) async {
    final http.Response r = await _client
        .post(
          Uri.parse('${await _root}/api/v1/pairing/request'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'username': username,
            'deviceId': deviceId,
            'deviceLabel': deviceLabel,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 404) throw const UnknownUsernameException();
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw StateError('Could not ask for access (${r.statusCode}).');
    }
    return PairingRequest.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// What this caregiver has already claimed, if anything.
  ///
  /// The backend claim is the durable record; the device's own
  /// `patientUsername` cache is not — a sign-out clears it (see
  /// `AppState.signOutAccount`), so a returning caregiver has to ask here
  /// rather than assume nothing was ever set up.
  Future<List<PairingClaim>> claimsFor(String caregiverUid) async {
    final http.Response r = await _client
        .get(
          Uri.parse('${await _root}/api/v1/pairing/claims?caregiverUid=$caregiverUid'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return const <PairingClaim>[];
    return <PairingClaim>[
      for (final Object? item in jsonDecode(r.body) as List<dynamic>)
        PairingClaim.fromJson(item! as Map<String, dynamic>),
    ];
  }

  /// What the caregiver's device polls for.
  Future<List<PairingRequest>> pendingFor(String caregiverUid) async {
    final http.Response r = await _client
        .get(
          Uri.parse('${await _root}/api/v1/pairing/requests?caregiverUid=$caregiverUid'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return const <PairingRequest>[];
    return <PairingRequest>[
      for (final Object? item in jsonDecode(r.body) as List<dynamic>)
        PairingRequest.fromJson(item! as Map<String, dynamic>),
    ];
  }

  /// What the patient's device polls for.
  Future<PairingRequest?> statusOf(String requestId) async {
    final http.Response r = await _client
        .get(
          Uri.parse('${await _root}/api/v1/pairing/status?requestId=$requestId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    return PairingRequest.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<PairingRequest?> respond({
    required String requestId,
    required String caregiverUid,
    required bool approve,
  }) async {
    final http.Response r = await _client
        .post(
          Uri.parse('${await _root}/api/v1/pairing/respond'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'requestId': requestId,
            'caregiverUid': caregiverUid,
            'approve': approve,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    return PairingRequest.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
