import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../intake/intake_flow.dart';
import 'patient_shell.dart';

/// Decides what a person sees when they open the patient app.
///
/// Two states: the structured intake while the questionnaire is unanswered,
/// and the dashboard from then on. Because the intake is written to disk step
/// by step, someone who closes the app halfway through comes back to the next
/// unanswered question rather than to the beginning.
///
/// The dashboard is reached *before* a baseline exists — that is the point of
/// the three-day plan. The companion on the home screen runs the two daily
/// activities, and the profile reveal is opened by the last of them.
class PatientEntry extends StatefulWidget {
  const PatientEntry({super.key});

  @override
  State<PatientEntry> createState() => _PatientEntryState();
}

enum _Phase { intake, shell }

class _PatientEntryState extends State<PatientEntry> {
  late _Phase _phase;

  @override
  void initState() {
    super.initState();
    // The questionnaire, not the baseline: someone who has answered every
    // question belongs on their dashboard even though the profile is still
    // three sessions away.
    _phase = AppScope.read(context).intake.isComplete ? _Phase.shell : _Phase.intake;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.intake => IntakeFlowScreen(
          onFinished: () => setState(() => _phase = _Phase.shell),
        ),
      _Phase.shell => const PatientShell(),
    };
  }
}
