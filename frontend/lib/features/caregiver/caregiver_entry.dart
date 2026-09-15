import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../intake/intake_flow.dart';
import 'caregiver_shell.dart';

/// Decides what a caregiver sees when they open the app.
///
/// The onboarding is the caregiver's because it is written for someone
/// answering *about* another person — who is helping to fill this in, what
/// has changed in their everyday life, what they can still do well — and a
/// person with cognitive change frequently under-reports exactly the things
/// it asks about, while the person living with them does not.
///
/// The test is whether the questionnaire has been answered, not whether
/// somebody is signed in. A brand-new account has answered nothing, so
/// creating one leads straight here and the profile is built at the end of
/// it; a returning account has answered it already and goes to the dashboard.
/// Gating on the account instead — which this briefly did — meant a new
/// caregiver signed up and landed on an empty dashboard with no profile
/// behind it.
///
/// It is still not a dead end: the dashboard keeps offering the onboarding in
/// its attention list for anyone who skips out of it half way.
///
/// Because every screen of it is written to disk as it is answered, a
/// caregiver who closes the app halfway through comes back to the next
/// unanswered question rather than to the beginning.
class CaregiverEntry extends StatefulWidget {
  const CaregiverEntry({super.key});

  @override
  State<CaregiverEntry> createState() => _CaregiverEntryState();

  /// Whether this account has been through setup already.
  ///
  /// Its own function so it can be tested without building the whole
  /// caregiver shell — which, inside a test harness, never settles.
  static bool isAlreadySetUp(AppState state, {bool justFinished = false}) =>
      justFinished || state.intake.isComplete || state.hasPatientProfile;
}

class _CaregiverEntryState extends State<CaregiverEntry> {
  /// Set when the questionnaire is finished *here*, so the shell stays put
  /// even though the record needs a moment to be written and read back.
  bool _justFinished = false;

  /// Set the first time this instance actually shows [IntakeFlowScreen].
  ///
  /// `isAlreadySetUp`'s `hasPatientProfile` half exists for a *returning*
  /// caregiver — someone who named their patient in an earlier session and
  /// closed the app before finishing. It cannot tell that case apart from a
  /// brand-new caregiver who just answered the first question of *this*
  /// onboarding: [PersonStep] writes the patient's name back to [AppState]
  /// as soon as its own "Continue" is pressed, which makes `hasPatientProfile`
  /// true two questions in. Because `build` re-reads the state on every
  /// rebuild (see below), that alone was enough to bounce a first-time
  /// caregiver out to an empty dashboard right after step 2, never reaching
  /// step 3. Once onboarding has actually been shown, only finishing it here
  /// — not a profile field arriving mid-flow — is allowed to leave it.
  bool _enteredOnboarding = false;

  @override
  Widget build(BuildContext context) {
    // Read through `AppScope.of`, not `read`, and decided on every build
    // rather than once in `initState`.
    //
    // Binding an account is asynchronous — the record comes off disk, and
    // anything this device has not seen is asked of the server. Deciding once,
    // at the moment this screen was created, meant deciding before any of
    // that had landed: a caregiver with a finished questionnaire was shown the
    // onboarding, and it stayed on screen even as the answers arrived behind
    // it. Now the answers arriving is a rebuild, and the rebuild shows the
    // dashboard.
    final AppState state = AppScope.of(context);

    // Three ways to be past the onboarding, not one.
    //
    // `intake.isComplete` alone was too strict: it is only true once the very
    // last screen of the questionnaire has been submitted, so a caregiver who
    // answered enough to produce a real profile — and who has been using the
    // app since — was sent back to question one every time they signed in.
    // Someone whose account already names the person they care for has
    // plainly done this before.
    //
    // But that "plainly done this before" test only holds before onboarding
    // has been shown *in this instance* — see `_enteredOnboarding`.
    //
    // The dashboard still offers to finish it, for as long as it is unfinished.
    final bool alreadySetUp =
        _justFinished || (!_enteredOnboarding && CaregiverEntry.isAlreadySetUp(state));
    if (alreadySetUp) {
      return const CaregiverShell();
    }

    _enteredOnboarding = true;
    return IntakeFlowScreen(
      onFinished: () => setState(() => _justFinished = true),
    );
  }
}
