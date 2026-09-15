import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/models/positive_feedback.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/celebration.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';

/// The end of every activity. Encouraging first, informative second — and
/// never phrased like an exam result.
///
/// Deliberately shows no number, count, or level anywhere: a dementia
/// patient should never see anything that could read as a bad score on a
/// bad day. See `PositiveFeedbackEngine` for the guardrail this is built on.
class GameResultScreen extends StatelessWidget {
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

  /// Kept for call-site compatibility; deliberately unused here — activity
  /// tallies (pairs found, hints used…) are exactly the kind of raw count
  /// this screen no longer shows.
  final List<({String label, String value})> highlights;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    final Color accent = game.accent;
    final PositiveFeedback feedback = PositiveFeedbackEngine.build(
      game: game,
      performance: performance,
      decision: decision,
      l: l,
    );
    final bool celebrate = feedback.celebrate && !state.reduceMotion;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          MotifBackground(
            opacity: 0.04,
            color: accent,
            washColors: <Color>[
              game.tint.withValues(alpha: 0.95),
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
                        state: feedback.companionState,
                        size: 150,
                        animate: !state.reduceMotion,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeInUp(
                    delayMs: 60,
                    child: Text(
                      '${feedback.headline}, ${state.patient.shortName}!',
                      textAlign: TextAlign.center,
                      style: AppText.hero.sized(29),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeInUp(
                    delayMs: 90,
                    child: Text(
                      l.resultCompleted(game.localizedName(l)),
                      textAlign: TextAlign.center,
                      style: AppText.bodyLarge.tint(AppColors.inkSoft),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── How it went, in words only ─────────────────────────
                  FadeInUp(
                    delayMs: 130,
                    child: MmCard(
                      padding: const EdgeInsets.symmetric(
                          vertical: Insets.lg, horizontal: Insets.lg),
                      shadow: AppColors.liftShadow(),
                      child: Column(
                        children: <Widget>[
                          ProgressRing(
                            value: feedback.ringValue,
                            size: 130,
                            stroke: 14,
                            color: accent,
                            center: Icon(
                              Icons.favorite_rounded,
                              color: accent,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: Insets.lg),
                          Text(
                            feedback.domainNote,
                            textAlign: TextAlign.center,
                            style: AppText.body.wght(700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  // ── Companion's closing words ──────────────────────────
                  FadeInUp(
                    delayMs: 170,
                    child: CompanionSpeech(
                      message: feedback.body,
                      state: CompanionState.happy,
                      companionSize: 68,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  // ── What happens next, in plain language ───────────────
                  FadeInUp(
                    delayMs: 200,
                    child: _NextTimeCard(
                      direction: decision.direction,
                      message: feedback.nextSessionNote,
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

/// A single, plain-language line about the next session — no level numbers,
/// no internal "signals", no reasoning sentence. Just what changes and why
/// it's a good thing either way.
class _NextTimeCard extends StatelessWidget {
  const _NextTimeCard({required this.direction, required this.message});

  final DifficultyDirection direction;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (direction) {
      DifficultyDirection.increase => AppColors.success,
      DifficultyDirection.maintain => AppColors.secondary,
      DifficultyDirection.decrease => AppColors.accent,
    };

    return MmCard(
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      child: Row(
        children: <Widget>[
          SoftIcon(icon: direction.icon, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: AppText.bodySmall.wght(600)),
          ),
        ],
      ),
    );
  }
}
