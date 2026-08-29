import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';

/// Tracks the signals every activity feeds to the adaptive engine.
class GameTracker {
  GameTracker();

  final DateTime _start = DateTime.now();
  int hints = 0;
  int mistakes = 0;
  int correct = 0;
  int attempts = 0;

  int get seconds => DateTime.now().difference(_start).inSeconds;

  double get accuracy => attempts == 0 ? 100 : (correct / attempts * 100).clamp(0, 100);

  /// Focus falls with repeated wrong taps and with a slow pace.
  double focus(int expectedSeconds) {
    final double paceScore =
        (100 - ((seconds - expectedSeconds) / expectedSeconds * 40)).clamp(45, 100);
    final double steadiness = (100 - mistakes * 7).clamp(40, 100).toDouble();
    return (paceScore * 0.5 + steadiness * 0.5).clamp(0, 100);
  }

  /// Memory falls with hint usage.
  double memory() => (100 - hints * 12 - mistakes * 5).clamp(35, 100).toDouble();

  /// Mean seconds per response over the whole session.
  ///
  /// Derived from the session clock rather than timed per tap: an average pace
  /// is what these activities can honestly report, and the profile and the
  /// report both label it that way rather than calling it a reaction time.
  int get responseMillis =>
      attempts == 0 ? 0 : ((seconds / attempts) * 1000).round();

  GamePerformance build({required int expectedSeconds, bool completed = true}) {
    return GamePerformance(
      accuracy: accuracy,
      focus: focus(expectedSeconds),
      memory: memory(),
      hintsUsed: hints,
      mistakes: mistakes,
      seconds: seconds,
      completed: completed,
      attempts: attempts,
      correct: correct,
      responseMillis: responseMillis,
    );
  }
}

/// Shared chrome for all six activities: a calm header, a level indicator, a
/// progress line and an optional hint budget. Nothing else competes with the
/// activity itself.
class GameShell extends StatelessWidget {
  const GameShell({
    super.key,
    required this.game,
    required this.level,
    required this.child,
    this.stepLabel,
    this.progress,
    this.hintsLeft,
    this.hintsTotal,
    this.onHint,
    this.bottom,
    this.companionMessage,
    this.companionState = CompanionState.encouraging,
    this.scrollable = true,
  });

  final GameDefinition game;
  final int level;
  final Widget child;
  final String? stepLabel;
  final double? progress;
  final int? hintsLeft;
  final int? hintsTotal;
  final VoidCallback? onHint;
  final Widget? bottom;
  final String? companionMessage;
  final CompanionState companionState;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (companionMessage != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, 0),
            child: CompanionSpeech(
              message: companionMessage!,
              state: companionState,
              companionSize: 70,
              compact: true,
            ),
          ),
          const SizedBox(height: Insets.md),
        ],
        child,
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.04,
        color: game.accent,
        washColors: <Color>[
          game.tint.withValues(alpha: 0.95),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _Header(
                game: game,
                level: level,
                stepLabel: stepLabel,
                hintsLeft: hintsLeft,
                hintsTotal: hintsTotal,
                onHint: onHint,
              ),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, Insets.md),
                  child: MeterBar(value: progress!, color: game.accent, height: 8),
                )
              else
                const SizedBox(height: Insets.sm),
              Expanded(
                child: scrollable
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: body,
                      )
                    : body,
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 12),
                  child: bottom!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.game,
    required this.level,
    required this.stepLabel,
    required this.hintsLeft,
    required this.hintsTotal,
    required this.onHint,
  });

  final GameDefinition game;
  final int level;
  final String? stepLabel;
  final int? hintsLeft;
  final int? hintsTotal;
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 6, Insets.gutter, 6),
      child: Row(
        children: <Widget>[
          RoundIconButton(
            icon: Icons.close_rounded,
            size: 44,
            tooltip: l.gamesLeaveActivity,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  game.localizedName(l),
                  style: AppText.h3.wght(800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Text(l.gamesLevel(level),
                        style: AppText.caption.wght(700).tint(game.accent)),
                    const SizedBox(width: 7),
                    DifficultyDots(level: level, color: game.accent, size: 7),
                    if (stepLabel != null) ...<Widget>[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text('· $stepLabel',
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hintsTotal != null && hintsTotal! > 0) ...<Widget>[
            const SizedBox(width: 8),
            Pressable(
              onTap: (hintsLeft ?? 0) > 0 ? onHint : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (hintsLeft ?? 0) > 0
                      ? AppColors.accent.withValues(alpha: 0.14)
                      : AppColors.surfaceMuted,
                  borderRadius: Corners.r(Corners.pill),
                  border: Border.all(
                    color: (hintsLeft ?? 0) > 0
                        ? AppColors.accent.withValues(alpha: 0.35)
                        : AppColors.hairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: (hintsLeft ?? 0) > 0 ? AppColors.accent : AppColors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$hintsLeft',
                      style: AppText.body.wght(800).tint(
                            (hintsLeft ?? 0) > 0 ? AppColors.accent : AppColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The soft feedback strip games show after each answer.
class FeedbackBubble extends StatelessWidget {
  const FeedbackBubble({
    super.key,
    required this.message,
    required this.positive,
    this.icon,
  });

  final String message;
  final bool positive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color color = positive ? AppColors.success : AppColors.secondary;
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(message),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.normal,
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) => Transform.scale(
        scale: 0.94 + t * 0.06,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: Corners.r(Corners.md),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon ?? (positive ? Icons.check_circle_rounded : Icons.info_rounded),
              color: color,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: AppText.bodyLarge.wght(600).tint(AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
