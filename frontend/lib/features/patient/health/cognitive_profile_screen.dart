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

  static const Map<CognitiveDomain, String> _shortLabels = <CognitiveDomain, String>{
    CognitiveDomain.memory: 'Memory',
    CognitiveDomain.attention: 'Attention',
    CognitiveDomain.reasoning: 'Language',
    CognitiveDomain.spatial: 'Spatial',
    CognitiveDomain.auditory: 'Auditory',
    CognitiveDomain.procedural: 'Executive',
  };

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;

    final Map<String, int> current = <String, int>{
      for (final DomainReading r in snapshot.readings)
        if (r.hasReading) _shortLabels[r.domain]!: r.current!.round(),
    };
    final Map<String, int>? baseline = snapshot.baseline == null
        ? null
        : <String, int>{
            for (final DomainReading r in snapshot.readings)
              if (r.baseline != null) _shortLabels[r.domain]!: r.baseline!.round(),
          };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
          children: <Widget>[
            ScreenHeader(
              eyebrow: firstTime ? 'Baseline complete' : 'Cognitive profile',
              title: firstTime ? 'Your starting point' : 'Your cognitive profile',
              subtitle: firstTime
                  ? 'Everything from here is compared with these six numbers.'
                  : 'Current performance against your own baseline.',
              leading: firstTime
                  ? null
                  : RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
            ),
            const SizedBox(height: Insets.lg),
            if (firstTime) ...<Widget>[
              const CompanionSpeech(
                message: 'Well done. That is your starting point recorded.',
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
                    Text('Across the six domains', style: AppText.label),
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
                      (label: 'Now', color: AppColors.seriesTeal),
                      if (baseline != null)
                        (label: 'Baseline', color: AppColors.seriesBlue),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            SectionHeader(
              title: 'By domain',
              subtitle: firstTime
                  ? 'Your first measurement in each area'
                  : 'Current score, and change from baseline',
            ),
            const SizedBox(height: Insets.sm),
            for (final DomainReading r in snapshot.readings) DomainRow(reading: r),
            const SizedBox(height: Insets.md),
            _KeyObservation(snapshot: snapshot, firstTime: firstTime),
            const SizedBox(height: Insets.lg),
            SectionHeader(
              title: 'Patterns observed',
              subtitle: 'What was reported and measured, grouped',
            ),
            const SizedBox(height: Insets.sm),
            for (final ObservedPattern p in snapshot.patterns) PatternRow(pattern: p),
            const SizedBox(height: Insets.sm),
            const NotADiagnosisNote(
              message:
                  'These are patterns in what you reported and what the activities '
                  'measured. This app deliberately does not estimate the likelihood '
                  'of any specific condition — that requires a clinical assessment.',
            ),
            const SizedBox(height: Insets.lg),
            if (firstTime)
              BigButton(
                label: 'Go to my dashboard',
                icon: Icons.arrow_forward_rounded,
                onPressed: onContinue,
              )
            else
              BigButton(
                label: 'Prepare a summary for my doctor',
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
              Text('Key observation', style: AppText.label.copyWith(color: AppColors.primaryDeep)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            firstTime
                ? 'This first session is your reference point. A single set of '
                    'scores says very little on its own — what carries meaning is '
                    'how they move over the coming weeks.'
                : snapshot.headline,
            style: AppText.bodyLarge.copyWith(height: 1.5),
          ),
          if (!firstTime && snapshot.suggestsClinicalDiscussion) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              'Change has been observed in more than one area, alongside reported '
              'difficulty with daily activities. That combination is worth '
              'discussing with a healthcare professional.',
              style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
