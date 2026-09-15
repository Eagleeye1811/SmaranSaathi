import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/core/models/assessment.dart';
import 'package:smaran_saathi/core/models/doctor.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/services/doctor_connection_service.dart';

/// The doctor handshake, as state rather than as screens.
///
/// Real and backend-persisted now (see `backend/tests/test_doctor_connections.py`
/// for the authority checks — who may accept whose invitation — enforced
/// server-side against a real Firebase token, and `doctor_connection_service_test.dart`
/// for the HTTP layer). What is left to verify here is `AppState`'s own
/// orchestration on top of that: caching, optimistic updates, and reload-
/// after-mutation — so this uses a small in-memory fake of
/// [DoctorConnectionService] rather than a mock HTTP client, isolating that
/// orchestration from the wire format.
class _FakeDoctorConnectionService extends DoctorConnectionService {
  _FakeDoctorConnectionService()
      : super(baseUrl: 'https://fake', idToken: ({bool forceRefresh = false}) async => 'token');

  /// Whichever account is "asking" right now — the fake's stand-in for
  /// "whichever Firebase account the real idToken callback belongs to",
  /// since the real backend derives identity from the token, never from a
  /// client-supplied field (see `doctor_connections.py`).
  String currentUid = 'uid-unset';

  final Map<String, DoctorProfile> _profiles = <String, DoctorProfile>{};
  final Map<String, ConnectionRequest> _requests = <String, ConnectionRequest>{};
  final Map<String, String> _links = <String, String>{}; // patientId -> doctorUid
  int _nextRequestId = 1;

  @override
  Future<DoctorProfile> upsertProfile({
    required String name,
    String specialization = '',
    String hospital = '',
    String phone = '',
    String registrationNumber = '',
    String avatarInitials = '',
  }) async {
    final DoctorProfile profile = DoctorProfile(
      id: currentUid,
      name: name,
      specialization: specialization,
      hospital: hospital,
      email: '',
      phone: phone,
      registrationNumber: registrationNumber,
      avatarInitials: avatarInitials,
    );
    _profiles[currentUid] = profile;
    return profile;
  }

  @override
  Future<List<DoctorProfile>> directory() async => _profiles.values.toList();

  @override
  Future<ConnectionRequest> invite({
    required String doctorUid,
    required String patientId,
    String patientName = '',
    int patientAge = 0,
    String district = '',
  }) async {
    if (_links[patientId] == doctorUid) throw const DoctorAlreadyConnectedException();
    final String id = 'req_${_nextRequestId++}';
    final ConnectionRequest request = ConnectionRequest(
      id: id,
      patientName: patientName,
      patientAge: patientAge,
      district: district,
      requestedByLabel: 'A family caregiver',
      timeAgo: 'just now',
      doctorId: doctorUid,
    );
    _requests[id] = request;
    return request;
  }

  @override
  Future<List<ConnectionRequest>> pendingRequests() async =>
      _requests.values.where((ConnectionRequest r) => r.doctorId == currentUid).toList();

  @override
  Future<ConnectionRequest> respond({required String requestId, required bool approve}) async {
    final ConnectionRequest? request = _requests.remove(requestId);
    if (request == null) throw StateError('Unknown request.');
    if (approve) _links[_patientIdFor(request)] = request.doctorId;
    return request;
  }

  /// The fake never receives a real `patientId` back from `invite` (the
  /// real backend's `ConnectionRequest`-shaped response doesn't carry one
  /// either — the caregiver already knows it), so it is threaded through
  /// via `_pendingPatientId` set by the test right before each `invite`.
  String? _pendingPatientId;
  set pendingPatientId(String value) => _pendingPatientId = value;
  String _patientIdFor(ConnectionRequest r) => _pendingPatientId ?? 'unknown-patient';

  @override
  Future<String?> forPatient(String patientId) async => _links[patientId];

  @override
  Future<void> disconnect(String patientId) async {
    _links.remove(patientId);
  }
}

void main() {
  test('a clinician who signs up is listed, and sees only their own requests', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);
    final _FakeDoctorConnectionService fake = _FakeDoctorConnectionService();
    state.attachDoctorConnections(fake);

    fake.currentUid = 'uid-doctor-real';
    await state.signInAccount('uid-doctor-real');
    state.setRole(AppRole.doctor);
    await state.updateMyDoctorProfile(
      name: 'Ritu Baruah',
      specialization: 'Neurologist',
      hospital: 'Nagaon District Hospital',
    );

    // Signing up is enough to be findable — no sample data involved.
    final DoctorProfile mine = state.myDoctorProfile!;
    expect(mine.name, 'Ritu Baruah');
    await state.loadDoctorDirectory();
    expect(state.doctorDirectory.map((DoctorProfile d) => d.id), contains(mine.id));

    // A caregiver invites them, and the request reaches that doctor.
    fake.pendingPatientId = 'p_1';
    await state.inviteDoctor(mine.id);

    await state.loadPendingDoctorRequests();
    expect(
      state.pendingDoctorRequests.where((ConnectionRequest r) => r.doctorId == mine.id),
      isNotEmpty,
    );

    // A different doctor asking sees nothing addressed to this one.
    fake.currentUid = 'uid-other-doctor';
    await state.loadPendingDoctorRequests();
    expect(state.pendingDoctorRequests, isEmpty);
  });

  test('accepting connects the doctor to the patient', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);
    final _FakeDoctorConnectionService fake = _FakeDoctorConnectionService();
    state.attachDoctorConnections(fake);

    fake.currentUid = 'uid-doc-hazarika';
    fake.pendingPatientId = state.patient.id;
    await state.inviteDoctor('uid-doc-hazarika');
    await state.loadPendingDoctorRequests();
    final ConnectionRequest req = state.pendingDoctorRequests
        .firstWhere((ConnectionRequest r) => r.doctorId == 'uid-doc-hazarika');

    await state.acceptConnectionRequest(req.id);
    await state.refreshConnectedDoctor();
    expect(state.connectedDoctor?.id, 'uid-doc-hazarika');
  });

  test('declining withdraws the invitation without connecting anyone', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);
    final _FakeDoctorConnectionService fake = _FakeDoctorConnectionService();
    state.attachDoctorConnections(fake);

    fake.currentUid = 'uid-doc-hazarika';
    fake.pendingPatientId = state.patient.id;
    await state.inviteDoctor('uid-doc-hazarika');
    await state.loadPendingDoctorRequests();
    final ConnectionRequest req = state.pendingDoctorRequests
        .firstWhere((ConnectionRequest r) => r.doctorId == 'uid-doc-hazarika');

    await state.declineConnectionRequest(req.id);
    await state.refreshConnectedDoctor();
    expect(state.connectedDoctor, isNull);
  });

  test('the onboarding step is optional — inviting is enough, so is skipping', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);
    final _FakeDoctorConnectionService fake = _FakeDoctorConnectionService();
    state.attachDoctorConnections(fake);
    fake.currentUid = 'uid-doc-hazarika';
    fake.pendingPatientId = state.patient.id;

    // Nothing about the questionnaire depends on a doctor replying: the step
    // is never what the flow resumes onto, so closing the app on it comes
    // back to the summary rather than to a stranger's inbox.
    expect(state.intake.nextStep, isNot(IntakeStep.doctor));

    // And an invitation is a complete outcome by itself.
    await state.inviteDoctor('uid-doc-hazarika');
    expect(state.statusOf(const DoctorProfile(id: 'uid-doc-hazarika', name: '', specialization: '', hospital: '', email: '')),
        InvitationStatus.sent);
    expect(state.intake.nextStep, isNot(IntakeStep.doctor));
  });

  test('disconnecting clears the connected doctor', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);
    final _FakeDoctorConnectionService fake = _FakeDoctorConnectionService();
    state.attachDoctorConnections(fake);

    fake.currentUid = 'uid-doc-barua';
    fake.pendingPatientId = state.patient.id;
    await state.inviteDoctor('uid-doc-barua');
    await state.loadPendingDoctorRequests();
    final ConnectionRequest req = state.pendingDoctorRequests.first;
    await state.acceptConnectionRequest(req.id);
    await state.refreshConnectedDoctor();
    expect(state.connectedDoctor?.id, 'uid-doc-barua');

    await state.disconnectDoctor('uid-doc-barua');
    expect(state.connectedDoctor, isNull);
  });
}
