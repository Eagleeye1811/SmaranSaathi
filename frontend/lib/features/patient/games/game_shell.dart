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

  /// Null for an activity with no difficulty levels — see
  /// [GameDefinition.hasLevels]. The header simply omits the "Level N · dots"
  /// segment rather than show a fake level for it.
  final int? level;
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
  final int? level;
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
                    if (level != null) ...<Widget>[
                      Text(l.gamesLevel(level!),
                          style: AppText.caption.wght(700).tint(game.accent)),
                      const SizedBox(width: 7),
                      DifficultyDots(level: level!, color: game.accent, size: 7),
                    ],
                    if (stepLabel != null) ...<Widget>[
                      if (level != null) const SizedBox(width: 10),
                      Flexible(
                        child: Text(level != null ? '· $stepLabel' : stepLabel!,
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

/// The level picker each activity's intro screen shows — one chip per level,
/// "Level N" over a short title over a short subtitle, locked levels dimmed
/// with a lock icon.
///
/// Was duplicated near-identically at the bottom of all seven game files;
/// hoisted here so the "Level N" row can't silently overflow its chip width
/// in one game without the fix reaching the other six. The "Level N" +
/// lock-icon row is wrapped in [Flexible] with ellipsis specifically because
/// a bare `Text` in a `Row` ignores its own `overflow`/`maxLines` unless
/// something gives it a bounded width — that gap was the actual cause of a
/// real (if rare) render overflow on narrower chips.
class LevelOptionChip extends StatelessWidget {
  const LevelOptionChip({
    super.key,
    required this.levelNum,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.primary,
    this.icon,
  });

  final int levelNum;
  final String title;
  final String subtitle;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  /// A small glyph for what this level actually is — a teacup, a basket of
  /// laundry — shown beside the numeral once unlocked. Optional: a game
  /// that has nothing sensible to show per level just omits it and keeps
  /// the plain numeral badge.
  final IconData? icon;

  /// The game's own accent colour. Every chip used to render its selected
  /// state in the same hardcoded blue regardless of which game it belonged
  /// to — the one place in the whole level-picker where a game's identity
  /// *wasn't* visible. Defaults to [AppColors.primary] only so a caller that
  /// genuinely has no game colour (there is none today) still compiles.
  final Color accent;

  /// Reserves the same vertical space for a line of text regardless of
  /// whether *this* chip's own title happens to need one line or two — a
  /// short title ("Making tea") otherwise left its chip visibly shorter
  /// than a neighbour whose title wrapped ("Washing clothes"), since each
  /// chip's `Column` naturally only grows as tall as its own content
  /// needs. Scaled through the active text scaler, not a raw pixel
  /// constant, so it still reserves the right amount of room at a larger
  /// accessibility text size instead of clipping a wrapped line.
  static double _twoLineHeight(BuildContext context, double fontSize) =>
      MediaQuery.textScalerOf(context).scale(fontSize) * 1.35 * 2;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool lit = unlocked && selected;
    // On-white text for the plain states, on-accent (white) once the chip is
    // filled with the game's own colour — the single switch every text and
    // icon colour below reads off, so "selected" always stays legible
    // whichever game's accent it happens to be.
    final Color ink = lit
        ? Colors.white
        : unlocked
            ? AppColors.ink
            : AppColors.inkMuted.withValues(alpha: 0.5);
    final Color inkSoft = lit
        ? Colors.white.withValues(alpha: 0.85)
        : unlocked
            ? AppColors.inkMuted
            : AppColors.inkMuted.withValues(alpha: 0.5);

    return Semantics(
      button: true,
      selected: selected,
      // The spoken label keeps saying "Level N" even though the chip itself
      // now shows that as a numeral in a coloured badge rather than as a
      // words — the simplification is visual, not a loss of information.
      label: '${l.gamesLevel(levelNum)}. $title'
          '${unlocked ? '' : '. ${l.gameLevelLocked}'}',
      child: Pressable(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: lit ? 1 : 0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double t, Widget? child) => Transform.scale(
            scale: 1 + t * 0.035,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              // A filled gradient card for the selected, unlocked level —
              // every other state stays a flat, quiet surface, so the one
              // level actually in play is the one thing that looks lit up.
              gradient: lit
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[accent, Color.lerp(accent, Colors.black, 0.18)!],
                    )
                  : null,
              color: lit
                  ? null
                  : unlocked
                      ? AppColors.surfaceMuted
                      : AppColors.surfaceMuted.withValues(alpha: 0.4),
              borderRadius: Corners.r(Corners.lg),
              border: lit
                  ? null
                  : Border.all(
                      color: unlocked
                          ? AppColors.hairline
                          : AppColors.hairline.withValues(alpha: 0.4),
                    ),
              boxShadow: lit
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.38),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // A coloured numeral badge in place of the old plain "Level N"
                // text row — the single biggest lever for making this chip
                // read as designed rather than a stack of shrinking captions.
                // The optional `icon` rides along as a small second badge at
                // its corner — what the level actually is, not just its
                // number — the same way a completed-step checkmark would.
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lit
                              ? Colors.white.withValues(alpha: 0.22)
                              : unlocked
                                  ? accent
                                  : AppColors.inkMuted.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: lit ? Border.all(color: Colors.white, width: 1.6) : null,
                        ),
                        child: unlocked
                            ? Text(
                                '$levelNum',
                                style: AppText.h3.wght(800).tint(Colors.white),
                              )
                            : const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                      ),
                      if (icon != null && unlocked)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: lit ? Colors.white : accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: lit ? accent : accent.withValues(alpha: 0.3),
                                width: 1.4,
                              ),
                            ),
                            child: Icon(icon, size: 12, color: lit ? accent : accent),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: _twoLineHeight(context, 12),
                  child: Text(
                    title,
                    style: AppText.caption.sized(12).wght(700).tint(ink),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: _twoLineHeight(context, 10),
                  child: Text(
                    unlocked ? subtitle : l.gameLevelLocked,
                    style: AppText.caption.sized(10).tint(inkSoft),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
