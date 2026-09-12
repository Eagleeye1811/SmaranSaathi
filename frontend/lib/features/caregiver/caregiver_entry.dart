import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../intake/intake_flow.dart';
import 'caregiver_shell.dart';

/// Decides what a caregiver sees when they open the app.
///
/// Two states: the onboarding while it is unanswered, and the dashboard from
/// then on. The onboarding is the caregiver's because it is written for
/// someone answering *about* another person — who is helping to fill this in,
/// what has changed in their everyday life, what they can still do well — and
/// a person with cognitive change frequently under-reports exactly the things
/// it asks about, while the person living with them does not.
///
/// Because every screen of it is written to disk as it is answered, a
/// caregiver who closes the app halfway through comes back to the next
/// unanswered question rather than to the beginning.
class CaregiverEntry extends StatefulWidget {
  const CaregiverEntry({super.key});

  @override
  State<CaregiverEntry> createState() => _CaregiverEntryState();
}

enum _Phase { onboarding, shell }

class _CaregiverEntryState extends State<CaregiverEntry> {
  late _Phase _phase;

  @override
  void initState() {
    super.initState();
    _phase = AppScope.read(context).intake.isComplete ? _Phase.shell : _Phase.onboarding;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.onboarding => IntakeFlowScreen(
          onFinished: () => setState(() => _phase = _Phase.shell),
        ),
      _Phase.shell => const CaregiverShell(),
    };
  }
}
