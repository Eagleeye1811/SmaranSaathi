import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../widgets/clinic_widgets.dart';

/// One patient's longitudinal picture. Framed throughout as *cognitive
/// activity performance*, never as a diagnosis.
class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ClinicPatient patient = state.caseload.firstWhere(
      (ClinicPatient c) => c.id == patientId,
      orElse: () => state.caseload.first,
    );
    final bool isDemoPatient = patient.id == state.patient.id;
    final List<DoctorAlert> alerts = state.alerts
        .where((DoctorAlert a) => a.patientName == patient.name)
        .toList();

    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 10),
                child: Row(
                  children: <Widget>[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      color: AppColors.clinicInk,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Patient record', style: CT.h3.wght(800))),
                    StatusChip(status: patient.status),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                  children: <Widget>[
                    // ── Identity ────────────────────────────────────────
                    FadeInUp(
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                SceneImage(
                                  sceneId: patient.sceneId,
                                  size: 66,
                                  circle: true,
                                  borderColor: Colors.white,
                                  borderWidth: 3,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(patient.name, style: CT.h2.sized(22)),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${patient.age} years · ${patient.district}',
                                        style: CT.caption,
                                      ),
                                      const SizedBox(height: 3),
                                      Text('Language: ${patient.language}',
                                          style: CT.caption),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text('${patient.score}',
                                        style: CT.statLarge
                                            .tint(trendColor(patient.trend))),
                                    Text('overall', style: CT.caption.sized(10.5)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: Insets.md),
                            const Divider(color: AppColors.clinicHairline),
                            const SizedBox(height: Insets.md),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ClinicStat(
                                    label: 'Engagement',
                                    value: '${patient.engagement}%',
                                    color: AppColors.seriesTeal,
                                  ),
                                ),
                                Expanded(
                                  child: ClinicStat(
                                    label: 'Adherence',
                                    value: '${patient.adherence}%',
                                    color: AppColors.seriesBlue,
                                  ),
                                ),
                                Expanded(
                                  child: ClinicStat(
                                    label: 'Last session',
                                    value: patient.lastSession.split(',').first,
                                    color: AppColors.clinicInkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Cognitive profile ───────────────────────────────
                    FadeInUp(
                      delayMs: 50,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Cognitive profile', style: CT.h3),
                            const SizedBox(height: 3),
                            Text(patient.profile.updated, style: CT.caption),
                            const SizedBox(height: Insets.md),
                            Center(
                              child: RadarChart(
                                values: <String, int>{
                                  for (final CognitiveDomain d in CognitiveDomain.values)
                                    d.label: patient.profile.score(d),
                                },
                                size: 280,
                                color: AppColors.seriesTeal,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            const Divider(color: AppColors.clinicHairline),
                            const SizedBox(height: Insets.md),
                            for (final CognitiveDomain d in CognitiveDomain.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 11),
                                child: Row(
                                  children: <Widget>[
                                    Icon(d.icon, size: 16, color: AppColors.clinicInkSoft),
                                    const SizedBox(width: 9),
                                    SizedBox(
                                      width: 84,
                                      child: Text(d.label, style: CT.bodySmall),
                                    ),
                                    Expanded(
                                      child: MeterBar(
                                        value: patient.profile.score(d) / 100,
                                        color: _domainColor(patient.profile.score(d)),
                                        height: 8,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${patient.profile.score(d)}',
                                        textAlign: TextAlign.right,
                                        style: CT.body.wght(800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.clinicBackground,
                                borderRadius: Corners.r(Corners.sm),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Text('Overall', style: CT.body.wght(700)),
                                  const Spacer(),
                                  Text('${patient.profile.overall}',
                                      style: CT.stat.tint(AppColors.clinicAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── 30-day trend ────────────────────────────────────
                    FadeInUp(
                      delayMs: 90,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text('Cognitive performance trend', style: CT.h3),
                                ),
                                Row(
                                  children: <Widget>[
                                    Icon(patient.trend.icon,
                                        size: 15, color: trendColor(patient.trend)),
                                    const SizedBox(width: 5),
                                    Text(patient.trend.label,
                                        style: CT.caption
                                            .wght(700)
                                            .tint(trendColor(patient.trend))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Last 30 days. Shaded band is this patient\'s typical range.',
                                style: CT.caption),
                            const SizedBox(height: Insets.md),
                            TrendLineChart(
                              points: <SeriesPoint>[
                                for (int i = 0; i < patient.thirtyDay.length; i++)
                                  SeriesPoint(
                                    i == 0
                                        ? '30d ago'
                                        : i == patient.thirtyDay.length - 1
                                            ? 'Today'
                                            : '${patient.thirtyDay.length - i}',
                                    patient.thirtyDay[i],
                                  ),
                              ],
                              color: trendColor(patient.trend),
                              minValue: 25,
                              labelEvery: 7,
                              showDots: false,
                              height: 190,
                              band: (
                                low: patient.score - 8.0,
                                high: patient.score + 8.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Activity breakdown ──────────────────────────────
                    if (isDemoPatient) ...<Widget>[
                      FadeInUp(
                        delayMs: 120,
                        child: ClinicCard(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Performance by activity', style: CT.h3),
                              const SizedBox(height: 3),
                              Text('Mean session score across recorded sessions.',
                                  style: CT.caption),
                              const SizedBox(height: Insets.md),
                              BarSeriesChart(
                                points: <SeriesPoint>[
                                  for (final GameDefinition g in MockData.games)
                                    SeriesPoint(_short(g.name), _avg(state, g.id)),
                                ],
                                color: AppColors.seriesBlue,
                                showValues: true,
                                height: 175,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      FadeInUp(
                        delayMs: 150,
                        child: ClinicCard(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Session log', style: CT.h3),
                              const SizedBox(height: Insets.md),
                              for (int i = 0; i < state.sessions.take(8).length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: <Widget>[
                                      SizedBox(
                                        width: 66,
                                        child: Text(
                                          state.sessions[i].dayOffset == 0
                                              ? 'Today'
                                              : state.sessions[i].dayOffset == 1
                                                  ? 'Yesterday'
                                                  : '−${state.sessions[i].dayOffset}d',
                                          style: CT.caption.wght(700),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          MockData.game(state.sessions[i].gameId).name,
                                          style: CT.bodySmall.tint(AppColors.clinicInk),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('L${state.sessions[i].level}',
                                          style: CT.caption),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 34,
                                        child: Text(
                                          '${state.sessions[i].performance.overall}',
                                          textAlign: TextAlign.right,
                                          style: CT.body.wght(800),
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
                    ],

                    // ── Alerts ──────────────────────────────────────────
                    if (alerts.isNotEmpty) ...<Widget>[
                      FadeInUp(
                        delayMs: 170,
                        child: Text('Alerts', style: CT.h3),
                      ),
                      const SizedBox(height: 10),
                      for (final DoctorAlert a in alerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClinicCard(
                            accentEdge: severityColor(a.severity),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                        child: Text(a.title, style: CT.body.wght(700))),
                                    Text(a.age, style: CT.caption),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(a.detail, style: CT.bodySmall),
                                const SizedBox(height: 8),
                                PillTag(
                                  label: a.severity.label,
                                  color: severityColor(a.severity),
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: Insets.lg),
                    ],

                    // ── Suggested next steps ────────────────────────────
                    FadeInUp(
                      delayMs: 190,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Considerations', style: CT.h3),
                            const SizedBox(height: 10),
                            for (final String s in _considerations(patient))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Icon(Icons.circle, size: 6,
                                        color: AppColors.clinicInkSoft),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(s, style: CT.bodySmall)),
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
        ),
      ),
    );
  }

  static Color _domainColor(int score) {
    if (score >= 75) return AppColors.success;
    if (score >= 60) return AppColors.seriesBlue;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  static String _short(String name) => switch (name) {
        'Procedure Reconstruction' => 'Procedure',
        'Finish the Story' => 'Story',
        'Familiar Place Explorer' => 'Place',
        'Melody of the Valleys' => 'Melody',
        'Weaves of the Hills' => 'Weaves',
        'NER Memory Cards' => 'Cards',
        _ => name,
      };

  static double _avg(AppState state, GameId id) {
    final List<GameSession> list = state.sessionsFor(id);
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (double a, GameSession s) => a + s.performance.overall) /
        list.length;
  }

  static List<String> _considerations(ClinicPatient p) {
    return <String>[
      if (p.trend == TrendDirection.down)
        'Cognitive activity performance has decreased over the last 7 days. Consider further clinical assessment.',
      if (p.adherence < 80)
        'Reminder adherence is ${p.adherence}%. Worth reviewing the medication schedule with the caregiver.',
      if (p.engagement < 55)
        'Engagement is low. Consider adjusting the activity mix or the time of day sessions are scheduled.',
      if (p.trend == TrendDirection.up)
        'Performance is improving; the adaptive engine has raised difficulty. No change suggested.',
      if (p.status == ClinicalStatus.followUp)
        'A scheduled review is due this cycle.',
      'These figures describe in-app activity performance only and should be read alongside clinical assessment.',
    ];
  }
}
