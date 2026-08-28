import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../widgets/caregiver_top_bar.dart';

/// Caregiver analytics — the week at a glance, then activity by activity.
class CaregiverActivityScreen extends StatelessWidget {
  const CaregiverActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    final List<SeriesPoint> perGame = <SeriesPoint>[
      for (final GameDefinition g in MockData.games)
        SeriesPoint(_shortName(g.name), _averageFor(state, g.id)),
    ];

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.secondaryTint.withValues(alpha: 0.7),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const CaregiverTopBar(title: 'Activity', subtitle: 'Aama Devi · last 7 days'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  // ── Summary tiles ─────────────────────────────────────
                  FadeInUp(
                    child: MmCard(
                      shadow: AppColors.liftShadow(),
                      child: Column(
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: StatTile(
                                  label: 'Cognitive engagement',
                                  value: '${state.todayEngagement}',
                                  suffix: '%',
                                  meter: state.todayEngagement / 100,
                                  color: AppColors.seriesTeal,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: StatTile(
                                  label: 'Average accuracy',
                                  value: state.averageAccuracy().round().toString(),
                                  suffix: '%',
                                  meter: state.averageAccuracy() / 100,
                                  color: AppColors.seriesOchre,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.lg),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: StatTile(
                                  label: 'Activities completed',
                                  value: '${state.gamesCompletedTotal()}',
                                  color: AppColors.seriesBlue,
                                  compact: true,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: StatTile(
                                  label: 'Reminder adherence',
                                  value: '${state.adherencePercent}',
                                  suffix: '%',
                                  meter: state.adherencePercent / 100,
                                  color: AppColors.seriesClay,
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Weekly engagement ─────────────────────────────────
                  FadeInUp(
                    delayMs: 50,
                    child: _ChartCard(
                      title: 'Daily cognitive engagement',
                      caption: 'Share of the day\'s planned activity she took part in.',
                      child: TrendLineChart(
                        points: state.engagementWeek,
                        color: AppColors.seriesTeal,
                        valueSuffix: '%',
                        minValue: 40,
                        height: 170,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Weekly activity strip ─────────────────────────────
                  FadeInUp(
                    delayMs: 80,
                    child: _ChartCard(
                      title: 'Activities completed each day',
                      caption: 'Out of four planned activities per day.',
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: WeekStrip(
                          days: <SeriesPoint>[
                            for (final SeriesPoint p in state.gamesWeek)
                              SeriesPoint(p.label, (p.value / 4).clamp(0, 1)),
                          ],
                          color: AppColors.seriesBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Performance by activity ───────────────────────────
                  FadeInUp(
                    delayMs: 110,
                    child: _ChartCard(
                      title: 'Average score by activity',
                      caption: 'Where she is strongest, and where she needs support.',
                      child: BarSeriesChart(
                        points: perGame,
                        color: AppColors.seriesTeal,
                        height: 170,
                        showValues: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Memory activity & adherence ───────────────────────
                  FadeInUp(
                    delayMs: 140,
                    child: _ChartCard(
                      title: 'Memory activity',
                      caption: 'Questions she remembered and answered each day.',
                      child: BarSeriesChart(
                        points: state.memoryActivityWeek,
                        color: AppColors.seriesPlum,
                        maxValue: 6,
                        height: 150,
                        showValues: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  FadeInUp(
                    delayMs: 170,
                    child: _ChartCard(
                      title: 'Reminder adherence',
                      caption: 'Medicine, hydration and routine reminders marked done.',
                      child: TrendLineChart(
                        points: state.adherenceWeek,
                        color: AppColors.seriesClay,
                        valueSuffix: '%',
                        minValue: 50,
                        height: 150,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Difficulty per activity ───────────────────────────
                  FadeInUp(
                    delayMs: 200,
                    child: SectionHeader(
                      title: 'Adaptive difficulty',
                      icon: Icons.tune_rounded,
                      subtitle: 'Set automatically from her recent performance',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 210,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < MockData.games.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == MockData.games.length - 1 ? 0 : 16),
                              child: Row(
                                children: <Widget>[
                                  SceneImage(
                                    sceneId: MockData.games[i].sceneId,
                                    size: 42,
                                    radius: Corners.sm,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(MockData.games[i].name,
                                            style: AppText.body.wght(700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 3),
                                        Text(
                                          AdaptiveDifficultyService.levelDescription(
                                            MockData.games[i].id,
                                            state.levelOf(MockData.games[i].id),
                                          ),
                                          style: AppText.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Text('Level ${state.levelOf(MockData.games[i].id)}',
                                          style: AppText.caption.wght(800)),
                                      const SizedBox(height: 5),
                                      DifficultyDots(
                                        level: state.levelOf(MockData.games[i].id),
                                        color: MockData.games[i].accent,
                                        size: 7,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Session history ───────────────────────────────────
                  FadeInUp(
                    delayMs: 240,
                    child: SectionHeader(
                      title: 'Recent sessions',
                      icon: Icons.history_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 250,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < state.sessions.take(10).length; i++)
                            _HistoryRow(
                              session: state.sessions[i],
                              last: i == state.sessions.take(10).length - 1,
                            ),
                        ],
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

  static String _shortName(String name) => switch (name) {
        'Procedure Reconstruction' => 'Procedure',
        'Finish the Story' => 'Story',
        'Familiar Place Explorer' => 'Place',
        'Melody of the Valleys' => 'Melody',
        'Weaves of the Hills' => 'Weaves',
        'NER Memory Cards' => 'Cards',
        _ => name,
      };

  static double _averageFor(AppState state, GameId id) {
    final List<GameSession> list = state.sessionsFor(id);
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (double a, GameSession s) => a + s.performance.overall) /
        list.length;
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.caption, required this.child});
  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppText.h3),
          const SizedBox(height: 3),
          Text(caption, style: AppText.caption),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session, required this.last});
  final GameSession session;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final GameDefinition g = MockData.game(session.gameId);
    final String when = session.dayOffset == 0
        ? 'Today'
        : session.dayOffset == 1
            ? 'Yesterday'
            : '${session.dayOffset} days ago';
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: g.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(g.name,
                    style: AppText.body.wght(700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '$when · ${session.timeLabel} · Level ${session.level} · '
                  '${session.performance.hintsUsed} hint${session.performance.hintsUsed == 1 ? '' : 's'}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${session.performance.overall}%',
              style: AppText.body.wght(800).tint(g.accent)),
        ],
      ),
    );
  }
}
