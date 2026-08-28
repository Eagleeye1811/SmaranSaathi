import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/celebration.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';

/// The end of every activity. Encouraging first, informative second — and
/// never phrased like an exam result.
class GameResultScreen extends StatefulWidget {
  const GameResultScreen({
    super.key,
    required this.game,
    required this.performance,
    required this.decision,
    required this.playedLevel,
    this.highlights = const <({String label, String value})>[],
  });

  final GameDefinition game;
  final GamePerformance performance;
  final AdaptiveDecision decision;
  final int playedLevel;

  /// Optional activity-specific figures (objects found, pairs matched…).
  final List<({String label, String value})> highlights;

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen> {
  bool _showAdaptive = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showAdaptive = true);
    });
  }

  String get _headline {
    final int s = widget.performance.overall;
    if (s >= 85) return 'Wonderful';
    if (s >= 70) return 'Very well done';
    if (s >= 55) return 'Nicely done';
    return 'Thank you for trying';
  }

  String get _closing {
    final int s = widget.performance.overall;
    if (s >= 85) return 'You did very well today. I enjoyed that.';
    if (s >= 70) return 'That was a good session. You stayed with it.';
    if (s >= 55) return 'You worked steadily. That is what matters.';
    return 'Finishing is the important part. We will try again together.';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    final GamePerformance p = widget.performance;
    final Color accent = widget.game.accent;
    final bool celebrate = p.overall >= 70 && !state.reduceMotion;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          MotifBackground(
            opacity: 0.04,
            color: accent,
            washColors: <Color>[
              widget.game.tint.withValues(alpha: 0.95),
              AppColors.background.withValues(alpha: 0),
            ],
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 30),
                children: <Widget>[
                  // ── Celebration ────────────────────────────────────────
                  FadeInUp(
                    child: Center(
                      child: Companion(
                        state: p.overall >= 70
                            ? CompanionState.celebrating
                            : CompanionState.encouraging,
                        size: 150,
                        animate: !state.reduceMotion,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeInUp(
                    delayMs: 60,
                    child: Text(
                      '$_headline, ${state.patient.shortName}!',
                      textAlign: TextAlign.center,
                      style: AppText.hero.sized(29),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeInUp(
                    delayMs: 90,
                    child: Text(
                      'You completed ${widget.game.name}.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyLarge.tint(AppColors.inkSoft),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Headline number ────────────────────────────────────
                  FadeInUp(
                    delayMs: 130,
                    child: MmCard(
                      padding: const EdgeInsets.symmetric(
                          vertical: Insets.lg, horizontal: Insets.lg),
                      shadow: AppColors.liftShadow(),
                      child: Column(
                        children: <Widget>[
                          ProgressRing(
                            value: p.overall / 100,
                            size: 150,
                            stroke: 14,
                            color: accent,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: p.overall.toDouble()),
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.easeOutCubic,
                                  builder: (BuildContext context, double v, _) => Text(
                                    '${v.round()}%',
                                    style: AppText.statHuge.sized(42).tint(accent),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('Cognitive\nperformance',
                                    textAlign: TextAlign.center, style: AppText.caption),
                              ],
                            ),
                          ),
                          const SizedBox(height: Insets.lg),
                          _MetricRow(
                              label: l.resultAccuracy, value: p.accuracy.round(), color: accent),
                          const SizedBox(height: 12),
                          _MetricRow(label: l.resultFocus, value: p.focus.round(), color: accent),
                          const SizedBox(height: 12),
                          _MetricRow(label: l.resultMemory, value: p.memory.round(), color: accent),
                          const SizedBox(height: Insets.md),
                          const Divider(color: AppColors.hairline),
                          const SizedBox(height: Insets.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _MiniStat(
                                icon: Icons.schedule_rounded,
                                label: l.resultTime,
                                value: p.durationLabel,
                              ),
                              _MiniStat(
                                icon: Icons.lightbulb_outline_rounded,
                                label: l.resultHints,
                                value: '${p.hintsUsed}',
                              ),
                              _MiniStat(
                                icon: Icons.replay_rounded,
                                label: l.resultRetries,
                                value: '${p.mistakes}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  // ── Activity-specific figures ──────────────────────────
                  if (widget.highlights.isNotEmpty) ...<Widget>[
                    FadeInUp(
                      delayMs: 150,
                      child: MmCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md, vertical: Insets.md),
                        child: Wrap(
                          alignment: WrapAlignment.spaceAround,
                          spacing: 8,
                          runSpacing: 14,
                          children: <Widget>[
                            for (final ({String label, String value}) h in widget.highlights)
                              SizedBox(
                                width: 92,
                                child: Column(
                                  children: <Widget>[
                                    Text(h.value, style: AppText.stat.tint(accent)),
                                    const SizedBox(height: 3),
                                    Text(h.label,
                                        textAlign: TextAlign.center, style: AppText.caption),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                  ],

                  // ── Companion's closing words ──────────────────────────
                  FadeInUp(
                    delayMs: 170,
                    child: CompanionSpeech(
                      message: _closing,
                      state: CompanionState.happy,
                      companionSize: 68,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  // ── Adaptive difficulty ────────────────────────────────
                  AnimatedSlide(
                    offset: _showAdaptive ? Offset.zero : const Offset(0, 0.12),
                    duration: Motion.slow,
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _showAdaptive ? 1 : 0,
                      duration: Motion.slow,
                      child: _AdaptiveCard(
                        decision: widget.decision,
                        game: widget.game,
                        playedLevel: widget.playedLevel,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  BigButton(
                    label: l.actionContinue,
                    icon: Icons.arrow_forward_rounded,
                    color: accent,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
          if (celebrate) const Positioned.fill(child: ConfettiOverlay()),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 86,
          child: Text(label, style: AppText.body.wght(600).tint(AppColors.inkSoft)),
        ),
        Expanded(child: MeterBar(value: value / 100, color: color, height: 9)),
        const SizedBox(width: 12),
        SizedBox(
          width: 46,
          child: Text('$value%',
              textAlign: TextAlign.right, style: AppText.body.wght(800).tint(color)),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.inkMuted),
        const SizedBox(height: 6),
        Text(value, style: AppText.body.wght(800)),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

class _AdaptiveCard extends StatelessWidget {
  const _AdaptiveCard({
    required this.decision,
    required this.game,
    required this.playedLevel,
  });

  final AdaptiveDecision decision;
  final GameDefinition game;
  final int playedLevel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color color = switch (decision.direction) {
      DifficultyDirection.increase => AppColors.success,
      DifficultyDirection.maintain => AppColors.secondary,
      DifficultyDirection.decrease => AppColors.accent,
    };

    return MmCard(
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: decision.direction.icon, color: color, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.resultAdjusted,
                        style: AppText.body.wght(800)),
                    const SizedBox(height: 3),
                    Text(decision.direction.patientMessage, style: AppText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _LevelChip(
                  caption: l.resultThisSession,
                  level: playedLevel,
                  detail: AdaptiveDifficultyService.levelDescription(game.id, playedLevel),
                  color: AppColors.inkMuted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 20, color: color),
              ),
              Expanded(
                child: _LevelChip(
                  caption: l.resultNextSession,
                  level: decision.nextLevel,
                  detail:
                      AdaptiveDifficultyService.levelDescription(game.id, decision.nextLevel),
                  color: color,
                  emphasised: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(l.resultWhatMitraNoticed, style: AppText.overline),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String s in decision.signals)
                PillTag(label: s, color: AppColors.inkSoft, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(decision.reason, style: AppText.bodySmall),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.caption,
    required this.level,
    required this.detail,
    required this.color,
    this.emphasised = false,
  });

  final String caption;
  final int level;
  final String detail;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: Corners.r(Corners.sm),
        border: Border.all(
          color: emphasised ? color.withValues(alpha: 0.4) : AppColors.hairline,
          width: emphasised ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(caption.toUpperCase(),
              style: AppText.overline.sized(10), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Text('Level $level',
              style: AppText.body.wght(800).tint(color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          DifficultyDots(level: level, color: color, size: 7),
          const SizedBox(height: 7),
          Text(detail, style: AppText.caption.sized(11.5), maxLines: 3),
        ],
      ),
    );
  }
}
