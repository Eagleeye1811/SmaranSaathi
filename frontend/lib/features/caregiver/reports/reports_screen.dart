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
import '../../../core/services/report_store.dart';
import '../../../core/telehealth/consultation_format.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../intake/onboarding_l10n.dart';

/// Reports & Insights page — weekly summary, medical reports with AI
/// explanation, and the week's engagement trend.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<MedicalReport> reports = state.medicalReports;

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
                    Insets.gutter, Insets.md, Insets.gutter, 32),
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
                    child: reports.isEmpty
                        ? _NoReportsCard(
                            onUpload: () => _showUploadSheet(context))
                        : Column(
                            children: <Widget>[
                              for (int i = 0; i < reports.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          i < reports.length - 1 ? 12 : 0),
                                  child: _ReportCard(
                                    report: reports[i],
                                    onDelete: () => _confirmDelete(
                                        context, state, reports[i]),
                                  ),
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

  /// Which kind of document this is, then the system picker.
  ///
  /// The kind is asked first and not inferred: a PDF from a lab could be any
  /// of these, the file name is no guide ("scan_002.pdf"), and it is the one
  /// thing the caregiver knows for certain at the moment they attach it.
  void _showUploadSheet(BuildContext context) {
    final AppState state = AppScope.read(context);

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
                'Attach a PDF or a photo of an MRI, EEG, blood test or other '
                'medical document. It stays on this device.',
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
                    onTap: () {
                      // Closed before the picker opens: the system sheet takes
                      // over the screen anyway, and leaving this one behind it
                      // means returning to a stale sheet over the new report.
                      Navigator.pop(ctx);
                      _pickAndAttach(context, state, kind);
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndAttach(
      BuildContext context, AppState state, ReportKind kind) async {
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);

    final PickedReport? picked = await ReportStore.pick();
    // A dismissed picker is not a failure and says nothing on screen. Only a
    // pick that genuinely could not be stored is worth a message.
    if (picked == null) return;

    state.addMedicalReport(
      kind: kind,
      fileName: picked.fileName,
      filePath: picked.filePath,
      sizeBytes: picked.sizeBytes,
    );

    messenger?.showSnackBar(
      SnackBar(content: Text('${kind.label} attached · ${picked.fileName}')),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, MedicalReport report) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Remove this report?'),
            content: Text(
              '${report.kind.label} from ${report.dateLabel} will be deleted '
              'from this device. This cannot be undone.',
              style: AppText.bodySmall,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Remove',
                    style: AppText.body.wght(700).tint(AppColors.danger)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    // The record goes through `AppState`; its file is this layer's to clean
    // up, because `AppState` stays free of `dart:io`.
    final MedicalReport? removed = state.removeMedicalReport(report.id);
    if (removed != null) await ReportStore.delete(removed.filePath);
  }
}

/// Shown in place of the list before anything has been attached.
class _NoReportsCard extends StatelessWidget {
  const _NoReportsCard({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SoftIcon(
                  icon: Icons.folder_open_rounded,
                  color: AppColors.inkMuted,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('No reports yet', style: AppText.body.wght(700)),
                    const SizedBox(height: 2),
                    Text(
                      'Keep scans and lab results in one place, ready for the '
                      'next appointment.',
                      style: AppText.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          BigButton(
            label: 'Attach a report',
            icon: Icons.upload_file_rounded,
            height: 52,
            onPressed: onUpload,
          ),
        ],
      ),
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
  // Only set once *this* button has actually been tapped, so the "play X to
  // finish" wording can name the game. Coming back to this screen after the
  // round already finished elsewhere (played on another device, or simply a
  // fresh instance of this widget) has no such name to show — `caption`
  // below falls back to the live count instead of assuming nothing happened.
  GameId? _justFastForwarded;

  @override
  Widget build(BuildContext context) {
    final int done = widget.state.cycleActivitiesCompleted;
    final GameId? left = _justFastForwarded;
    final String caption = done >= 7
        ? 'Round complete — 7 of 7 played'
        : left != null
            ? 'Fast-forwarded 6/7 — play "${MockData.game(left).name}" to finish the round'
            : done > 0
                ? 'Fast-forwarded $done/7 — play the last activity to finish the round'
                : 'Fast-forward 6 of 7 activities';
    return Row(
      children: <Widget>[
        const Icon(Icons.science_outlined, size: 15, color: AppColors.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(caption, style: AppText.caption.tint(AppColors.inkMuted)),
        ),
        if (done < 7)
          TextButton(
            onPressed: () => setState(() {
              _justFastForwarded = widget.state.simulateRestOfRoundForDemo();
            }),
            child: const Text('Fast-forward'),
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

// ── Medical report card ───────────────────────────────────────────────────────

class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.report, this.onDelete});
  final MedicalReport report;

  /// Null for a row with no file behind it, which there is nothing to remove.
  final VoidCallback? onDelete;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _expanded = false;

  /// Resolved once per build rather than inside the row, so the check is not
  /// repeated as the card animates in.
  late bool _fileExists = ReportStore.exists(widget.report.filePath);

  @override
  void didUpdateWidget(_ReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.filePath != widget.report.filePath) {
      _fileExists = ReportStore.exists(widget.report.filePath);
    }
  }

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
              if (widget.onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Remove',
                    child: Pressable(
                      onTap: widget.onDelete!,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 19, color: AppColors.inkMuted),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // The attached file itself, when there is one: the name the
          // caregiver will recognise, its size, and whether the copy is still
          // on disk. A record can outlive its file — a backup restored onto a
          // new phone brings this list but not the documents — and saying so
          // plainly beats a row that silently does nothing.
          if (r.hasFile) ...<Widget>[
            const SizedBox(height: Insets.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: Corners.r(Corners.md),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    r.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_outlined,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.fileName,
                      style: AppText.bodySmall.wght(600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fileExists ? r.sizeLabel : 'File missing',
                    style: AppText.caption.tint(
                        _fileExists ? AppColors.inkMuted : AppColors.danger),
                  ),
                ],
              ),
            ),
          ],
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
