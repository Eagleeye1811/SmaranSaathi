import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/game.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/mock/mock_data.dart';
import '../patient/games/game_launcher.dart';
import 'intake_kit.dart';

/// The handover from questionnaire to measurement.
///
/// Framing matters here more than anywhere else in the app. The person is
/// about to be measured, having just spent ten minutes describing what worries
/// them. So this screen says what the activities are for, how long they take,
/// and — twice — that a first session establishes *their own* starting point
/// rather than grading them against anyone else.
class BaselineIntroScreen extends StatelessWidget {
  const BaselineIntroScreen({super.key, required this.onBegin, this.onBack});

  final VoidCallback onBegin;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return IntakeScaffold(
      eyebrow: 'Baseline assessment',
      onBack: onBack,
      title: 'Your cognitive baseline',
      subtitle: 'Six short activities, about eight minutes in total.',
      continueLabel: 'Begin assessment',
      onContinue: onBegin,
      children: <Widget>[
        const CompanionSpeech(
          message: 'We will do these together. There is no pass or fail here.',
          state: CompanionState.encouraging,
        ),
        const SizedBox(height: Insets.lg),
        for (final GameDefinition game in MockData.games)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: MmCard(
              padding: const EdgeInsets.all(Insets.md),
              child: ListRow(
                leading: SoftIcon(
                  icon: game.domain.icon,
                  color: game.accent,
                  background: game.tint,
                ),
                title: game.name,
                subtitle: '${game.domain.clinicalLabel} · ${game.domain.measures}',
                trailing: Text('${game.estimatedMinutes} min', style: AppText.caption),
              ),
            ),
          ),
        const SizedBox(height: Insets.sm),
        const NotADiagnosisNote(
          message:
              'These activities are not a clinical test battery. Your first '
              'session becomes your personal reference point, and everything '
              'afterwards is compared with it rather than with other people.',
        ),
      ],
    );
  }
}

/// The baseline run itself: the six activities, in order, resumable.
///
/// Progress is written to the intake record after each activity, so a person
/// who needs a break — or whose phone locks — returns to the remaining
/// activities rather than starting again.
class BaselineRunScreen extends StatefulWidget {
  const BaselineRunScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<BaselineRunScreen> createState() => _BaselineRunScreenState();
}

class _BaselineRunScreenState extends State<BaselineRunScreen> {
  bool _capturing = false;
  String? _error;

  Future<void> _play(GameId id) async {
    final AppState state = AppScope.read(context);
    final int before = state.sessionsFor(id).length;
    await GameLauncher.open(context, id);
    if (!mounted) return;
    // Only count it when a session was actually recorded — leaving an activity
    // half way through must not mark it done.
    if (state.sessionsFor(id).length > before) {
      state.markBaselineActivity(id);
    }
    setState(() {});
    if (state.baselineRunComplete) await _finish();
  }

  /// Freezes the baseline and hands over to the profile.
  ///
  /// The `finally` matters: an earlier version left `_capturing` true if the
  /// capture threw, which disabled the only button on the screen permanently —
  /// a dead end at the very end of a twenty-minute assessment. A failure now
  /// re-enables the button and says what happened.
  Future<void> _finish() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    final AppState state = AppScope.read(context);
    try {
      await state.captureBaseline();
    } catch (error) {
      debugPrint('BaselineRunScreen: capturing the baseline failed ($error)');
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Your results are saved, but the profile could not be built '
            'just now. Tap again to retry.';
      });
      return;
    }
    if (!mounted) return;
    // The screen pops itself, using its own context: whoever opened it should
    // not have to know how many routes are on the stack above them.
    Navigator.of(context).maybePop();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final int done = GameId.values.length - state.baselineRemaining.length;
    final List<GameId> remaining = state.baselineRemaining;

    return IntakeScaffold(
      eyebrow: 'Baseline assessment',
      title: 'Activity $done of ${GameId.values.length}',
      subtitle: remaining.isEmpty
          ? 'All six are done. Building your profile…'
          : 'Take them at your own pace. You can stop and come back.',
      continueLabel: remaining.isEmpty ? 'See my profile' : 'Start next activity',
      onContinue: _capturing
          ? null
          : remaining.isEmpty
              ? _finish
              : () => _play(remaining.first),
      children: <Widget>[
        MeterBar(value: done / GameId.values.length, height: 10),
        if (_error != null) ...<Widget>[
          const SizedBox(height: Insets.md),
          MmCard(
            color: AppColors.dangerTint,
            padding: const EdgeInsets.all(Insets.md),
            child: Text(_error!, style: AppText.bodySmall.copyWith(color: AppColors.ink)),
          ),
        ],
        const SizedBox(height: Insets.lg),
        for (final GameDefinition game in MockData.games)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: MmCard(
              onTap: state.intake.baselineActivities.contains(game.id.name)
                  ? null
                  : () => _play(game.id),
              padding: const EdgeInsets.all(Insets.md),
              color: state.intake.baselineActivities.contains(game.id.name)
                  ? AppColors.successTint
                  : AppColors.surface,
              child: ListRow(
                leading: SoftIcon(
                  icon: state.intake.baselineActivities.contains(game.id.name)
                      ? Icons.check_rounded
                      : game.domain.icon,
                  color: state.intake.baselineActivities.contains(game.id.name)
                      ? AppColors.success
                      : game.accent,
                  background: state.intake.baselineActivities.contains(game.id.name)
                      ? AppColors.successTint
                      : game.tint,
                ),
                title: game.name,
                subtitle: game.domain.clinicalLabel,
                trailing: state.intake.baselineActivities.contains(game.id.name)
                    ? const PillTag(label: 'Done', color: AppColors.success, dense: true)
                    : const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens the baseline run as a full-screen route and reports completion.
Future<void> openBaselineRun(BuildContext context, {required VoidCallback onComplete}) {
  return Nav.open(
    context,
    BaselineRunScreen(onComplete: onComplete),
  );
}
