import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/models/report.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../intake/intake_kit.dart';
import 'health_widgets.dart';

/// The clinician-ready summary.
///
/// This is what the whole journey is for. A doctor gets ten or fifteen minutes
/// and usually sees a single snapshot; this hands them twelve weeks of
/// structured history in the order they would have asked for it — presenting
/// concern, corroboration, function, measured change, and the contextual
/// factors that could explain it.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final ClinicalReport report = state.buildReport();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, Insets.md, Insets.gutter, Insets.lg),
                children: <Widget>[
                  ScreenHeader(
                    eyebrow: l.reportEyebrow,
                    title: l.reportTitle,
                    subtitle: report.periodLabel,
                    leading: RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  _Identity(report: report),
                  const SizedBox(height: Insets.md),
                  for (final ReportSection section in report.sections) ...<Widget>[
                    _Section(section: section),
                    const SizedBox(height: Insets.md),
                  ],
                  SectionHeader(
                    title: l.reportObservedPatternsTitle,
                    subtitle: l.reportObservedPatternsSubtitle,
                  ),
                  const SizedBox(height: Insets.sm),
                  for (final ObservedPattern p in report.patterns) PatternRow(pattern: p),
                  const SizedBox(height: Insets.sm),
                  if (report.suggestsDiscussion) ...<Widget>[
                    MmCard(
                      color: AppColors.accentTint,
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.event_available_rounded, color: AppColors.accent),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Text(
                              l.reportSuggestsDiscussion,
                              style: AppText.body.copyWith(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                  NotADiagnosisNote(message: ClinicalReport.disclaimer),
                ],
              ),
            ),
            _ShareBar(report: report),
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.report});

  final ClinicalReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(report.patientName, style: AppText.h2),
          const SizedBox(height: 4),
          Text(
              '${l.reportAgeYears(report.age)} · ${report.language} · '
              '${report.occupation}',
              style: AppText.bodySmall),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              PillTag(
                  label: l.reportCompletedBy(report.completedBy.toLowerCase()), dense: true),
              PillTag(
                label: report.periodLabel,
                color: AppColors.secondary,
                dense: true,
                icon: Icons.calendar_month_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(section.title.toUpperCase(), style: AppText.overline),
          const SizedBox(height: Insets.sm),
          for (final String line in section.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 8, right: 10),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.inkMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Text(line, style: AppText.body.copyWith(height: 1.45))),
                ],
              ),
            ),
          if (section.note != null) ...<Widget>[
            const SizedBox(height: Insets.xs),
            Text(section.note!, style: AppText.caption.copyWith(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.report});

  final ClinicalReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BigButton(
            label: l.reportCopySummaryButton,
            icon: Icons.copy_all_rounded,
            height: 60,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report.asPlainText()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.reportCopiedSnackbar),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: Insets.xs),
          Text(
            l.reportPlainTextNote,
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
