import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/clinical.dart';
import '../models/doctor.dart';

/// A caregiver's patient connecting to a real doctor account — durable,
/// backend-persisted, mirroring `PairingService`'s claim/request/decide
/// shape but for two real Firebase accounts instead of a device.
///
/// Auth here is a Firebase ID token (see `AuthService.idToken`), not the
/// device token `PairingService`/`HttpSyncTransport` use — both sides of
/// this handshake are real signed-in accounts, unlike a patient device,
/// which is why this follows `FirebaseAuthService.declareRole`'s pattern
/// (`Authorization: Bearer <idToken>` straight to the configured backend)
/// rather than `PairingService`'s dev-loopback discovery ladder.
class DoctorAlreadyConnectedException implements Exception {
  const DoctorAlreadyConnectedException();
}

class DoctorConnectionService {
  DoctorConnectionService({
    required String baseUrl,
    required Future<String?> Function({bool forceRefresh}) idToken,
    http.Client? client,
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _idToken = idToken,
        _client = client ?? http.Client();

  final String _baseUrl;
  final Future<String?> Function({bool forceRefresh}) _idToken;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final String? token = await _idToken();
    if (token == null) throw StateError('Not signed in.');
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Upserts the signed-in doctor's own listing — call once per sign-in
  /// (see `AppState.ensureDoctorListing`) so a doctor becomes durably
  /// discoverable the moment they first reach the app, not just cached on
  /// whichever device they happened to sign into.
  Future<DoctorProfile> upsertProfile({
    required String name,
    String specialization = '',
    String hospital = '',
    String phone = '',
    String registrationNumber = '',
    String avatarInitials = '',
  }) async {
    final http.Response r = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/doctors/profile'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'name': name,
            'specialization': specialization,
            'hospital': hospital,
            'phone': phone,
            'registrationNumber': registrationNumber,
            'avatarInitials': avatarInitials,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw StateError('Could not save doctor profile (${r.statusCode}).');
    }
    final DoctorProfile? profile =
        DoctorProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    if (profile == null) throw StateError('Malformed doctor profile response.');
    return profile;
  }

  /// Every real, registered doctor — no sample/fictional entries mixed in
  /// anymore; those are gone, replaced by real seeded accounts.
  Future<List<DoctorProfile>> directory() async {
    final http.Response r = await _client
        .get(Uri.parse('$_baseUrl/api/v1/doctors/directory'), headers: await _headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return const <DoctorProfile>[];
    final List<DoctorProfile> list = <DoctorProfile>[];
    for (final Object? item in jsonDecode(r.body) as List<dynamic>) {
      final DoctorProfile? profile = DoctorProfile.fromJson(item! as Map<String, dynamic>);
      if (profile != null) list.add(profile);
    }
    return list;
  }

  /// A caregiver asking a doctor to take on their patient.
  Future<ConnectionRequest> invite({
    required String doctorUid,
    required String patientId,
    String patientName = '',
    int patientAge = 0,
    String district = '',
  }) async {
    final http.Response r = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/doctors/connections/invite'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'doctorUid': doctorUid,
            'patientId': patientId,
            'patientName': patientName,
            'patientAge': patientAge,
            'district': district,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 409) throw const DoctorAlreadyConnectedException();
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw StateError('Could not send invitation (${r.statusCode}).');
    }
    return _requestFromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// What the doctor's own device polls for — invitations waiting on them.
  Future<List<ConnectionRequest>> pendingRequests() async {
    final http.Response r = await _client
        .get(Uri.parse('$_baseUrl/api/v1/doctors/connections/requests'), headers: await _headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return const <ConnectionRequest>[];
    return <ConnectionRequest>[
      for (final Object? item in jsonDecode(r.body) as List<dynamic>)
        _requestFromJson(item! as Map<String, dynamic>),
    ];
  }

  Future<ConnectionRequest> respond({required String requestId, required bool approve}) async {
    final http.Response r = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/doctors/connections/respond'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{'requestId': requestId, 'approve': approve}),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw StateError('Could not respond (${r.statusCode}).');
    return _requestFromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// The uid of the doctor currently connected to this patient, if any.
  Future<String?> forPatient(String patientId) async {
    final http.Response r = await _client
        .get(
          Uri.parse('$_baseUrl/api/v1/doctors/connections/for-patient?patientId=$patientId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final String body = r.body.trim();
    if (body.isEmpty || body == 'null') return null;
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['doctorUid'] as String?;
  }

  /// The doctor's caseload — real patients, real computed scores.
  Future<List<ClinicPatient>> caseload() async {
    final http.Response r = await _client
        .get(Uri.parse('$_baseUrl/api/v1/doctors/connections/caseload'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return const <ClinicPatient>[];
    return <ClinicPatient>[
      for (final Object? item in jsonDecode(r.body) as List<dynamic>)
        ClinicPatient.fromJson(item! as Map<String, dynamic>),
    ];
  }

  Future<void> disconnect(String patientId) async {
    await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/doctors/connections/disconnect'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{'patientId': patientId}),
        )
        .timeout(const Duration(seconds: 12));
  }

  ConnectionRequest _requestFromJson(Map<String, dynamic> j) {
    final int requestedAtMillis = j['requestedAtMillis'] as int? ?? 0;
    return ConnectionRequest(
      id: j['requestId'] as String? ?? '',
      patientName: j['patientName'] as String? ?? '',
      patientAge: j['patientAge'] as int? ?? 0,
      district: j['district'] as String? ?? '',
      // The backend only carries `caregiverUid`, not a display name — a
      // generic label beats guessing at one.
      requestedByLabel: 'A family caregiver',
      timeAgo: _timeAgo(requestedAtMillis),
      doctorId: j['doctorUid'] as String? ?? '',
    );
  }

  static String _timeAgo(int millis) {
    if (millis <= 0) return '';
    final Duration age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}
