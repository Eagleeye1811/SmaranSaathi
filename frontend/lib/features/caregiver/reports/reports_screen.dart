import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/caregiver_note.dart';
import '../../../core/models/doctor.dart';
import '../../../core/models/game.dart';
import '../../../core/models/medical_report.dart';
import '../../../core/models/onboarding.dart';
import '../../../core/models/weekly_report.dart';
import '../../../core/services/app_state.dart';
import '../../../core/telehealth/consultation_format.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../intake/onboarding_l10n.dart';

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

/// Where the caregiver gives ongoing input for the doctor's weekly report —
/// never the report itself. Neither the caregiver nor the patient can see
/// evaluation metrics anywhere in this app; this card only ever collects,
/// never displays, clinical data.
class _WeeklyReportCard extends StatefulWidget {
  const _WeeklyReportCard({required this.state});
  final AppState state;

  @override
  State<_WeeklyReportCard> createState() => _WeeklyReportCardState();
}

class _WeeklyReportCardState extends State<_WeeklyReportCard> {
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submitNote() {
    if (_noteCtrl.text.trim().isEmpty) return;
    widget.state.addCaregiverNote(_noteCtrl.text);
    setState(_noteCtrl.clear);
  }

  void _openConcernSheet(BuildContext context, DailyDifficulty difficulty) {
    ConcernTrend trend = ConcernTrend.same;
    final TextEditingController commentCtrl = TextEditingController();
    final AppLocalizations l = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext bctx, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                MediaQuery.of(bctx).viewInsets.bottom + Insets.xl,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(dailyDifficultyLabel(l, difficulty), style: AppText.h3),
                  const SizedBox(height: 4),
                  Text('How has this been since you last checked in?', style: AppText.bodySmall),
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: <Widget>[
                      for (final ConcernTrend t in ConcernTrend.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(switch (t) {
                                ConcernTrend.better => 'Better',
                                ConcernTrend.same => 'Same',
                                ConcernTrend.worse => 'Worse',
                              }),
                              selected: trend == t,
                              onSelected: (bool sel) {
                                if (sel) setModalState(() => trend = t);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Anything you would like to add? (optional)',
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(borderRadius: Corners.r(Corners.md)),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  SoftButton(
                    label: 'Save',
                    icon: Icons.check_rounded,
                    color: AppColors.primary,
                    filled: true,
                    onPressed: () {
                      widget.state
                          .logConcernUpdate(difficulty, trend, comment: commentCtrl.text.trim());
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.state;
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DailyDifficulty> concerns = state.intake.onboarding.topDifficulties;
    final DoctorProfile? doctor = state.connectedDoctor;

    final List<_CycleEntry> entries = <_CycleEntry>[
      for (final CaregiverConcernUpdate c in state.concernUpdatesThisCycle)
        _CycleEntry(
          at: c.at,
          icon: Icons.trending_flat_rounded,
          text: '${dailyDifficultyLabel(l, c.difficulty)}: ${switch (c.trend) {
            ConcernTrend.better => 'better',
            ConcernTrend.same => 'about the same',
            ConcernTrend.worse => 'a little worse',
          }}${c.comment.isEmpty ? '' : ' — ${c.comment}'}',
        ),
      for (final CaregiverNoteEntry n in state.notesThisCycle)
        _CycleEntry(at: n.at, icon: Icons.sticky_note_2_outlined, text: n.text),
    ]..sort((_CycleEntry a, _CycleEntry b) => b.at.compareTo(a.at));

    final WeeklyClinicalReport? lastReport = state.lastCompletedReport;

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (lastReport != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: AppColors.successTint,
                borderRadius: Corners.r(Corners.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A full week\'s report (7 of 7 activities) was sent to '
                      '${doctor?.name ?? 'your doctor'} on '
                      '${formatConsultationDate(lastReport.generatedAt)}.',
                      style: AppText.bodySmall.wght(600).tint(AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
          Row(
            children: <Widget>[
              const Icon(Icons.forum_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  doctor != null
                      ? '${state.cycleActivitiesCompleted} of 7 activities completed this round · Notes go to Dr. ${doctor.name}'
                      : 'Connect a doctor to share these notes with them',
                  style: AppText.bodySmall.wght(700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (concerns.isNotEmpty) ...<Widget>[
            Text('How has this been going?', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final DailyDifficulty d in concerns)
                  ActionChip(
                    label: Text(dailyDifficultyLabel(l, d)),
                    onPressed: () => _openConcernSheet(context, d),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _noteCtrl,
                  onSubmitted: (_) => _submitNote(),
                  decoration: InputDecoration(
                    hintText: 'Add a note for your doctor',
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: Corners.r(Corners.md)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _submitNote,
              ),
            ],
          ),
          if (entries.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            const Divider(color: AppColors.hairline),
            const SizedBox(height: Insets.sm),
            Text('This week so far', style: AppText.label),
            const SizedBox(height: 8),
            for (final _CycleEntry e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(e.icon, size: 16, color: AppColors.inkMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.text, style: AppText.bodySmall)),
                  ],
                ),
              ),
          ],
          if (kDebugMode) ...<Widget>[
            const SizedBox(height: Insets.md),
            const Divider(color: AppColors.hairline),
            const SizedBox(height: Insets.sm),
            _DemoRoundButton(state: state),
          ],
        ],
      ),
    );
  }
}

/// Debug-build only — never compiled into a release build (`kDebugMode`).
/// Fills in the rest of the current round so a demo only has to play one
/// real activity to trigger the weekly report, instead of sitting through
/// all 7.
class _DemoRoundButton extends StatefulWidget {
  const _DemoRoundButton({required this.state});
  final AppState state;

  @override
  State<_DemoRoundButton> createState() => _DemoRoundButtonState();
}

class _DemoRoundButtonState extends State<_DemoRoundButton> {
  GameId? _leftToPlay;

  @override
  Widget build(BuildContext context) {
    final GameId? left = _leftToPlay;
    return Row(
      children: <Widget>[
        const Icon(Icons.science_outlined, size: 15, color: AppColors.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            left == null
                ? 'Demo: simulate 6 of 7 activities'
                : 'Simulated 6/7 — play "${MockData.game(left).name}" to finish the round',
            style: AppText.caption.tint(AppColors.inkMuted),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _leftToPlay = widget.state.simulateRestOfRoundForDemo();
          }),
          child: const Text('Simulate'),
        ),
      ],
    );
  }
}

class _CycleEntry {
  const _CycleEntry({required this.at, required this.icon, required this.text});
  final DateTime at;
  final IconData icon;
  final String text;
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
