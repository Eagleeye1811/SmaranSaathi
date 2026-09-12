import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/core/models/assessment.dart';
import 'package:smaran_saathi/core/models/doctor.dart';
import 'package:smaran_saathi/core/services/app_state.dart';

/// The doctor handshake, as state rather than as screens.
///
/// Pure `AppState` on purpose: the rules here — who may connect whom, whose
/// invitations a clinician can see — are the part that would be a real
/// problem if it were wrong, and they hold regardless of which widget is on
/// screen.
void main() {
  test('a clinician who signs up is listed, and sees only their own requests',
      () async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await state.signInAccount('uid-doctor-real');
    state.setRole(AppRole.doctor);
    state.updateMyDoctorProfile(
      name: 'Ritu Baruah',
      specialization: 'Neurologist',
      hospital: 'Nagaon District Hospital',
    );

    // Signing up is enough to be findable — no sample data involved.
    final DoctorProfile mine = state.myDoctorProfile!;
    expect(mine.name, 'Ritu Baruah');
    expect(state.doctorDirectory.map((DoctorProfile d) => d.id), contains(mine.id));

    // A caregiver invites them, and the request reaches that doctor.
    state.inviteDoctor(mine.id);
    expect(
      state.myConnectionRequests.where((ConnectionRequest r) => r.doctorId == mine.id),
      isNotEmpty,
    );

    // An invitation addressed to a different clinic is not theirs to read.
    state.inviteDoctor('doc_hazarika');
    expect(
      state.myConnectionRequests.where((ConnectionRequest r) => r.doctorId == 'doc_hazarika'),
      isEmpty,
    );

    // Accepting is what connects them — the caregiver cannot do it alone.
    final ConnectionRequest own = state.connectionRequests
        .firstWhere((ConnectionRequest r) => r.doctorId == mine.id);
    state.acceptConnectionRequest(own.id);
    expect(state.connectedDoctor?.id, mine.id);
  });

  test('declining withdraws the invitation', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    state.inviteDoctor('doc_hazarika');
    final ConnectionRequest req = state.connectionRequests
        .firstWhere((ConnectionRequest r) => r.doctorId == 'doc_hazarika');

    state.declineConnectionRequest(req.id);
    expect(
      state.doctorDirectory.firstWhere((DoctorProfile d) => d.id == 'doc_hazarika').status,
      InvitationStatus.notSent,
    );
    expect(state.connectedDoctor?.id, isNot('doc_hazarika'));
  });

  test('the onboarding step is optional — inviting is enough, so is skipping',
      () async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    // Nothing about the questionnaire depends on a doctor replying: the step
    // is never what the flow resumes onto, so closing the app on it comes
    // back to the summary rather than to a stranger's inbox.
    expect(state.intake.nextStep, isNot(IntakeStep.doctor));

    // And an invitation is a complete outcome by itself.
    state.inviteDoctor('doc_hazarika');
    expect(
      state.doctorDirectory.firstWhere((DoctorProfile d) => d.id == 'doc_hazarika').status,
      InvitationStatus.sent,
    );
    expect(state.intake.nextStep, isNot(IntakeStep.doctor));
  });

  test('only one doctor is connected at a time', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    expect(state.connectedDoctor, isNotNull);
    state.connectDoctor('doc_barua');
    expect(state.connectedDoctor?.id, 'doc_barua');
    expect(
      state.doctorDirectory
          .where((DoctorProfile d) => d.status == InvitationStatus.connected)
          .length,
      1,
    );
  });
}
