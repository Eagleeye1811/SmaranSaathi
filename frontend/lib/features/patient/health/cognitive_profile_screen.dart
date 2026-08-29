import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../intake/intake_kit.dart';
import 'health_widgets.dart';
import 'report_screen.dart';

/// The cognitive profile — the app's answer to "what did you find?".
///
/// Three deliberate choices here:
///
/// * Every domain is shown *against the person's own baseline*, never against
///   a population norm the app does not have.
/// * Patterns are reported as patterns, with the reasoning attached. There are
///   no disease probabilities anywhere in this product; a confident
///   "Alzheimer's 78%" would look impressive in a demo and be indefensible.
/// * The caveat sits next to the numbers, not at the bottom of the scroll.
class CognitiveProfileScreen extends StatelessWidget {
  const CognitiveProfileScreen({super.key, this.firstTime = false, this.onContinue});

  /// Shown immediately after the baseline run, when the framing has to be
  /// "here is your starting point" rather than "here is your result".
  final bool firstTime;
  final VoidCallback? onContinue;

  static Map<CognitiveDomain, String> _shortLabels(AppLocalizations l) =>
      <CognitiveDomain, String>{
        CognitiveDomain.memory: l.cognitiveDomainMemory,
        CognitiveDomain.attention: l.cognitiveDomainAttention,
        CognitiveDomain.reasoning: l.cognitiveDomainLanguage,
        CognitiveDomain.spatial: l.cognitiveDomainSpatial,
        CognitiveDomain.auditory: l.cognitiveDomainAuditory,
        CognitiveDomain.procedural: l.cognitiveDomainExecutive,
      };

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;
    final Map<CognitiveDomain, String> shortLabels = _shortLabels(l);

    final Map<String, int> current = <String, int>{
      for (final DomainReading r in snapshot.readings)
        if (r.hasReading) shortLabels[r.domain]!: r.current!.round(),
    };
    final Map<String, int>? baseline = snapshot.baseline == null
        ? null
        : <String, int>{
            for (final DomainReading r in snapshot.readings)
              if (r.baseline != null) shortLabels[r.domain]!: r.baseline!.round(),
          };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
          children: <Widget>[
            ScreenHeader(
              eyebrow: firstTime ? l.cognitiveBaselineCompleteEyebrow : l.cognitiveProfileEyebrow,
              title: firstTime ? l.cognitiveStartingPointTitle : l.cognitiveProfileTitle,
              subtitle: firstTime
                  ? l.cognitiveStartingPointSubtitle
                  : l.cognitiveProfileSubtitle,
              leading: firstTime
                  ? null
                  : RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
            ),
            const SizedBox(height: Insets.lg),
            if (firstTime) ...<Widget>[
              CompanionSpeech(
                message: l.cognitiveWellDone,
                state: CompanionState.celebrating,
              ),
              const SizedBox(height: Insets.lg),
            ],
            StatusCard(snapshot: snapshot),
            const SizedBox(height: Insets.lg),
            if (current.length >= 3) ...<Widget>[
              MmCard(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  children: <Widget>[
                    Text(l.cognitiveAcrossSixDomains, style: AppText.label),
                    const SizedBox(height: Insets.md),
                    Center(
                      child: RadarChart(
                        values: current,
                        comparison: baseline,
                        size: 250,
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    ChartLegend(entries: <({String label, Color color})>[
                      (label: l.cognitiveChartNow, color: AppColors.seriesTeal),
                      if (baseline != null)
                        (label: l.cognitiveChartBaseline, color: AppColors.seriesBlue),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            SectionHeader(
              title: l.cognitiveByDomainTitle,
              subtitle: firstTime
                  ? l.cognitiveFirstMeasurement
                  : l.cognitiveCurrentScoreChange,
            ),
            const SizedBox(height: Insets.sm),
            for (final DomainReading r in snapshot.readings) DomainRow(reading: r),
            const SizedBox(height: Insets.md),
            _KeyObservation(snapshot: snapshot, firstTime: firstTime),
            const SizedBox(height: Insets.lg),
            SectionHeader(
              title: l.cognitivePatternsObservedTitle,
              subtitle: l.cognitivePatternsObservedSubtitle,
            ),
            const SizedBox(height: Insets.sm),
            for (final ObservedPattern p in snapshot.patterns) PatternRow(pattern: p),
            const SizedBox(height: Insets.sm),
            NotADiagnosisNote(
              message: l.cognitivePatternsDisclaimer,
            ),
            const SizedBox(height: Insets.lg),
            if (firstTime)
              BigButton(
                label: l.cognitiveGoToDashboard,
                icon: Icons.arrow_forward_rounded,
                onPressed: onContinue,
              )
            else
              BigButton(
                label: l.cognitivePrepareSummary,
                icon: Icons.description_outlined,
                onPressed: () => Nav.push(context, const ReportScreen()),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyObservation extends StatelessWidget {
  const _KeyObservation({required this.snapshot, required this.firstTime});

  final MonitoringSnapshot snapshot;
  final bool firstTime;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      color: AppColors.primaryTint,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryDeep),
              const SizedBox(width: Insets.sm),
              Text(l.cognitiveKeyObservation,
                  style: AppText.label.copyWith(color: AppColors.primaryDeep)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            firstTime ? l.cognitiveFirstSessionReference : snapshot.headline,
            style: AppText.bodyLarge.copyWith(height: 1.5),
          ),
          if (!firstTime && snapshot.suggestsClinicalDiscussion) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              l.cognitiveChangeMultipleAreas,
              style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
