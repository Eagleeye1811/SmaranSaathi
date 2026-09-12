import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/voice/voice_bootstrap.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../core/voice/voice_language.dart';
import 'intake_kit.dart';
import 'onboarding_summary_screen.dart';
import 'welcome_screens.dart';
import 'steps_consent_profile.dart';
import 'steps_medical_caregiver.dart';
import 'steps_reason_safety.dart';
import 'steps_symptoms_function.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_controller.dart';

/// The onboarding, start to finish.
///
/// Held in one widget rather than as twelve pushed routes so that "where am I"
/// is a single integer: the flow can resume at the first unanswered step after
/// the app is closed, and back never escapes into a half-built navigation
/// stack. [AppState] owns the answers; this owns only the position.
///
/// The order is [IntakeRecord.order] rather than a second list kept here,
/// because [IntakeRecord.nextStep] resumes against that list and two lists
/// that disagreed would resume someone onto the wrong screen.
class IntakeFlowScreen extends StatefulWidget {
  const IntakeFlowScreen({super.key, required this.onFinished});

  /// Called once the baseline has been captured and the profile exists.
  final VoidCallback onFinished;

  @override
  State<IntakeFlowScreen> createState() => _IntakeFlowScreenState();
}

class _IntakeFlowScreenState extends State<IntakeFlowScreen> {
  static const List<IntakeStep> _order = IntakeRecord.order;

  late int _index;

  VoiceIntakeController? _voice;

  VoiceIntakeController _ensureVoice() {
    if (_voice != null) return _voice!;
    final LocaleController? locale = LocaleScope.maybeRead(context);
    return _voice = buildVoiceIntakeController(
      onAdvance: _advance,
      onGoBack: _back,
      language: locale?.voiceLanguage ?? VoiceLanguage.english,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LocaleController? locale = LocaleScope.maybeOf(context);
    if (_voice != null && locale != null && _voice!.language != locale.voiceLanguage) {
      _voice!.setLanguage(locale.voiceLanguage);
    }
  }

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
    _voice?.dispose();
    super.dispose();
  }

  void _advance() {
    if (_index >= _order.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() => _index = _skipEmpty(_index + 1, 1));
  }

  void _back() {
    if (_index > 0) setState(() => _index = _skipEmpty(_index - 1, -1));
  }

  /// Steps over a screen that has nothing to show.
  ///
  /// Only the follow-up screen can be empty, and it is empty whenever none of
  /// the three named difficulties has follow-ups in [ProbeCatalogue] — which
  /// includes the common case of "no major difficulties noticed". Skipping it
  /// in both directions matters: a blank screen that reappears when you press
  /// back is worse than one that never appeared.
  int _skipEmpty(int index, int direction) {
    int at = index;
    while (at > 0 && at < _order.length - 1 && _isEmptyStep(_order[at])) {
      at += direction;
    }
    return at.clamp(0, _order.length - 1);
  }

  bool _isEmptyStep(IntakeStep step) =>
      step == IntakeStep.probes &&
      AppScope.read(context).intake.onboarding.activeProbes.isEmpty;

  /// Back on the *first* step leaves the onboarding instead of doing nothing.
  ///
  /// Step 1 is reached by choosing "Caregiver" on the authentication screen,
  /// and wanting to undo that choice is an ordinary thing to want. Nothing is
  /// lost by leaving either way: every answer is already on disk, and coming
  /// back resumes at the first unanswered question via `nextIntakeStep`.
  ///
  /// There are two ways out because there are two ways in:
  ///
  ///  - *Pushed* by the authentication screen, with the greeting underneath —
  ///    popping is all it takes, and nobody is signed out.
  ///  - *The root route*, which is where signing in lands a returning
  ///    caregiver: `WelcomeScreen.continueFrom` uses `Nav.rootTo`, so the
  ///    whole stack below is gone and there is nothing to pop. Getting back to
  ///    the greeting then means ending the session, so we ask first — a back
  ///    arrow that silently signs someone out would be a trap.
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
            title: Text(AppLocalizations.of(context).goBackAndLogOutConfirm),
            content: const Text(
              'Going back to the start signs you out on this device. Your '
              'answers stay saved and come back when you sign in again.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(context).stayHere),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(AppLocalizations.of(context).goBackAndLogOut),
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
      controller: _ensureVoice(),
      child: _step,
    );
  }

  Widget get _step {
    return switch (_order[_index]) {
      IntakeStep.consent => ConsentStep(onDone: _advance, onBack: _onBack),
      // ── Part A · knowing the person ─────────────────────────────────
      IntakeStep.person => PersonStep(onDone: _advance, onBack: _onBack),
      IntakeStep.health => HealthBackgroundStep(onDone: _advance, onBack: _onBack),
      IntakeStep.everyday => EverydayStep(onDone: _advance, onBack: _onBack),
      IntakeStep.probes => ProbesStep(onDone: _advance, onBack: _onBack),
      IntakeStep.example => RecentExampleStep(onDone: _advance, onBack: _onBack),
      IntakeStep.independence => IndependenceStep(onDone: _advance, onBack: _onBack),
      IntakeStep.behaviour => BehaviourStep(onDone: _advance, onBack: _onBack),
      IntakeStep.dailySafety => DailySafetyStep(onDone: _advance, onBack: _onBack),
      // ── Part B · knowing their life ─────────────────────────────────
      IntakeStep.strengths => StrengthsStep(onDone: _advance, onBack: _onBack),
      IntakeStep.goals => GoalsStep(onDone: _advance, onBack: _onBack),
      // The onboarding ends by reading the answers back. The six activities
      // are not run off the back of it: the three daily baseline sessions are
      // invited by the companion on the dashboard instead.
      IntakeStep.summary || IntakeStep.done => OnboardingSummaryScreen(
          onBack: _onBack,
          onFinish: widget.onFinished,
        ),
    };
  }
}
