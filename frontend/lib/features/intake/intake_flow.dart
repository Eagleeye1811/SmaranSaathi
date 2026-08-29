import 'package:flutter/material.dart';

import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_bootstrap.dart';
import '../../core/voice/voice_intake_controller.dart';
import 'intake_kit.dart';
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

  /// Owned by the flow, not by a step: saying "next" on the last question of a
  /// screen has to move the flow on, which no single step can do for itself.
  late final VoiceIntakeController _voice = buildVoiceIntakeController(
    onAdvance: _advance,
    onGoBack: _back,
  );

  @override
  void initState() {
    super.initState();
    // Resume where the person stopped rather than at the first question.
    final IntakeStep next = AppScope.read(context).nextIntakeStep;
    final int found = _order.indexOf(next);
    _index = found < 0 ? 0 : found;
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
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
    return VoiceIntakeScope(
      controller: _voice,
      child: _step,
    );
  }

  Widget get _step {
    return switch (_order[_index]) {
      IntakeStep.consent => ConsentStep(onDone: _advance, onBack: _onBack),
      IntakeStep.profile => ProfileStep(onDone: _advance, onBack: _onBack),
      IntakeStep.reason => ReasonStep(onDone: _advance, onBack: _onBack),
      IntakeStep.safety => SafetyStep(onDone: _advance, onBack: _onBack),
      IntakeStep.symptoms => SymptomStep(onDone: _advance, onBack: _onBack),
      IntakeStep.function => FunctionStep(onDone: _advance, onBack: _onBack),
      IntakeStep.medical => MedicalStep(onDone: _advance, onBack: _onBack),
      IntakeStep.caregiver => CaregiverStep(onDone: _advance, onBack: _onBack),
      // The questionnaire ends here. The six activities are no longer run in
      // one sitting off the back of it: the intro closes the intake, and the
      // three daily sessions are invited by the companion on the dashboard.
      IntakeStep.baseline || IntakeStep.done => BaselineIntroScreen(
          onBack: _onBack,
          onBegin: () {
            AppScope.read(context).completeIntakeQuestionnaire();
            widget.onFinished();
          },
        ),
    };
  }
}
