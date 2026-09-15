import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_saathi/core/models/chat_message.dart';
import 'package:smaran_saathi/core/models/clinical.dart';
import 'package:smaran_saathi/core/services/app_state.dart';

void main() {
  group('a new doctor account has something to look at', () {
    test('the caseload is seeded rather than empty', () {
      final AppState state = AppState();
      // Nothing connected yet — exactly a freshly created doctor account.
      expect(state.connectedCaseload, isEmpty);
      expect(state.caseload, isNotEmpty,
          reason: 'an empty caseload shows a new clinician nothing');
    });

    test('every seeded patient is marked as a sample', () {
      final AppState state = AppState();
      expect(state.caseload.every((ClinicPatient p) => p.isDemo), isTrue);
    });

    test('a real patient is never flagged as a sample', () {
      final ClinicPatient fromBackend = ClinicPatient.fromJson(<String, dynamic>{
        'id': 'acct_uid-real',
        'name': 'Abhinav',
        'age': 72,
        // Even if the wire said otherwise, a real record stays real.
        'isDemo': true,
      });
      expect(fromBackend.isDemo, isFalse);
    });
  });

  _caregiverChatTests();

  group('doctor chat threads', () {
    test('the thread just replied to moves to the top', () {
      final AppState state = AppState();
      final List<DoctorConversation> before = state.doctorConversations;
      expect(before.length, greaterThan(1),
          reason: 'needs at least two threads to have an order at all');

      // Reply to whichever thread is currently last.
      final String bottomId = before.last.patientId;
      state.sendDoctorChatMessage(patientId: bottomId, text: 'Following up on this.');

      expect(state.doctorConversations.first.patientId, bottomId);
      expect(state.doctorConversations.first.lastMessage?.text, 'Following up on this.');
    });

    test('threads are ordered newest-first throughout', () {
      final AppState state = AppState();
      final List<DateTime> times = <DateTime>[
        for (final DoctorConversation c in state.doctorConversations)
          if (c.lastMessage != null) c.lastMessage!.timestamp,
      ];
      for (int i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isFalse,
            reason: 'thread $i is newer than the one above it');
      }
    });
  });
}

// ── The caregiver's side of the same thread ───────────────────────────────

void _caregiverChatTests() {
  test('a caregiver message is attributed to the caregiver, not the doctor',
      () {
    final AppState state = AppState();
    final String id = state.doctorConversations.first.patientId;

    state.sendDoctorChatMessage(
        patientId: id, text: 'Is the new dose alright?', fromDoctor: false);

    final ChatMessage sent = state.doctorConversations.first.lastMessage!;
    expect(sent.text, 'Is the new dose alright?');
    expect(sent.isFromDoctor, isFalse,
        reason: 'filed as the doctor, it would render on the wrong side for '
            'both of them');
  });

  test('a thread started by the caregiver carries real names, not placeholders',
      () {
    final AppState state = AppState();
    const String id = 'acct_cg-uid';

    // What the caregiver's device knows and the doctor's caseload does not.
    final DoctorConversation conv = state.getOrCreateDoctorConversation(
      id,
      patientName: 'Rohan',
      caregiverName: 'Virat',
      patientAge: 68,
      district: 'Guwahati, Assam',
    );

    expect(conv.patientName, 'Rohan');
    expect(conv.caregiverName, 'Virat');
    expect(conv.patientAge, 68);
    expect(conv.district, 'Guwahati, Assam');
  });

  test('a thread already created blind is healed once the names are known', () {
    final AppState state = AppState();
    const String id = 'acct_cg-uid';

    // Created before anyone said who it was with.
    final DoctorConversation blind = state.getOrCreateDoctorConversation(id);
    expect(blind.patientName, 'Connected Patient');
    expect(blind.caregiverName, 'Primary Caregiver');

    final DoctorConversation healed = state.getOrCreateDoctorConversation(
      id,
      patientName: 'Rohan',
      caregiverName: 'Virat',
    );
    expect(healed.patientName, 'Rohan');
    expect(healed.caregiverName, 'Virat');
    expect(state.doctorConversations.where((DoctorConversation c) => c.patientId == id).length, 1,
        reason: 'healing must not create a second thread');
  });

  test('a real name is never overwritten by a placeholder', () {
    final AppState state = AppState();
    const String id = 'acct_cg-uid';
    state.getOrCreateDoctorConversation(id, patientName: 'Rohan', caregiverName: 'Virat');

    // The doctor's side opens the same thread knowing nothing.
    final DoctorConversation again = state.getOrCreateDoctorConversation(id);
    expect(again.patientName, 'Rohan');
    expect(again.caregiverName, 'Virat');
  });

  test('the doctor and caregiver share one thread', () {
    final AppState state = AppState();
    final String id = state.doctorConversations.first.patientId;
    final int before = state.getOrCreateDoctorConversation(id).messages.length;

    state.sendDoctorChatMessage(patientId: id, text: 'Q', fromDoctor: false);
    state.sendDoctorChatMessage(patientId: id, text: 'A', fromDoctor: true);

    final DoctorConversation conv = state.getOrCreateDoctorConversation(id);
    expect(conv.messages.length, before + 2,
        reason: 'a second thread would have been started instead');
    expect(conv.messages[conv.messages.length - 2].isFromDoctor, isFalse);
    expect(conv.messages.last.isFromDoctor, isTrue);
  });
}
