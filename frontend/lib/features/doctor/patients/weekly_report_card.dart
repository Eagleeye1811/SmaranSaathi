import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/models/caregiver_note.dart';
import '../../../core/models/weekly_report.dart';
import '../../../core/telehealth/consultation_format.dart';
import '../widgets/clinic_widgets.dart';

/// The doctor-only weekly clinical report: every scored activity's metrics
/// for the current cycle, plus the caregiver's concern check-ins and
/// freeform notes for the same period. Nothing here is ever shown to the
/// patient or caregiver — see `WeeklyReportBuilder`'s doc comment.
class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({super.key, required this.report});

  final WeeklyClinicalReport report;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<ConcernUpdateEntry>> byConcern = <String, List<ConcernUpdateEntry>>{};
    for (final ConcernUpdateEntry c in report.concernUpdates) {
      byConcern.putIfAbsent(c.difficultyLabel, () => <ConcernUpdateEntry>[]).add(c);
    }
    for (final List<ConcernUpdateEntry> list in byConcern.values) {
      list.sort((ConcernUpdateEntry a, ConcernUpdateEntry b) => a.at.compareTo(b.at));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.fact_check_rounded, color: AppColors.clinicAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Weekly Cognitive Report', style: CT.h3.sized(16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.clinicAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${report.activitiesCompleted} of 7 activities',
                style: const TextStyle(
                    color: AppColors.clinicAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Cycle started ${formatConsultationDate(report.cycleStart)} · '
          'active on ${report.daysActive} day${report.daysActive == 1 ? '' : 's'}',
          style: CT.caption,
        ),
        const SizedBox(height: 16),

        Text('ACTIVITY METRICS', style: CT.h3.sized(12).wght(800)),
        const SizedBox(height: 8),
        if (report.gameSummaries.isEmpty)
          Text('No activity recorded yet this cycle.', style: CT.caption)
        else
          for (final GameDomainSummary g in report.gameSummaries) _GameMetricRow(summary: g),

        if (report.onboardingBaselineNote != null) ...<Widget>[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('BASELINE (FROM ONBOARDING)', style: CT.h3.sized(12).wght(800)),
          const SizedBox(height: 6),
          Text(report.onboardingBaselineNote!, style: CT.caption.sized(12)),
        ],

        if (byConcern.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('CAREGIVER CONCERN UPDATES', style: CT.h3.sized(12).wght(800)),
          const SizedBox(height: 8),
          for (final MapEntry<String, List<ConcernUpdateEntry>> entry in byConcern.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entry.key, style: CT.caption.sized(12).wght(700)),
                  const SizedBox(height: 4),
                  for (final ConcernUpdateEntry c in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text(
                        '${formatConsultationDate(c.at)} — ${_trendLabel(c.trend)}'
                        '${c.comment.isEmpty ? '' : ': ${c.comment}'}',
                        style: CT.caption.sized(11.5),
                      ),
                    ),
                ],
              ),
            ),
        ],

        if (report.notes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('CAREGIVER NOTES', style: CT.h3.sized(12).wght(800)),
          const SizedBox(height: 8),
          for (final CaregiverNoteRecord n in report.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(formatConsultationDate(n.at), style: CT.caption.sized(10.5)),
                  Text(n.text, style: CT.caption.sized(12)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static String _trendLabel(ConcernTrend t) => switch (t) {
        ConcernTrend.better => 'Better',
        ConcernTrend.same => 'Same',
        ConcernTrend.worse => 'Worse',
      };
}

class _GameMetricRow extends StatelessWidget {
  const _GameMetricRow({required this.summary});
  final GameDomainSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(summary.gameName, style: CT.caption.sized(12).wght(700)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${summary.sessionsPlayed}x · '
              'acc ${summary.avgAccuracy.round()} · '
              'focus ${summary.avgFocus.round()} · '
              'mem ${summary.avgMemory.round()} · '
              'hints ${summary.avgHintsUsed.toStringAsFixed(1)} · '
              'mistakes ${summary.avgMistakes.toStringAsFixed(1)}',
              style: CT.caption.sized(11),
            ),
          ),
        ],
      ),
    );
  }
}
