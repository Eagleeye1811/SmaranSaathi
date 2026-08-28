import 'package:flutter/material.dart';

import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import 'baseline_screens.dart';
import 'steps_consent_profile.dart';
import 'steps_medical_caregiver.dart';
import 'steps_reason_safety.dart';
import 'steps_symptoms_function.dart';

/// The intake, start to finish.
///
/// Held in one widget rather than as nine pushed routes so that "where am I"
/// is a single integer: the flow can resume at the first unanswered step after
/// the app is closed, and back never escapes into a half-built navigation
/// stack. [AppState] owns the answers; this owns only the position.
class IntakeFlowScreen extends StatefulWidget {
  const IntakeFlowScreen({super.key, required this.onFinished});

  /// Called once the baseline has been captured and the profile exists.
  final VoidCallback onFinished;

  @override
  State<IntakeFlowScreen> createState() => _IntakeFlowScreenState();
}

class _IntakeFlowScreenState extends State<IntakeFlowScreen> {
  static const List<IntakeStep> _order = <IntakeStep>[
    IntakeStep.consent,
    IntakeStep.profile,
    IntakeStep.reason,
    IntakeStep.safety,
    IntakeStep.symptoms,
    IntakeStep.function,
    IntakeStep.medical,
    IntakeStep.caregiver,
    IntakeStep.baseline,
  ];

  late int _index;

  @override
  void initState() {
    super.initState();
    // Resume where the person stopped rather than at the first question.
    final IntakeStep next = AppScope.read(context).nextIntakeStep;
    final int found = _order.indexOf(next);
    _index = found < 0 ? 0 : found;
  }

  void _advance() {
    if (_index < _order.length - 1) {
      setState(() => _index++);
    } else {
      widget.onFinished();
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  VoidCallback? get _onBack => _index == 0 ? null : _back;

  @override
  Widget build(BuildContext context) {
    return switch (_order[_index]) {
      IntakeStep.consent => ConsentStep(onDone: _advance, onBack: _onBack),
      IntakeStep.profile => ProfileStep(onDone: _advance, onBack: _onBack),
      IntakeStep.reason => ReasonStep(onDone: _advance, onBack: _onBack),
      IntakeStep.safety => SafetyStep(onDone: _advance, onBack: _onBack),
      IntakeStep.symptoms => SymptomStep(onDone: _advance, onBack: _onBack),
      IntakeStep.function => FunctionStep(onDone: _advance, onBack: _onBack),
      IntakeStep.medical => MedicalStep(onDone: _advance, onBack: _onBack),
      IntakeStep.caregiver => CaregiverStep(onDone: _advance, onBack: _onBack),
      IntakeStep.baseline || IntakeStep.done => BaselineIntroScreen(
          onBack: _onBack,
          // The run screen pops itself once the baseline is captured; this
          // only has to move the journey on.
          onBegin: () => openBaselineRun(context, onComplete: widget.onFinished),
        ),
    };
  }
}
