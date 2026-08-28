import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../intake/intake_flow.dart';
import 'health/cognitive_profile_screen.dart';
import 'patient_shell.dart';

/// Decides what a person sees when they open the patient app.
///
/// Three states, in order: the structured intake if it has not been completed,
/// the profile reveal immediately after the baseline is captured, and the
/// dashboard from then on. Because the intake is written to disk step by step,
/// someone who closes the app halfway through the questionnaire comes back to
/// the next unanswered question rather than to the beginning.
class PatientEntry extends StatefulWidget {
  const PatientEntry({super.key});

  @override
  State<PatientEntry> createState() => _PatientEntryState();
}

enum _Phase { intake, reveal, shell }

class _PatientEntryState extends State<PatientEntry> {
  late _Phase _phase;

  @override
  void initState() {
    super.initState();
    _phase = AppScope.read(context).intakeComplete ? _Phase.shell : _Phase.intake;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.intake => IntakeFlowScreen(
          onFinished: () => setState(() => _phase = _Phase.reveal),
        ),
      _Phase.reveal => CognitiveProfileScreen(
          firstTime: true,
          onContinue: () => setState(() => _phase = _Phase.shell),
        ),
      _Phase.shell => const PatientShell(),
    };
  }
}
