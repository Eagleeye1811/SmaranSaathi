import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../../l10n/mock_translator.dart';
import '../patients/patient_detail_screen.dart';
import '../widgets/clinic_widgets.dart';

/// Clinical overview: caseload shape first, then what changed.
class DoctorOverviewScreen extends StatelessWidget {
  const DoctorOverviewScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ClinicPatient> caseload = state.caseload;
    final List<DoctorAlert> alerts = state.alerts;

    final List<ClinicPatient> attention = caseload
        .where((ClinicPatient c) => c.status != ClinicalStatus.stable)
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          ClinicTopBar(
            title: l.doctorOverviewTitle,
            subtitle: MockTranslator.translateClinicName(MockData.clinicName, l),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
              children: <Widget>[
                FadeInUp(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(l.doctorOverviewGreeting(MockData.doctorName), style: CT.h2),
                            const SizedBox(height: 3),
                            Text(_dateLabel(l), style: CT.caption),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.clinicAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.clinicAccent, size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Caseload KPIs ──────────────────────────────────────
                FadeInUp(
                  delayMs: 40,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ClinicStat(
                                label: l.doctorTabPatients,
                                value: '${MockData.caseloadTotal}',
                                caption: l.doctorOverviewActiveCaption,
                                icon: Icons.groups_rounded,
                              ),
                            ),
                            Expanded(
                              child: ClinicStat(
                                label: l.doctorOverviewSessionsWeekLabel,
                                value: '186',
                                caption: l.doctorOverviewSessionsWeekCaption,
                                color: AppColors.seriesTeal,
                                icon: Icons.play_circle_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.lg),
                        const Divider(color: AppColors.clinicHairline),
                        const SizedBox(height: Insets.md),
                        Text(l.doctorOverviewCaseloadStatusLabel, style: CT.overline),
                        const SizedBox(height: 12),
                        _StatusBar(
                          stable: MockData.caseloadStable,
                          attention: MockData.caseloadAttention,
                          followUp: MockData.caseloadFollowUp,
                        ),
                        const SizedBox(height: 14),
                        ChartLegend(
                          entries: <({String label, Color color})>[
                            (
                              label: l.doctorOverviewLegendStable(MockData.caseloadStable),
                              color: AppColors.success
                            ),
                            (
                              label:
                                  l.doctorOverviewLegendNeedsAttention(MockData.caseloadAttention),
                              color: AppColors.danger
                            ),
                            (
                              label: l.doctorOverviewLegendFollowUp(MockData.caseloadFollowUp),
                              color: AppColors.warning
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Cohort trend ───────────────────────────────────────
                FadeInUp(
                  delayMs: 70,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorOverviewTrendTitle, style: CT.h3),
                        const SizedBox(height: 3),
                        Text(l.doctorOverviewTrendCaption, style: CT.caption),
                        const SizedBox(height: Insets.md),
                        TrendLineChart(
                          points: MockData.series(const <double>[68, 69, 67, 70, 71, 70, 72]),
                          color: AppColors.seriesBlue,
                          minValue: 60,
                          maxValue: 80,
                          height: 160,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Needs attention ────────────────────────────────────
                FadeInUp(
                  delayMs: 100,
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(l.doctorOverviewNeedsReviewTitle, style: CT.h3)),
                      TextButton(
                        onPressed: () => onOpenTab?.call(1),
                        child: Text(l.doctorOverviewAllPatients),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < attention.length; i++)
                  FadeInUp(
                    delayMs: 110 + i * 40,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PatientRow(
                        patient: attention[i],
                        onTap: () => Nav.push(
                          context,
                          PatientDetailScreen(patientId: attention[i].id),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: Insets.md),

                // ── Recent alerts ──────────────────────────────────────
                FadeInUp(
                  delayMs: 180,
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(l.doctorOverviewRecentAlertsTitle, style: CT.h3)),
                      TextButton(
                        onPressed: () => onOpenTab?.call(3),
                        child: Text(l.doctorOverviewAllAlerts),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < alerts.take(3).length; i++)
                  FadeInUp(
                    delayMs: 190 + i * 40,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertRow(alert: alerts[i]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(AppLocalizations l) {
    final List<String> months = <String>[
      l.doctorOverviewMonthJanuary,
      l.doctorOverviewMonthFebruary,
      l.doctorOverviewMonthMarch,
      l.doctorOverviewMonthApril,
      l.doctorOverviewMonthMay,
      l.doctorOverviewMonthJune,
      l.doctorOverviewMonthJuly,
      l.doctorOverviewMonthAugust,
      l.doctorOverviewMonthSeptember,
      l.doctorOverviewMonthOctober,
      l.doctorOverviewMonthNovember,
      l.doctorOverviewMonthDecember,
    ];
    final DateTime n = DateTime.now();
    return '${n.day} ${months[n.month - 1]} ${n.year}';
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.stable, required this.attention, required this.followUp});
  final int stable;
  final int attention;
  final int followUp;

  @override
  Widget build(BuildContext context) {
    final int total = stable + attention + followUp;
    return ClipRRect(
      borderRadius: Corners.r(Corners.pill),
      child: SizedBox(
        height: 16,
        child: Row(
          children: <Widget>[
            // a 2px surface gap separates each segment
            _seg(stable / total, AppColors.success, true),
            const SizedBox(width: 2),
            _seg(attention / total, AppColors.danger, false),
            const SizedBox(width: 2),
            _seg(followUp / total, AppColors.warning, false),
          ],
        ),
      ),
    );
  }

  Widget _seg(double f, Color c, bool first) => Expanded(
        flex: (f * 1000).round(),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double t, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: t,
              child: ColoredBox(color: c, child: const SizedBox.expand()),
            ),
          ),
        ),
      );
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});
  final ClinicPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      onTap: onTap,
      accentEdge: statusColor(patient.status),
      child: Row(
        children: <Widget>[
          SceneImage(sceneId: patient.sceneId, size: 44, circle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(patient.name,
                    style: CT.body.wght(700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${patient.age} · ${patient.district}',
                    style: CT.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                StatusChip(status: patient.status),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(patient.trend.icon, size: 16, color: trendColor(patient.trend)),
                  const SizedBox(width: 4),
                  Text('${patient.score}',
                      style: CT.stat.sized(20).tint(trendColor(patient.trend))),
                ],
              ),
              const SizedBox(height: 5),
              Sparkline(
                values: patient.thirtyDay.sublist(patient.thirtyDay.length - 14),
                color: trendColor(patient.trend),
                width: 64,
                height: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final DoctorAlert alert;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color c = severityColor(alert.severity);
    return ClinicCard(
      accentEdge: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(alert.patientName, style: CT.body.wght(700)),
              ),
              Text(alert.age, style: CT.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(alert.title, style: CT.bodySmall.tint(AppColors.clinicInk)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(severityIcon(alert.severity), size: 13, color: c),
              const SizedBox(width: 5),
              Text(alert.severity.localizedLabel(l),
                  style: AppText.caption.sized(11.5).wght(700).tint(c)),
            ],
          ),
        ],
      ),
    );
  }
}
