import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/caregiver/caregiver_entry.dart';

/// Whether a caregiver is handed the questionnaire when they open the app.
///
/// Tested as the rule rather than as the screen: building the caregiver shell
/// in a harness never settles, and the thing worth protecting here is the
/// decision — getting it wrong means asking somebody fifteen questions they
/// have already answered, every time they sign in.
void main() {
  test('a brand-new caregiver is asked', () {
    final AppState state = AppState();
    addTearDown(state.dispose);
    expect(CaregiverEntry.isAlreadySetUp(state), isFalse);
  });

  test('an account that already names its patient is not asked again', () async {
    final AppState state = AppState();
    addTearDown(state.dispose);
    await state.signInAccount('uid-returning');

    // Enough answered to produce a real profile, but the final screen never
    // submitted — which is how most half-finished questionnaires end, and
    // what used to send this caregiver back to question one on every sign-in.
    state.saveIntakeProfile(
        name: 'Aama Devi', age: 72, language: 'English', occupation: 'Weaver');

    expect(state.intake.isComplete, isFalse,
        reason: 'the rule must not depend on the last screen alone');
    expect(state.hasPatientProfile, isTrue);
    expect(CaregiverEntry.isAlreadySetUp(state), isTrue);
  });

  test('finishing it here counts, before anything is written back', () {
    final AppState state = AppState();
    addTearDown(state.dispose);
    expect(CaregiverEntry.isAlreadySetUp(state, justFinished: true), isTrue);
  });
}
