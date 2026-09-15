import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../widgets/clinic_widgets.dart';

/// Cohort-level analytics across the clinic's caseload.
class DoctorAnalyticsScreen extends StatelessWidget {
  const DoctorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ClinicPatient> caseload = state.caseload;
    if (caseload.isEmpty) unawaited(state.loadCaseload());

    // Domain averages across the cohort — a real caseload can genuinely be
    // empty (nobody connected yet), unlike the old fixed 8-patient mock.
    final Map<String, int> domainAverages = <String, int>{
      for (final CognitiveDomain d in CognitiveDomain.values)
        d.localizedLabel(l): caseload.isEmpty
            ? 0
            : (caseload.fold<int>(0, (int a, ClinicPatient c) => a + c.profile.score(d)) /
                    caseload.length)
                .round(),
    };

    // Score distribution in bands.
    final List<SeriesPoint> distribution = <SeriesPoint>[
      SeriesPoint('<50', _countIn(caseload, 0, 50).toDouble()),
      SeriesPoint('50–59', _countIn(caseload, 50, 60).toDouble()),
      SeriesPoint('60–69', _countIn(caseload, 60, 70).toDouble()),
      SeriesPoint('70–79', _countIn(caseload, 70, 80).toDouble()),
      SeriesPoint('80+', _countIn(caseload, 80, 200).toDouble()),
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          ClinicTopBar(
            title: l.doctorTabAnalytics,
            subtitle: l.doctorAnalyticsSubtitle,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
              children: <Widget>[
                FadeInUp(
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: ClinicStat(
                            label: l.doctorAnalyticsMeanScoreLabel,
                            value: '${_mean(caseload)}',
                            caption: l.doctorAnalyticsAcrossCaseload,
                            color: AppColors.seriesTeal,
                          ),
                        ),
                        Expanded(
                          child: ClinicStat(
                            label: l.doctorAnalyticsMeanAdherenceLabel,
                            value: '${_meanAdherence(caseload)}%',
                            caption: l.doctorAnalyticsRemindersCompleted,
                            color: AppColors.seriesBlue,
                          ),
                        ),
                        Expanded(
                          child: ClinicStat(
                            label: l.doctorPatientsLegendDeclining,
                            value: '${caseload.where((ClinicPatient c) => c.trend == TrendDirection.down).length}',
                            caption: l.doctorAnalyticsPatientsTrendingDown,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                FadeInUp(
                  delayMs: 50,
                  child: _Card(
                    title: l.doctorAnalyticsScoreDistTitle,
                    caption: l.doctorAnalyticsScoreDistCaption,
                    child: BarSeriesChart(
                      points: distribution,
                      color: AppColors.seriesTeal,
                      maxValue: distribution
                              .map((SeriesPoint p) => p.value)
                              .reduce((double a, double b) => a > b ? a : b) +
                          1,
                      showValues: true,
                      height: 170,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                FadeInUp(
                  delayMs: 80,
                  child: _Card(
                    title: l.doctorAnalyticsDomainTitle,
                    caption: l.doctorAnalyticsDomainCaption,
                    child: Center(
                      child: RadarChart(
                        values: domainAverages,
                        size: 280,
                        color: AppColors.seriesBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                FadeInUp(
                  delayMs: 110,
                  child: _Card(
                    title: l.doctorAnalyticsEngagementTitle,
                    caption: l.doctorAnalyticsEngagementCaption,
                    child: BarSeriesChart(
                      points: <SeriesPoint>[
                        // Engagement (how often/how long), not a score — this
                        // one honestly applies to Mood Canvas too.
                        for (int i = 0; i < MockData.games.length; i++)
                          SeriesPoint(
                            doctorChartLabel(l, MockData.games[i].id),
                            const <double>[24, 17, 14, 19, 15, 11, 13, 9][i],
                          ),
                      ],
                      color: AppColors.seriesOchre,
                      maxValue: 30,
                      showValues: true,
                      height: 170,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                FadeInUp(
                  delayMs: 140,
                  child: _Card(
                    title: l.doctorAnalyticsSessionsTitle,
                    caption: l.doctorAnalyticsSessionsCaption,
                    child: TrendLineChart(
                      points: MockData.series(
                        const <double>[142, 151, 149, 163, 158, 174, 186],
                        labels: <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'],
                      ),
                      color: AppColors.seriesPlum,
                      minValue: 120,
                      maxValue: 200,
                      height: 170,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                FadeInUp(
                  delayMs: 170,
                  child: _Card(
                    title: l.doctorAnalyticsDistrictTitle,
                    caption: l.doctorAnalyticsDistrictCaption,
                    child: Column(
                      children: <Widget>[
                        for (final ({String label, int value, Color color}) row
                            in <({String label, int value, Color color})>[
                          (label: l.doctorAnalyticsDistrictAssam, value: 11, color: AppColors.seriesTeal),
                          (label: l.doctorAnalyticsDistrictManipur, value: 4, color: AppColors.seriesOchre),
                          (label: l.doctorAnalyticsDistrictMeghalaya, value: 3, color: AppColors.seriesBlue),
                          (label: l.doctorAnalyticsDistrictNagaland, value: 3, color: AppColors.seriesClay),
                          (label: l.doctorAnalyticsDistrictMizoram, value: 2, color: AppColors.seriesPlum),
                          (label: l.doctorAnalyticsDistrictTripura, value: 1, color: AppColors.seriesLeaf),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 84,
                                  child: Text(row.label, style: CT.bodySmall),
                                ),
                                Expanded(
                                  child: MeterBar(
                                    value: row.value / 12,
                                    color: row.color,
                                    height: 9,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 22,
                                  child: Text('${row.value}',
                                      textAlign: TextAlign.right,
                                      style: CT.body.wght(800)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Medication Adherence by Patient ────────────────────
                FadeInUp(
                  delayMs: 190,
                  child: _Card(
                    title: l.doctorAnalyticsAdherenceTitle,
                    caption: l.doctorAnalyticsAdherenceCaption,
                    child: Column(
                      children: <Widget>[
                        for (final ClinicPatient p in caseload.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    p.name,
                                    style: CT.bodySmall.wght(600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  child: MeterBar(
                                    value: p.adherence / 100.0,
                                    color: p.adherence >= 90
                                        ? AppColors.success
                                        : p.adherence >= 75
                                            ? const Color(0xFF2F7FB8)
                                            : const Color(0xFFD9962B),
                                    height: 9,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    '${p.adherence}%',
                                    textAlign: TextAlign.right,
                                    style: CT.caption.wght(700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Wellness Activity Participation ────────────────────
                FadeInUp(
                  delayMs: 210,
                  child: _Card(
                    title: l.doctorAnalyticsWellnessTitle,
                    caption: l.doctorAnalyticsWellnessCaption,
                    child: BarSeriesChart(
                      points: const <SeriesPoint>[
                        SeriesPoint('Breathing', 42),
                        SeriesPoint('Chair Yoga', 35),
                        SeriesPoint('Sounds', 28),
                        SeriesPoint('Sleep Guide', 21),
                      ],
                      color: AppColors.seriesTeal,
                      maxValue: 50,
                      showValues: true,
                      height: 160,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Mood & Wellbeing Distribution ──────────────────────
                FadeInUp(
                  delayMs: 230,
                  child: _Card(
                    title: l.doctorAnalyticsMoodTitle,
                    caption: l.doctorAnalyticsMoodCaption,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: ClinicStat(
                            label: l.doctorAnalyticsMoodHappy,
                            value: '64%',
                            color: AppColors.success,
                            caption: 'Calm & Cheerful',
                            icon: Icons.sentiment_satisfied_alt_rounded,
                          ),
                        ),
                        Expanded(
                          child: ClinicStat(
                            label: l.doctorAnalyticsMoodNeutral,
                            value: '24%',
                            color: const Color(0xFF2F7FB8),
                            caption: 'Steady',
                            icon: Icons.sentiment_neutral_rounded,
                          ),
                        ),
                        Expanded(
                          child: ClinicStat(
                            label: l.doctorAnalyticsMoodAnxious,
                            value: '12%',
                            color: const Color(0xFFE0913A),
                            caption: 'Evening pauses',
                            icon: Icons.sentiment_dissatisfied_rounded,
                          ),
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
    );
  }

  static int _countIn(List<ClinicPatient> list, int lo, int hi) =>
      list.where((ClinicPatient c) => c.score >= lo && c.score < hi).length;

  static int _mean(List<ClinicPatient> list) => list.isEmpty
      ? 0
      : (list.fold<int>(0, (int a, ClinicPatient c) => a + c.score) / list.length).round();

  static int _meanAdherence(List<ClinicPatient> list) => list.isEmpty
      ? 0
      : (list.fold<int>(0, (int a, ClinicPatient c) => a + c.adherence) / list.length).round();
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.caption, required this.child});
  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: CT.h3),
          const SizedBox(height: 3),
          Text(caption, style: CT.caption),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}
