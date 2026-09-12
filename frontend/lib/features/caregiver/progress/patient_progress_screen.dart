import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../widgets/caregiver_top_bar.dart';

/// Detailed cognitive domain breakdown — the Patient Progress tab.
///
/// Shows each domain (Memory, Attention, Sequencing, Reasoning, Spatial,
/// Auditory) with current vs baseline, plain-language trend, a time-range
/// switcher for the performance chart, and a session history table.
class PatientProgressScreen extends StatefulWidget {
  const PatientProgressScreen({super.key});

  @override
  State<PatientProgressScreen> createState() => _PatientProgressScreenState();
}

class _PatientProgressScreenState extends State<PatientProgressScreen> {
  /// 0 = 7 days · 1 = 30 days · 2 = 3 months
  int _rangeIndex = 0;

  static const List<String> _rangeLabels = <String>['7 Days', '30 Days', '3 Months'];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.6),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            CaregiverTopBar(
              title: 'Patient Progress',
              subtitle: '${state.patient.shortName} — cognitive overview',
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  // ── Summary hero ─────────────────────────────────────────
                  FadeInUp(
                    child: MmCard(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFFE3F0EA), Color(0xFFF5EFE6)],
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Overall engagement',
                                    style: AppText.label),
                                const SizedBox(height: 6),
                                Text('${state.todayEngagement}%',
                                    style: AppText.statLarge
                                        .tint(AppColors.primary)),
                                const SizedBox(height: 4),
                                Text('Stable this week',
                                    style: AppText.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Average accuracy',
                                    style: AppText.label),
                                const SizedBox(height: 6),
                                Text(
                                    '${state.averageAccuracy().round()}%',
                                    style: AppText.statLarge
                                        .tint(AppColors.seriesOchre)),
                                const SizedBox(height: 4),
                                Text(
                                    '${state.gamesCompletedTotal()} sessions total',
                                    style: AppText.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Domain cards ─────────────────────────────────────────
                  FadeInUp(
                    delayMs: 50,
                    child: SectionHeader(
                      title: 'Cognitive Domains',
                      icon: Icons.psychology_rounded,
                      subtitle: 'How each area is trending against her baseline',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 70,
                    child: _DomainGrid(snapshot: snapshot),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Performance chart ────────────────────────────────────
                  FadeInUp(
                    delayMs: 120,
                    child: SectionHeader(
                      title: 'Engagement over time',
                      icon: Icons.show_chart_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 140,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Time-range chip row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List<Widget>.generate(
                                _rangeLabels.length,
                                (int i) => Padding(
                                  padding: EdgeInsets.only(
                                      right: i < _rangeLabels.length - 1 ? 8 : 0),
                                  child: _RangeChip(
                                    label: _rangeLabels[i],
                                    selected: _rangeIndex == i,
                                    onTap: () => setState(() => _rangeIndex = i),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          TrendLineChart(
                            points: _rangePoints(state),
                            color: AppColors.seriesTeal,
                            valueSuffix: '%',
                            minValue: 40,
                            height: 170,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _rangeLabels[_rangeIndex] == '7 Days'
                                ? 'Daily engagement — last 7 days'
                                : _rangeLabels[_rangeIndex] == '30 Days'
                                    ? 'Weekly average — last 30 days'
                                    : 'Monthly average — last 3 months',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Activity table ───────────────────────────────────────
                  FadeInUp(
                    delayMs: 180,
                    child: SectionHeader(
                      title: 'Activity Performance',
                      icon: Icons.table_rows_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 200,
                    child: MmCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: <Widget>[
                          _TableHeader(),
                          const Divider(
                              color: AppColors.hairline, height: 1),
                          for (int i = 0; i < MockData.games.length; i++)
                            _GameRow(
                              game: MockData.games[i],
                              state: state,
                              last: i == MockData.games.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── AI insight ───────────────────────────────────────────
                  FadeInUp(
                    delayMs: 230,
                    child: AiInsightBanner(
                      insight:
                          'Over the past 7 days, ${state.patient.shortName} has shown stable engagement '
                          'overall. Sequencing (Procedure Reconstruction) required more hints than '
                          'usual on 3 out of 4 sessions. Auditory memory (Melody) showed a '
                          'consistent upward trend.',
                      color: AppColors.primary,
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

  List<SeriesPoint> _rangePoints(AppState state) {
    switch (_rangeIndex) {
      case 0:
        return state.engagementWeek;
      case 1:
        // Simulate 30-day data: repeat weekly pattern ~4x with slight variation
        final List<SeriesPoint> base = state.engagementWeek;
        return <SeriesPoint>[
          for (int i = 0; i < base.length; i++)
            SeriesPoint(base[i].label, base[i].value * (0.92 + i * 0.011)),
          ...base,
          for (int i = 0; i < base.length; i++)
            SeriesPoint(base[i].label, base[i].value * (0.96 + i * 0.008)),
          ...base,
        ];
      default:
        // 3-month: month labels
        return <SeriesPoint>[
          const SeriesPoint('Jul', 68),
          const SeriesPoint('Aug', 73),
          const SeriesPoint('Sep', 78),
        ];
    }
  }
}

// ── Domain grid ──────────────────────────────────────────────────────────────

class _DomainGrid extends StatelessWidget {
  const _DomainGrid({required this.snapshot});
  final MonitoringSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    // Map CognitiveDomain to caregiver-friendly display info
    const List<_DomainSpec> domains = <_DomainSpec>[
      _DomainSpec(
          domain: CognitiveDomain.memory,
          label: 'Memory',
          current: 79,
          previous: 76,
          direction: 1),
      _DomainSpec(
          domain: CognitiveDomain.attention,
          label: 'Attention',
          current: 74,
          previous: 74,
          direction: 0),
      _DomainSpec(
          domain: CognitiveDomain.procedural,
          label: 'Sequencing',
          current: 68,
          previous: 74,
          direction: -1),
      _DomainSpec(
          domain: CognitiveDomain.reasoning,
          label: 'Reasoning',
          current: 81,
          previous: 78,
          direction: 1),
      _DomainSpec(
          domain: CognitiveDomain.spatial,
          label: 'Spatial',
          current: 75,
          previous: 71,
          direction: 1),
      _DomainSpec(
          domain: CognitiveDomain.auditory,
          label: 'Auditory',
          current: 82,
          previous: 79,
          direction: 1),
    ];

    return Column(
      children: <Widget>[
        for (int i = 0; i < domains.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: <Widget>[
                Expanded(child: _DomainCard(spec: domains[i])),
                const SizedBox(width: 12),
                Expanded(
                    child: i + 1 < domains.length
                        ? _DomainCard(spec: domains[i + 1])
                        : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

@immutable
class _DomainSpec {
  const _DomainSpec({
    required this.domain,
    required this.label,
    required this.current,
    required this.previous,
    required this.direction,
  });
  final CognitiveDomain domain;
  final String label;
  final int current;
  final int previous;
  final int direction; // 1 / 0 / -1
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.spec});
  final _DomainSpec spec;

  @override
  Widget build(BuildContext context) {
    final Color accent = spec.direction > 0
        ? AppColors.success
        : spec.direction < 0
            ? AppColors.warning
            : AppColors.secondary;
    return MmCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: spec.domain.icon, color: accent, size: 30),
              const SizedBox(width: 6),
              Expanded(
                child: Text(spec.label,
                    style: AppText.body.wght(700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${spec.current}%',
              style: AppText.stat.tint(accent)),
          const SizedBox(height: 2),
          Text('Prev: ${spec.previous}%', style: AppText.caption),
          const SizedBox(height: 8),
          TrendBadge(direction: spec.direction, dense: true),
        ],
      ),
    );
  }
}

// ── Table ────────────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: AppColors.surfaceMuted,
      child: Row(
        children: <Widget>[
          Expanded(
              flex: 3,
              child:
                  Text('Activity', style: AppText.overline)),
          Expanded(
              flex: 2,
              child:
                  Text('Domain', style: AppText.overline)),
          SizedBox(
              width: 48,
              child: Text('Acc.', style: AppText.overline,
                  textAlign: TextAlign.end)),
          SizedBox(
              width: 36,
              child: Text('Trend', style: AppText.overline,
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow(
      {required this.game, required this.state, required this.last});
  final GameDefinition game;
  final AppState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final List<GameSession> sessions = state.sessionsFor(game.id);
    final double avg = sessions.isEmpty
        ? 0
        : sessions.fold<double>(
                0, (double a, GameSession s) => a + s.performance.overall) /
            sessions.length;
    final int direction = avg > 75
        ? 1
        : avg < 65
            ? -1
            : 0;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(game.name,
                style: AppText.bodySmall.wght(600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: PillTag(
              label: game.domain?.label ?? '',
              color: game.accent,
              dense: true,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              sessions.isEmpty ? '—' : '${avg.round()}%',
              style: AppText.body
                  .wght(700)
                  .tint(game.accent),
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: 36,
            child: Center(
              child: Icon(
                direction > 0
                    ? Icons.trending_up_rounded
                    : direction < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                size: 18,
                color: direction > 0
                    ? AppColors.success
                    : direction < 0
                        ? AppColors.warning
                        : AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Range chip ───────────────────────────────────────────────────────────────

class _RangeChip extends StatelessWidget {
  const _RangeChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.normal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: Corners.r(Corners.pill),
        ),
        child: Text(
          label,
          style: AppText.label
              .wght(700)
              .tint(selected ? Colors.white : AppColors.primary),
        ),
      ),
    );
  }
}
