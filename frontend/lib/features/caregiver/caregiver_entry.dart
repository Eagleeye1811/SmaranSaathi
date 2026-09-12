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
}

class _CaregiverEntryState extends State<CaregiverEntry> {
  /// Set when the questionnaire is finished *here*, so the shell stays put
  /// even though the record needs a moment to be written and read back.
  bool _justFinished = false;

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
    if (_justFinished || state.intake.isComplete) return const CaregiverShell();

    return IntakeFlowScreen(
      onFinished: () => setState(() => _justFinished = true),
    );
  }
}
