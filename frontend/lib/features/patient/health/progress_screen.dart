import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/ai/health_assistant.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../intake/intake_kit.dart';
import '../assistant/assistant_screen.dart';
import 'health_widgets.dart';
import 'report_screen.dart';

/// Trends over time — the screen that shows this is not a one-off test.
///
/// The chart plots weekly means rather than individual sessions, because a
/// session-level line is mostly noise and invites reading meaning into a
/// single bad Tuesday. Weeks with no assessment are left out rather than
/// drawn as zero.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;
    final List<SeriesPoint> weekly = AppState.monitor.weeklySeries(state.sessions);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
          children: <Widget>[
            ScreenHeader(
              eyebrow: 'Monitoring',
              title: 'Your progress',
              subtitle: snapshot.hasBaseline
                  ? 'Weekly averages against your baseline'
                  : 'Complete a baseline to start tracking',
              leading: embedded
                  ? null
                  : RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
            ),
            const SizedBox(height: Insets.lg),
            if (weekly.length > 1) ...<Widget>[
              MmCard(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Wrap, not Row: the label and the baseline pill together
                    // exceed a small phone once the type scales up.
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text('Overall activity score', style: AppText.label),
                        if (snapshot.overallBaseline != null)
                          PillTag(
                            label: 'Baseline ${snapshot.overallBaseline!.round()}',
                            color: AppColors.secondary,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    TrendLineChart(
                      points: weekly,
                      labelEvery: weekly.length > 8 ? 2 : 1,
                      minValue: 40,
                      color: trendColor(snapshot.overallTrend),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    label: 'Adherence',
                    value: '${snapshot.adherencePercent}%',
                    meter: snapshot.adherencePercent / 100,
                    icon: Icons.event_available_rounded,
                    compact: true,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: StatTile(
                    label: 'Consistency',
                    value: '${snapshot.consistency}%',
                    meter: snapshot.consistency / 100,
                    color: AppColors.secondary,
                    icon: Icons.timeline_rounded,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            StatTile(
              label: 'Reported independence in daily activities',
              value: '${snapshot.functionalIndependence}%',
              meter: snapshot.functionalIndependence / 100,
              color: AppColors.accent,
              icon: Icons.home_work_outlined,
            ),
            const SizedBox(height: Insets.lg),
            SectionHeader(
              title: 'By domain',
              subtitle: '${snapshot.assessmentsCompleted} of '
                  '${snapshot.assessmentsExpected} weeks assessed',
            ),
            const SizedBox(height: Insets.sm),
            for (final DomainReading r in snapshot.readings)
              if (r.hasReading) DomainRow(reading: r),
            const SizedBox(height: Insets.md),
            MmCard(
              color: AppColors.primaryTint,
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Why did my score change?', style: AppText.h3),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Sleep, mood, illness, medication and plain tiredness all move '
                    'these numbers. Ask the companion to read your own record and '
                    'explain what it sees.',
                    style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5),
                  ),
                  const SizedBox(height: Insets.md),
                  SoftButton(
                    label: 'Explain my change',
                    icon: Icons.help_outline_rounded,
                    filled: true,
                    onPressed: () => Nav.push(
                      context,
                      const AssistantScreen(initialAction: HealthQuickAction.whyChanged),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            const NotADiagnosisNote(),
            const SizedBox(height: Insets.md),
            BigButton(
              label: 'Prepare a summary for my doctor',
              icon: Icons.description_outlined,
              outlined: true,
              onPressed: () => Nav.push(context, const ReportScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
