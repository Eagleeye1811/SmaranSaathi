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
import '../widgets/clinic_widgets.dart';

/// Cohort-level analytics across the clinic's caseload.
class DoctorAnalyticsScreen extends StatelessWidget {
  const DoctorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<ClinicPatient> caseload = state.caseload;

    // Domain averages across the cohort.
    final Map<String, int> domainAverages = <String, int>{
      for (final CognitiveDomain d in CognitiveDomain.values)
        d.label: (caseload.fold<int>(0, (int a, ClinicPatient c) => a + c.profile.score(d)) /
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
          const ClinicTopBar(
            title: 'Analytics',
            subtitle: 'Cohort view · last 30 days',
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
                            label: 'Mean score',
                            value: '${_mean(caseload)}',
                            caption: 'Across the caseload',
                            color: AppColors.seriesTeal,
                          ),
                        ),
                        Expanded(
                          child: ClinicStat(
                            label: 'Mean adherence',
                            value: '${_meanAdherence(caseload)}%',
                            caption: 'Reminders completed',
                            color: AppColors.seriesBlue,
                          ),
                        ),
                        Expanded(
                          child: ClinicStat(
                            label: 'Declining',
                            value: '${caseload.where((ClinicPatient c) => c.trend == TrendDirection.down).length}',
                            caption: 'Patients trending down',
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
                    title: 'Cognitive score distribution',
                    caption: 'Number of patients in each score band.',
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
                    title: 'Mean performance by cognitive domain',
                    caption: 'Where the cohort is strongest and weakest.',
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
                    title: 'Engagement by activity',
                    caption: 'Share of sessions each activity accounts for.',
                    child: BarSeriesChart(
                      points: <SeriesPoint>[
                        for (int i = 0; i < MockData.games.length; i++)
                          SeriesPoint(
                            _short(MockData.games[i].name),
                            const <double>[24, 17, 14, 19, 15, 11][i],
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
                    title: 'Sessions completed per week',
                    caption: 'Across the whole caseload.',
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
                    title: 'Patients by district',
                    caption: 'Reach across the North Eastern Region.',
                    child: Column(
                      children: <Widget>[
                        for (final ({String label, int value, Color color}) row
                            in const <({String label, int value, Color color})>[
                          (label: 'Assam', value: 11, color: AppColors.seriesTeal),
                          (label: 'Manipur', value: 4, color: AppColors.seriesOchre),
                          (label: 'Meghalaya', value: 3, color: AppColors.seriesBlue),
                          (label: 'Nagaland', value: 3, color: AppColors.seriesClay),
                          (label: 'Mizoram', value: 2, color: AppColors.seriesPlum),
                          (label: 'Tripura', value: 1, color: AppColors.seriesLeaf),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _countIn(List<ClinicPatient> list, int lo, int hi) =>
      list.where((ClinicPatient c) => c.score >= lo && c.score < hi).length;

  static int _mean(List<ClinicPatient> list) =>
      (list.fold<int>(0, (int a, ClinicPatient c) => a + c.score) / list.length).round();

  static int _meanAdherence(List<ClinicPatient> list) =>
      (list.fold<int>(0, (int a, ClinicPatient c) => a + c.adherence) / list.length).round();

  static String _short(String name) => switch (name) {
        'Procedure Reconstruction' => 'Procedure',
        'Finish the Story' => 'Story',
        'Familiar Place Explorer' => 'Place',
        'Melody of the Valleys' => 'Melody',
        'Weaves of the Hills' => 'Weaves',
        'NER Memory Cards' => 'Cards',
        _ => name,
      };
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
