import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/voice/voice_bootstrap.dart';
import '../../core/voice/voice_intake_controller.dart';
import 'intake_kit.dart';
import 'baseline_screens.dart';
import 'welcome_screens.dart';
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

  /// Back on the *first* step leaves the intake instead of doing nothing.
  ///
  /// Step 1 is reached by choosing "Patient" on the welcome screen, and
  /// wanting to undo that choice is an ordinary thing to want. Nothing is
  /// lost by leaving either way: every answer is already on disk, and coming
  /// back resumes at the first unanswered question via `nextIntakeStep`.
  ///
  /// There are two ways out because there are two ways in:
  ///
  ///  - *Pushed* by the role picker, with the welcome screen underneath —
  ///    popping is all it takes, and nobody is signed out.
  ///  - *The root route*, which is where signing in lands a returning
  ///    patient: `WelcomeScreen.continueFrom` uses `Nav.rootTo`, so the whole
  ///    stack below is gone and there is nothing to pop. Getting back to the
  ///    welcome screen then means ending the session, so we ask first — a
  ///    back arrow that silently signs someone out would be a trap.
  Future<void> _leave() async {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final AppState state = AppScope.read(context);
    if (state.accountId != null) {
      if (!await _confirmSignOut() || !mounted) return;

      final AuthService? auth = AuthScope.maybeOf(context);
      // Local first: the app must end up signed out even when Firebase is
      // unreachable, which on a rural connection it often is.
      await state.signOutAccount();
      try {
        await auth?.signOut();
      } catch (error) {
        debugPrint('IntakeFlowScreen: signing out of Firebase failed ($error)');
      }
      if (!mounted) return;
    }

    Nav.rootTo(context, const WelcomeScreen());
  }

  /// Signing out is the price of going back from a root intake, so it is
  /// stated plainly — including the part people actually worry about, which
  /// is whether their answers survive it.
  Future<bool> _confirmSignOut() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Go back and log out?'),
            content: const Text(
              'Going back to the start signs you out on this device. Your '
              'answers stay saved and come back when you sign in again.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay here'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Go back and log out'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Within the flow this steps back a question; on step 1 it steps out of
  /// the flow. Never null — every route into the intake has a way back out.
  VoidCallback get _onBack => _index > 0 ? _back : _leave;

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
