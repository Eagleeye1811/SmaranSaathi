import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/personalization_service.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../widgets/patient_widgets.dart';
import 'game_launcher.dart';
import '../../../l10n/app_localizations.dart';

/// The activity hub. Ordered by the personalisation engine, so the thing that
/// matters most to this particular person is always first.
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    final Recommendation rec = state.todaysRecommendation;
    final List<GameId> order = AppState.personalization.priorityOrder(state.patient);
    final int doneToday = state.completedToday.length;

    return MotifBackground(
      opacity: 0.045,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.8),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const PatientTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  FadeInUp(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Today\'s Cognitive Journey', style: AppText.patientTitle.sized(28)),
                        const SizedBox(height: 6),
                        Text(
                          l.gamesIntro,
                          style: AppText.body.tint(AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  FadeInUp(
                    delayMs: 50,
                    child: MmCard(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        children: <Widget>[
                          ProgressRing(
                            value: doneToday / 6,
                            size: 60,
                            stroke: 7,
                            color: AppColors.primary,
                            center: Text('$doneToday/6', style: AppText.body.wght(800)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  doneToday == 0
                                      ? l.gamesNothingDoneYet
                                      : doneToday >= 4
                                          ? l.gamesVeryGoodDay
                                          : l.gamesGoodStart,
                                  style: AppText.body.wght(800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l.gamesDifficultyNote,
                                  style: AppText.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  for (int i = 0; i < order.length; i++)
                    FadeInUp(
                      delayMs: 70 + i * 45,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _GameCard(
                          game: MockData.game(order[i]),
                          level: state.levelOf(order[i]),
                          completed: state.completedToday.contains(order[i]),
                          recommended: order[i] == rec.gameId,
                          lastAccuracy: state.sessionsFor(order[i]).isEmpty
                              ? null
                              : state
                                  .sessionsFor(order[i])
                                  .first
                                  .performance
                                  .accuracy
                                  .round(),
                          onPlay: () => GameLauncher.open(context, order[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.level,
    required this.completed,
    required this.recommended,
    required this.onPlay,
    this.lastAccuracy,
  });

  final GameDefinition game;
  final int level;
  final bool completed;
  final bool recommended;
  final VoidCallback onPlay;
  final int? lastAccuracy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: EdgeInsets.zero,
      clip: true,
      onTap: onPlay,
      shadow: recommended ? AppColors.liftShadow() : AppColors.softShadow(),
      border: Border.all(
        color: recommended ? game.accent.withValues(alpha: 0.45) : AppColors.hairline,
        width: recommended ? 2 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (recommended)
            Container(
              width: double.infinity,
              color: game.accent,
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 7),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(l.gamesChosenForYou,
                      style: AppText.overline.sized(10.5).tint(Colors.white)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: Corners.r(Corners.md),
                        boxShadow: AppColors.softShadow(y: 3, blur: 10),
                      ),
                      child: SceneImage(sceneId: game.sceneId, size: 90, radius: Corners.md),
                    ),
                    if (completed)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(game.name, style: AppText.h3.wght(800)),
                      const SizedBox(height: 4),
                      Text(game.tagline, style: AppText.bodySmall, maxLines: 2),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          PillTag(
                            label: game.domain.label,
                            icon: game.domain.icon,
                            color: game.accent,
                            dense: true,
                          ),
                          PillTag(
                            label: '${game.estimatedMinutes} min',
                            icon: Icons.schedule_rounded,
                            color: AppColors.inkSoft,
                            dense: true,
                          ),
                          if (completed)
                            PillTag(
                              label: l.gamesDoneToday,
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.md, 12, Insets.md, Insets.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text('Level $level',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.wght(700)),
                          ),
                          const SizedBox(width: 8),
                          DifficultyDots(level: level, color: game.accent, size: 7),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AdaptiveDifficultyService.levelDescription(game.id, level),
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lastAccuracy != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text('Last time · $lastAccuracy% accuracy', style: AppText.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SoftButton(
                  label: completed ? l.actionPlayAgain : 'Play',
                  icon: Icons.play_arrow_rounded,
                  color: game.accent,
                  filled: !completed,
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
