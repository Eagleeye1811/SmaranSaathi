import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/clinical.dart';
import '../../core/models/game.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/mock/mock_data.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/content_labels.dart';
import '../patient/games/game_launcher.dart';
import 'intake_kit.dart';

/// The handover from questionnaire to daily use.
///
/// Framing matters here more than anywhere else in the app. The person has
/// just spent ten minutes describing what worries them, so the first thing
/// they see afterwards is what is *working* — drawn from their own answers —
/// followed by the plan. Nothing on this screen is a score of their brain and
/// nothing on it is a risk figure; it is the strengths their answers already
/// show, and what the next three days will add to them.
class BaselineIntroScreen extends StatelessWidget {
  const BaselineIntroScreen({super.key, required this.onBegin, this.onBack});

  final VoidCallback onBegin;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final IntakeRecord intake = state.intake;
    final String name =
        state.patient.shortName.isEmpty ? l.intakeBaselineFriendFallback : state.patient.shortName;

    // Everything below is phrased as a strength, because every one of these
    // numbers *is* one: they are the parts of daily life the person told us
    // are still theirs.
    final int independence = intake.function.independencePercent;
    final double symptomLoad = SymptomDomain.values
            .map(intake.symptoms.severity)
            .reduce((double a, double b) => a + b) /
        SymptomDomain.values.length;
    final int steadyDays = (100 - symptomLoad).clamp(35, 100).round();
    final int support = intake.caregiver != null ? 100 : 70;
    final int health = (100 - intake.medical.vascularRiskCount * 12).clamp(40, 100).round();

    final List<SeriesPoint> strengths = <SeriesPoint>[
      SeriesPoint(l.intakeBaselineChartDailyLiving, independence.toDouble()),
      SeriesPoint(l.intakeBaselineChartSteadyDays, steadyDays.toDouble()),
      SeriesPoint(l.intakeBaselineChartSupport, support.toDouble()),
      SeriesPoint(l.intakeBaselineChartHealthBasics, health.toDouble()),
    ];

    return IntakeScaffold(
      eyebrow: l.intakeBaselineEyebrow,
      onBack: onBack,
      title: l.intakeBaselineTitle,
      subtitle: l.intakeBaselineSubtitle(name),
      continueLabel: l.intakeBaselineStartJourney,
      onContinue: onBegin,
      footnote: l.intakeBaselineFootnote,
      children: <Widget>[
        CompanionSpeech(
          message: l.intakeBaselineCompanionThanks(name),
          state: CompanionState.encouraging,
        ),
        const SizedBox(height: Insets.lg),

        // ── What is going well ────────────────────────────────────────────
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.intakeBaselineStrengthsTitle, style: AppText.h3),
              const SizedBox(height: 4),
              Text(
                l.intakeBaselineStrengthsSubtitle,
                style: AppText.bodySmall,
              ),
              const SizedBox(height: Insets.md),
              BarSeriesChart(
                points: strengths,
                color: AppColors.success,
                height: 160,
                showValues: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),

        // ── Why the activities help ───────────────────────────────────────
        MmCard(
          color: AppColors.primaryTint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.intakeBaselineBenefitsTitle, style: AppText.h3),
              const SizedBox(height: Insets.sm),
              for (final (IconData icon, String line) benefit in <(IconData, String)>[
                (Icons.timeline_rounded, l.intakeBaselineBenefit1),
                (Icons.self_improvement_rounded, l.intakeBaselineBenefit2),
                (Icons.medical_information_outlined, l.intakeBaselineBenefit3),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(benefit.$1, size: 20, color: AppColors.primaryDeep),
                      const SizedBox(width: 10),
                      Expanded(child: Text(benefit.$2, style: AppText.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),

        // ── The three-day plan ────────────────────────────────────────────
        Text(l.intakeBaselinePlanTitle, style: AppText.h3),
        const SizedBox(height: 4),
        Text(
          l.intakeBaselinePlanSubtitle,
          style: AppText.bodySmall,
        ),
        const SizedBox(height: Insets.md),
        for (int day = 0; day < AppState.baselinePlan.length; day++)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: MmCard(
              padding: const EdgeInsets.all(Insets.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SoftIcon(
                    icon: Icons.wb_sunny_rounded,
                    color: AppColors.accent,
                    background: AppColors.accentTint,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.intakeBaselineDayN(day + 1), style: AppText.bodyLarge.wght(700)),
                        const SizedBox(height: 2),
                        Text(
                          AppState.baselinePlan[day]
                              .map((GameId g) => MockData.game(g).name)
                              .join(' · '),
                          style: AppText.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PillTag(label: l.intakeBaselineTwoActivities, dense: true),
                ],
              ),
            ),
          ),
        const SizedBox(height: Insets.sm),
        NotADiagnosisNote(
          message: l.intakeBaselineDisclaimer,
        ),
      ],
    );
  }
}

/// One day of the baseline: the two activities planned for today.
///
/// Reached from the dashboard, not from the questionnaire — the companion on
/// the home screen invites the session, which is where the habit has to live
/// once the baseline is finished. The last session of the third day freezes
/// the baseline and opens the profile.
class BaselineSessionScreen extends StatefulWidget {
  const BaselineSessionScreen({super.key, required this.onComplete});

  /// Called once all six activities are done and the baseline is captured.
  final VoidCallback onComplete;

  @override
  State<BaselineSessionScreen> createState() => _BaselineSessionScreenState();
}

class _BaselineSessionScreenState extends State<BaselineSessionScreen> {
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
    if (state.baselineRunComplete && !state.baselineReady) await _finish();
  }

  /// Freezes the baseline and hands over to the profile.
  ///
  /// A failure must not brick the screen: an earlier version left `_capturing`
  /// true, which disabled the only button permanently — a dead end at the very
  /// end of a three-day assessment.
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
      debugPrint('BaselineSessionScreen: capturing the baseline failed ($error)');
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = AppLocalizations.of(context).intakeBaselineCaptureError;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final int day = state.baselineDayIndex;
    final bool allDone = state.baselineRunComplete;
    final List<GameId> today = allDone
        ? AppState.baselinePlan.last
        : AppState.baselinePlan[day];
    final List<GameId> remaining = state.baselineTodayRemaining;
    final int done = today.length - remaining.length;
    final int totalDone = GameId.values.length - state.baselineRemaining.length;

    return IntakeScaffold(
      eyebrow: l.intakeBaselineDayOfTotal(
          allDone ? AppState.baselinePlan.length : day + 1, AppState.baselinePlan.length),
      title: allDone ? l.intakeBaselineAllSixDone : l.intakeBaselineTodaysSession,
      subtitle: allDone ? l.intakeBaselineBuildingProfile : l.intakeBaselineTodaySubtitle,
      continueLabel: allDone
          ? l.intakeBaselineSeeProfile
          : remaining.isEmpty
              ? l.intakeBaselineDoneForToday
              : l.intakeBaselineStartGame(MockData.game(remaining.first).name),
      onContinue: _capturing
          ? null
          : allDone && !state.baselineReady
              ? _finish
              : remaining.isEmpty
                  ? () => Navigator.of(context).maybePop()
                  : () => _play(remaining.first),
      children: <Widget>[
        CompanionSpeech(
          message: allDone
              ? l.intakeBaselineCompanionAllDone
              : done == 0
                  ? l.intakeBaselineCompanionStart
                  : l.intakeBaselineCompanionOneToGo,
          state: done == 0 ? CompanionState.encouraging : CompanionState.celebrating,
        ),
        const SizedBox(height: Insets.lg),
        MeterBar(value: totalDone / GameId.values.length, height: 10),
        const SizedBox(height: 6),
        Text(l.intakeBaselineTotalProgress(totalDone, GameId.values.length),
            style: AppText.caption),
        if (_error != null) ...<Widget>[
          const SizedBox(height: Insets.md),
          MmCard(
            color: AppColors.dangerTint,
            padding: const EdgeInsets.all(Insets.md),
            child: Text(_error!, style: AppText.bodySmall.copyWith(color: AppColors.ink)),
          ),
        ],
        const SizedBox(height: Insets.lg),
        for (final GameId id in today)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: _ActivityRow(
              game: MockData.game(id),
              done: state.intake.baselineActivities.contains(id.name),
              onTap: state.intake.baselineActivities.contains(id.name)
                  ? null
                  : () => _play(id),
            ),
          ),
        if (remaining.isEmpty && !allDone) ...<Widget>[
          const SizedBox(height: Insets.sm),
          MmCard(
            color: AppColors.successTint,
            child: Row(
              children: <Widget>[
                const SoftIcon(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  background: AppColors.successTint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.intakeBaselineSessionComplete(day + 1),
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.game, required this.done, this.onTap});

  final GameDefinition game;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.md),
      color: done ? AppColors.successTint : AppColors.surface,
      child: ListRow(
        leading: SoftIcon(
          icon: done ? Icons.check_rounded : game.domain.icon,
          color: done ? AppColors.success : game.accent,
          background: done ? AppColors.successTint : game.tint,
        ),
        title: game.localizedName(l),
        subtitle: l.intakeBaselineActivityMinutes(game.domain.clinicalLabel, game.estimatedMinutes),
        trailing: done
            ? PillTag(label: l.intakeBaselineDone, color: AppColors.success, dense: true)
            : const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
      ),
    );
  }
}

/// Opens today's baseline session as a full-screen route.
Future<void> openBaselineSession(BuildContext context, {required VoidCallback onComplete}) {
  return Nav.open(context, BaselineSessionScreen(onComplete: onComplete));
}
