import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/doctor.dart';
import '../../../core/models/game.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../alerts/doctor_alerts_screen.dart';
import '../appointments/appointment_detail_screen.dart';
import '../patients/patient_detail_screen.dart';
import '../profile/doctor_profile_screen.dart';
import '../widgets/clinic_widgets.dart';

/// Clinical overview dashboard:
/// Combines caseload overview, today's appointments, and key patient analytics.
class DoctorOverviewScreen extends StatelessWidget {
  const DoctorOverviewScreen({
    super.key,
    this.onOpenTab,
    this.onOpenProfile,
  });

  final ValueChanged<int>? onOpenTab;
  final VoidCallback? onOpenProfile;

  String _greetingText() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dateLabel() {
    final DateTime now = DateTime.now();
    const List<String> weekdays = <String>[
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final String weekday = weekdays[now.weekday - 1];
    final String month = months[now.month - 1];
    return '$weekday, ${now.day} $month ${now.year}';
  }

  double _countIn(List<ClinicPatient> list, int min, int max) {
    return list
        .where((ClinicPatient c) => c.score >= min && c.score < max)
        .length
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ClinicPatient> caseload = state.caseload;

    final List<DoctorAppointment> todayAppts = state.doctorAppointments
        .where((DoctorAppointment a) => a.dateLabel.toLowerCase() == 'today')
        .toList();

    final List<ClinicPatient> attentionPatients = caseload
        .where((ClinicPatient p) =>
            p.status == ClinicalStatus.needsAttention ||
            p.trend == TrendDirection.down ||
            p.adherence < 75)
        .toList();

    // Domain averages across the cohort
    final Map<String, int> domainAverages = <String, int>{
      for (final CognitiveDomain d in CognitiveDomain.values)
        d.localizedLabel(l): (caseload.fold<int>(0, (int a, ClinicPatient c) => a + c.profile.score(d)) /
                caseload.length)
            .round(),
    };

    // Score distribution
    final List<SeriesPoint> distribution = <SeriesPoint>[
      SeriesPoint('<50', _countIn(caseload, 0, 50)),
      SeriesPoint('50–59', _countIn(caseload, 50, 60)),
      SeriesPoint('60–69', _countIn(caseload, 60, 70)),
      SeriesPoint('70–79', _countIn(caseload, 70, 80)),
      SeriesPoint('80+', _countIn(caseload, 80, 200)),
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          ClinicTopBar(
            title: l.doctorTabOverview,
            onAlerts: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DoctorAlertsScreen()),
              );
            },
            onProfile: onOpenProfile ??
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DoctorProfileScreen()),
                  );
                },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, 32),
              children: <Widget>[
                // ── Greeting Header ────────────────────────────────────
                FadeInUp(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _greetingText(),
                                style: CT.h1.sized(26).wght(800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _dateLabel(),
                                style: CT.caption.sized(13).tint(AppColors.clinicInkSoft),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: onOpenProfile ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const DoctorProfileScreen(),
                                  ),
                                );
                              },
                          child: const SceneImage(
                            sceneId: 'portrait_priya',
                            size: 52,
                            circle: true,
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),

                // ── Caseload Overview KPI ──────────────────────────────
                FadeInUp(
                  delayMs: 20,
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
                        const SizedBox(height: Insets.md),
                        const Divider(color: AppColors.clinicHairline),
                        const SizedBox(height: Insets.sm),
                        Text(l.doctorOverviewCaseloadStatusLabel, style: CT.overline),
                        const SizedBox(height: 10),
                        _StatusBar(
                          stable: MockData.caseloadStable,
                          attention: MockData.caseloadAttention,
                          followUp: MockData.caseloadFollowUp,
                        ),
                        const SizedBox(height: 12),
                        ChartLegend(
                          entries: <({String label, Color color})>[
                            (
                              label: l.doctorOverviewLegendStable(MockData.caseloadStable),
                              color: AppColors.success
                            ),
                            (
                              label: l.doctorOverviewLegendNeedsAttention(MockData.caseloadAttention),
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

                // ── Today's Appointments Section ───────────────────────
                FadeInUp(
                  delayMs: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.today_rounded, size: 18, color: AppColors.clinicAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l.doctorOverviewTodayAppts, style: CT.h3.wght(700)),
                          ),
                          TextButton(
                            onPressed: () => onOpenTab?.call(2),
                            child: Text(l.doctorTabAppointments),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (todayAppts.isEmpty)
                        ClinicCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(l.doctorOverviewNoAppts, style: CT.caption),
                            ),
                          ),
                        )
                      else
                        for (final DoctorAppointment appt in todayAppts) ...<Widget>[
                          ClinicCard(
                            accentEdge: appt.isVirtual ? const Color(0xFF2F7FB8) : const Color(0xFF3E9268),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AppointmentDetailScreen(appointment: appt),
                                ),
                              );
                            },
                            child: Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: (appt.isVirtual ? const Color(0xFF2F7FB8) : const Color(0xFF3E9268))
                                        .withValues(alpha: 0.12),
                                    borderRadius: Corners.r(6),
                                  ),
                                  child: Icon(
                                    appt.isVirtual ? Icons.videocam_rounded : Icons.location_on_rounded,
                                    size: 17,
                                    color: appt.isVirtual ? const Color(0xFF2F7FB8) : const Color(0xFF3E9268),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(appt.patientName, style: CT.body.wght(700)),
                                      Text(
                                        '${appt.timeLabel} · ${appt.isVirtual ? l.doctorApptVirtual : l.doctorApptInPerson}',
                                        style: CT.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                if (appt.isVirtual)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.clinicAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => AppointmentDetailScreen(
                                            appointment: appt,
                                            autoLaunchVideo: true,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(l.doctorApptJoin, style: CT.caption.wght(700).tint(Colors.white)),
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.clinicInkSoft),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Patients Needing Attention ─────────────────────────
                FadeInUp(
                  delayMs: 50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Patients Needing Attention',
                              style: CT.h3.wght(700),
                            ),
                          ),
                          PillTag(
                            label: '${attentionPatients.length} Patients',
                            color: AppColors.danger,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Flagged for cognitive score decline, missed activities, or clinical review.',
                        style: CT.caption,
                      ),
                      const SizedBox(height: 10),
                      if (attentionPatients.isEmpty)
                        ClinicCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text('All patients in caseload are currently stable.', style: CT.caption),
                            ),
                          ),
                        )
                      else
                        for (final ClinicPatient p in attentionPatients) ...<Widget>[
                          ClinicCard(
                            accentEdge: AppColors.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PatientDetailScreen(patientId: p.id),
                                ),
                              );
                            },
                            child: Row(
                              children: <Widget>[
                                SceneImage(
                                  sceneId: p.sceneId,
                                  size: 42,
                                  circle: true,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        p.name,
                                        style: CT.body.wght(700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p.age} yrs · ${p.district}',
                                        style: CT.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: <Widget>[
                                          Text(
                                            'Score ${p.score}',
                                            style: CT.bodySmall.wght(700),
                                          ),
                                          const SizedBox(width: 5),
                                          Icon(
                                            p.trend.icon,
                                            size: 14,
                                            color: p.trend == TrendDirection.down
                                                ? AppColors.danger
                                                : (p.trend == TrendDirection.up
                                                    ? AppColors.success
                                                    : AppColors.warning),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              p.trend == TrendDirection.down
                                                  ? 'Score declining'
                                                  : (p.adherence < 75
                                                      ? 'Low adherence (${p.adherence}%)'
                                                      : 'Review due'),
                                              style: CT.caption.tint(AppColors.danger).wght(600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.clinicInkSoft),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Medication Adherence by Patient ────────────────────
                FadeInUp(
                  delayMs: 60,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorAnalyticsAdherenceTitle, style: CT.h3),
                        const SizedBox(height: 3),
                        Text(l.doctorAnalyticsAdherenceCaption, style: CT.caption),
                        const SizedBox(height: Insets.md),
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

                // ── Cognitive Domain Performance ───────────────────────
                FadeInUp(
                  delayMs: 80,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorAnalyticsDomainTitle, style: CT.h3),
                        const SizedBox(height: 3),
                        Text(l.doctorAnalyticsDomainCaption, style: CT.caption),
                        const SizedBox(height: Insets.md),
                        Center(
                          child: RadarChart(
                            values: domainAverages,
                            size: 260,
                            color: AppColors.seriesBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── Cognitive Score Distribution ───────────────────────
                FadeInUp(
                  delayMs: 100,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorAnalyticsScoreDistTitle, style: CT.h3),
                        const SizedBox(height: 3),
                        Text(l.doctorAnalyticsScoreDistCaption, style: CT.caption),
                        const SizedBox(height: Insets.md),
                        BarSeriesChart(
                          points: distribution,
                          color: AppColors.seriesTeal,
                          maxValue: distribution
                                  .map((SeriesPoint p) => p.value)
                                  .reduce((double a, double b) => a > b ? a : b) +
                              1,
                          showValues: true,
                          height: 160,
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
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.stable,
    required this.attention,
    required this.followUp,
  });

  final int stable;
  final int attention;
  final int followUp;

  @override
  Widget build(BuildContext context) {
    final int total = stable + attention + followUp;
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: Corners.r(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: stable,
              child: const ColoredBox(color: AppColors.success),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: attention,
              child: const ColoredBox(color: AppColors.danger),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: followUp,
              child: const ColoredBox(color: AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }
}
