import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/medical_report.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';

// ── Mock medical reports ──────────────────────────────────────────────────────

const List<MedicalReport> _mockReports = <MedicalReport>[
  MedicalReport(
    id: 'r_001',
    kind: ReportKind.mri,
    dateLabel: '10 August 2026',
    doctorName: 'Dr. Neha Sharma',
    status: ReportStatus.summarised,
    aiSummary:
        'The MRI shows mild changes consistent with the normal aging process. '
        'There are small areas of reduced blood flow in the memory-related part '
        'of the brain (hippocampus), which is common with early memory changes. '
        'No signs of stroke or tumour. The doctor can discuss what this means '
        'for day-to-day care.',
    fileName: 'MRI_Brain_Aug2026.pdf',
  ),
  MedicalReport(
    id: 'r_002',
    kind: ReportKind.eeg,
    dateLabel: '15 July 2026',
    doctorName: 'Dr. Neha Sharma',
    status: ReportStatus.awaitingDoctor,
    fileName: 'EEG_Report_Jul2026.pdf',
  ),
  MedicalReport(
    id: 'r_003',
    kind: ReportKind.bloodTest,
    dateLabel: '1 June 2026',
    doctorName: 'Jorhat Medical Lab',
    status: ReportStatus.uploaded,
    fileName: 'BloodTest_Jun2026.pdf',
  ),
];

/// Reports & Insights page — weekly summary, medical reports with AI explanation,
/// and AI care insights panel.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return MotifBackground(
      opacity: 0.04,
      showTopWash: false,
      // No top inset: this screen only ever renders inside `CaregiverShell`,
      // whose own header already clears the status bar.
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  // ── Weekly report card ────────────────────────────────
                  FadeInUp(
                    child: SectionHeader(
                      title: 'Weekly Overview',
                      icon: Icons.calendar_view_week_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 20,
                    child: _WeeklyReportCard(state: state),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── AI care insights ──────────────────────────────────
                  FadeInUp(
                    delayMs: 60,
                    child: SectionHeader(
                      title: 'AI Care Insights',
                      icon: Icons.auto_awesome_rounded,
                      subtitle:
                          'Patterns observed over the past 2 weeks',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 80,
                    child: _AiInsightsCard(state: state),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Medical reports ───────────────────────────────────
                  FadeInUp(
                    delayMs: 120,
                    child: SectionHeader(
                      title: 'Medical Reports',
                      icon: Icons.folder_open_rounded,
                      action: 'Upload',
                      onAction: () => _showUploadSheet(context),
                    ),
                  ),
                  FadeInUp(
                    delayMs: 140,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < _mockReports.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                                bottom: i < _mockReports.length - 1
                                    ? 12
                                    : 0),
                            child: _ReportCard(
                                report: _mockReports[i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Engagement chart ──────────────────────────────────
                  FadeInUp(
                    delayMs: 180,
                    child: SectionHeader(
                      title: 'Engagement This Week',
                      icon: Icons.insights_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 200,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Daily engagement: last 7 days',
                              style: AppText.overline),
                          const SizedBox(height: 10),
                          TrendLineChart(
                            points: state.engagementWeek,
                            color: AppColors.seriesTeal,
                            valueSuffix: '%',
                            minValue: 40,
                            height: 150,
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

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Upload a Report', style: AppText.h3),
              const SizedBox(height: 4),
              Text(
                'Upload MRI, EEG, blood tests or other medical documents. '
                'The original is always available to your doctor.',
                style: AppText.bodySmall,
              ),
              const SizedBox(height: Insets.lg),
              for (final ReportKind kind in ReportKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListRow(
                    leading: SoftIcon(
                        icon: kind.icon, color: kind.color, size: 44),
                    title: kind.label,
                    trailing: const Icon(
                        Icons.upload_file_rounded,
                        color: AppColors.inkMuted,
                        size: 20),
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ── Weekly report summary ─────────────────────────────────────────────────────

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final int done = state.gamesCompletedTotal();
    final int adherence = state.adherencePercent;

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Week of 6 – 12 September 2026',
              style: AppText.overline),
          const SizedBox(height: 12),
          _SummaryRow(
              icon: Icons.extension_rounded,
              color: AppColors.seriesTeal,
              label: 'Cognitive activities',
              value: '$done completed this week'),
          _SummaryRow(
              icon: Icons.psychology_alt_rounded,
              color: AppColors.seriesOchre,
              label: 'Average accuracy',
              value: '${state.averageAccuracy().round()}%'),
          _SummaryRow(
              icon: Icons.sentiment_satisfied_alt_rounded,
              color: AppColors.success,
              label: 'Mood',
              value: 'Calm on 5 of 7 days'),
          _SummaryRow(
              icon: Icons.medication_liquid_rounded,
              color: AppColors.terracotta,
              label: 'Reminder adherence',
              value: '$adherence%, ${state.remindersDone}/${state.remindersTotal} acknowledged'),
          _SummaryRow(
              icon: Icons.shield_outlined,
              color: AppColors.primary,
              label: 'Safety',
              value: 'No alerts this week',
              last: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: <Widget>[
          SoftIcon(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppText.label),
                const SizedBox(height: 2),
                Text(value, style: AppText.bodySmall.wght(600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI insights card ──────────────────────────────────────────────────────────

class _AiInsightsCard extends StatelessWidget {
  const _AiInsightsCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      color: AppColors.primaryTint.withValues(alpha: 0.5),
      border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('AI Care Insights',
                    style: AppText.h3.tint(AppColors.primaryDeep)),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          for (final _InsightItem item in _insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InsightRow(item: item),
            ),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: 10),
          Text(
            '✦ AI-observed patterns, for context only. '
            'Not a medical diagnosis. Consult your doctor for clinical decisions.',
            style: AppText.caption
                .tint(AppColors.inkMuted)
                .copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  static const List<_InsightItem> _insights = <_InsightItem>[
    _InsightItem(
      label: 'Sequencing trend',
      body:
          'Over the past 2 weeks, sequencing activities required more hints than in previous weeks. This is an area worth monitoring.',
      icon: Icons.trending_down_rounded,
      color: AppColors.warning,
    ),
    _InsightItem(
      label: 'Auditory memory improving',
      body:
          'Melody of the Valleys showed a consistent upward trend over 6 consecutive sessions.',
      icon: Icons.trending_up_rounded,
      color: AppColors.success,
    ),
    _InsightItem(
      label: 'Stable engagement',
      body:
          'Overall engagement has remained between 68–81% for 14 consecutive days, suggesting a consistent routine.',
      icon: Icons.trending_flat_rounded,
      color: AppColors.secondary,
    ),
  ];
}

@immutable
class _InsightItem {
  const _InsightItem({
    required this.label,
    required this.body,
    required this.icon,
    required this.color,
  });
  final String label;
  final String body;
  final IconData icon;
  final Color color;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.item});
  final _InsightItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(item.icon, size: 18, color: item.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(item.label,
                  style: AppText.body.wght(700)),
              const SizedBox(height: 3),
              Text(item.body, style: AppText.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Medical report card ───────────────────────────────────────────────────────

class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.report});
  final MedicalReport report;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final MedicalReport r = widget.report;
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: r.kind.icon, color: r.kind.color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(r.kind.label, style: AppText.body.wght(700)),
                    const SizedBox(height: 2),
                    Text(r.dateLabel, style: AppText.caption),
                    const SizedBox(height: 2),
                    Text(r.doctorName,
                        style: AppText.caption,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PillTag(
                  label: r.status.label,
                  color: r.hasSummary
                      ? AppColors.success
                      : AppColors.inkMuted,
                  dense: true,
                ),
              ),
            ],
          ),
          if (r.hasSummary) ...<Widget>[
            const SizedBox(height: Insets.md),
            Pressable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Explain in simple language',
                        style: AppText.body
                            .wght(700)
                            .tint(AppColors.primary)),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            if (_expanded) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: Corners.r(Corners.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(r.aiSummary!, style: AppText.bodySmall),
                    const SizedBox(height: 8),
                    Text(
                      'AI-generated explanation, for understanding only. '
                      'The original report is always available to your doctor.',
                      style: AppText.caption
                          .tint(AppColors.inkMuted)
                          .copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
