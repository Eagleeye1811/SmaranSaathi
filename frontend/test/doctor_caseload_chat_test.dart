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
