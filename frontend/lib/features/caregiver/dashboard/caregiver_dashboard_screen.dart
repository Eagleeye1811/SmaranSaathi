import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/models/game.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../intake/intake_flow.dart';
import '../../../data/mock/mock_data.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/safety.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../patient_view_screen.dart';
import '../pairing_widgets.dart';

/// The caregiver's home: what needs attention, then how the day has gone.
///
/// Ordered by what a caregiver opens this screen to find out, most urgent
/// first: *is something wrong right now* → *has today happened* → *is the
/// trend going the right way* → *what exactly happened* → *what is still
/// owed*. Anything that answered none of those questions has been taken off:
/// the patient hero card (the name lives in the greeting, the profile has its
/// own tab), the second copy of today's numbers, the written-in-advance
/// "alerts" that said the same thing whatever the data did, and the
/// personalisation blurb.
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key, this.onOpenTab});

  /// Index into `CaregiverShell`'s destinations: 1 activities, 2 mood,
  /// 4 safety, 7 reminders, 8 patient profile.
  final ValueChanged<int>? onOpenTab;

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  ValueChanged<int>? get onOpenTab => widget.onOpenTab;

  String _greeting(AppLocalizations l) {
    final int h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning;
    if (h < 17) return l.greetingAfternoon;
    return l.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<Reminder> due =
        state.reminders.where((Reminder r) => !r.done).toList();

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.8),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
          children: <Widget>[
            if (state.offline)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: OfflineBanner(pending: state.pendingSync),
              ),

            // ── Who, and when ─────────────────────────────────────────────
            FadeInUp(child: _Header(state: state, greeting: _greeting(l))),
            const SizedBox(height: Insets.lg),

            // ── Somebody is standing there holding a phone ────────────────
            const PairingRequestBanner(),

            // ── Needs attention ───────────────────────────────────────────
            //
            // Only ever shown when something is genuinely true right now, so
            // that seeing anything here means something.
            FadeInUp(
              delayMs: 30,
              child: _NeedsAttention(state: state, onOpenTab: onOpenTab),
            ),

            // ── Today ─────────────────────────────────────────────────────
            FadeInUp(
              delayMs: 60,
              child: SectionHeader(
                title: l.caregiverTodaysOverviewTitle,
                icon: Icons.today_rounded,
              ),
            ),
            FadeInUp(
              delayMs: 70,
              child: _TodayGrid(state: state, onOpenTab: onOpenTab),
            ),
            const SizedBox(height: Insets.lg),

            // ── Safe zone ─────────────────────────────────────────────────
            //
            // Its own section rather than a tile in the grid above: "where
            // are they" is a different question from "how did today go", it
            // has an action attached when no zone exists yet, and a boundary
            // the family has moved away from is worth seeing spelled out.
            FadeInUp(
              delayMs: 85,
              child: SectionHeader(
                title: 'Safe zone',
                icon: Icons.location_on_rounded,
                action: 'Open map',
                onAction: () => onOpenTab?.call(3),
              ),
            ),
            FadeInUp(
              delayMs: 90,
              child: _SafeZoneSection(state: state, onOpenTab: onOpenTab),
            ),
            const SizedBox(height: Insets.lg),

            // ── What is still owed ────────────────────────────────────────
            FadeInUp(
              delayMs: 100,
              child: SectionHeader(
                title: l.caregiverRemindersTitle,
                icon: Icons.notifications_active_rounded,
                action: l.caregiverManageAction,
                onAction: () => onOpenTab?.call(6),
              ),
            ),
            FadeInUp(delayMs: 110, child: _RemindersCard(state: state, due: due)),
            const SizedBox(height: Insets.lg),

            // ── Progress ──────────────────────────────────────────────────
            //
            // Everything from here down used to be two separate tabs of its
            // own — Patient Progress behind the patient's name, and Cognitive
            // Activities. With one patient to one caregiver neither had a
            // second subject to distinguish it from this screen, so both have
            // been folded in and the analytics simply continue below the day.
            //
            // The weekly series are the app's own: the previous six days come
            // from the sample history, today's point is live. Finish an
            // activity in the patient app and the last point on every chart
            // here moves.
            FadeInUp(
              delayMs: 130,
              child: SectionHeader(
                title: l.caregiverCognitiveProgressTitle,
                icon: Icons.show_chart_rounded,
              ),
            ),
            FadeInUp(delayMs: 140, child: _ProgressSummary(state: state)),
            const SizedBox(height: Insets.md),
            FadeInUp(
              delayMs: 150,
              child: _ChartCard(
                title: l.caregiverChartEngagementTitle,
                caption: l.caregiverChartEngagementCaption,
                child: TrendLineChart(
                  points: state.engagementWeek,
                  color: AppColors.seriesTeal,
                  valueSuffix: '%',
                  minValue: 40,
                  height: 170,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            FadeInUp(
              delayMs: 160,
              child: _ChartCard(
                title: l.caregiverChartActivitiesTitle,
                caption: l.caregiverChartActivitiesCaption,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: WeekStrip(
                    days: <SeriesPoint>[
                      for (final SeriesPoint p in state.gamesWeek)
                        SeriesPoint(p.label, (p.value / 4).clamp(0, 1)),
                    ],
                    color: AppColors.seriesBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            FadeInUp(
              delayMs: 170,
              child: _ChartCard(
                title: l.caregiverStatReminderAdherence,
                caption: l.caregiverChartAdherenceCaption,
                child: TrendLineChart(
                  points: state.adherenceWeek,
                  color: AppColors.seriesClay,
                  valueSuffix: '%',
                  minValue: 50,
                  height: 150,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            FadeInUp(
              delayMs: 180,
              child: _ChartCard(
                title: l.caregiverChartMemoryTitle,
                caption: l.caregiverChartMemoryCaption,
                child: BarSeriesChart(
                  points: state.memoryActivityWeek,
                  color: AppColors.seriesPlum,
                  maxValue: 6,
                  height: 150,
                  showValues: true,
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),

            // ── By activity ───────────────────────────────────────────────
            FadeInUp(
              delayMs: 200,
              child: SectionHeader(
                title: l.caregiverChartScoreTitle,
                icon: Icons.bar_chart_rounded,
                subtitle: l.caregiverChartScoreCaption,
              ),
            ),
            FadeInUp(delayMs: 210, child: _ScoreByActivity(state: state)),
            const SizedBox(height: Insets.lg),

            // ── Where the difficulty sits ─────────────────────────────────
            FadeInUp(
              delayMs: 260,
              child: SectionHeader(
                title: l.caregiverAdaptiveDifficultyTitle,
                icon: Icons.tune_rounded,
                subtitle: l.caregiverAdaptiveDifficultySubtitle,
              ),
            ),
            FadeInUp(delayMs: 270, child: _DifficultyList(state: state)),
            const SizedBox(height: Insets.lg),

            // ── Session history ───────────────────────────────────────────
            //
            // Today's sessions sit at the top of it, labelled as today, so
            // this is both "what happened just now" and "what happened this
            // week" without being two lists that disagree.
            FadeInUp(
              delayMs: 290,
              child: SectionHeader(
                title: l.caregiverRecentSessionsTitle,
                icon: Icons.history_rounded,
              ),
            ),
            FadeInUp(delayMs: 300, child: _SessionHistory(state: state, l: l)),
            const SizedBox(height: Insets.lg),

            // ── Into the patient's own app ────────────────────────────────
            //
            // Still one tap away, but a quiet row rather than the full-width
            // hero it used to be: it is a thing a caregiver does occasionally,
            // not the first thing they came here to read.
            if (state.hasPatientProfile)
              FadeInUp(
                delayMs: 210,
                child: _OpenPatientAppRow(name: state.patient.shortName),
              ),
          ],
        ),
      ),
    );
  }
}

/// Greeting, date, and who is being cared for — the patient hero card's job,
/// in three lines instead of a screenful.
class _Header extends StatelessWidget {
  const _Header({required this.state, required this.greeting});

  final AppState state;
  final String greeting;

  String _dateLabel(AppLocalizations l) {
    final List<String> days = <String>[
      l.caregiverWeekdayMon, l.caregiverWeekdayTue, l.caregiverWeekdayWed, l.caregiverWeekdayThu,
      l.caregiverWeekdayFri, l.caregiverWeekdaySat, l.caregiverWeekdaySun,
    ];
    final DateTime n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${monthShortLabel(l, n.month)} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                state.hasCaregiverProfile
                    ? '$greeting, ${state.caregiverName}'
                    : greeting,
                style: AppText.h1.sized(26),
              ),
              const SizedBox(height: 4),
              Text(_dateLabel(l), style: AppText.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: Insets.sm),
        const SceneImage(
          sceneId: 'portrait_priya',
          size: 50,
          circle: true,
          borderColor: Colors.white,
          borderWidth: 3,
        ),
      ],
    );
  }
}

/// The only things on this screen allowed to shout, and only when true.
///
/// Everything here is derived from live state — a wandering alert, a low mood
/// logged today, a day with nothing done by the evening, a safe zone never
/// set up. When none of them hold, the section renders nothing at all rather
/// than manufacturing reassurance.
class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.state, required this.onOpenTab});

  final AppState state;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final SafeZoneEvent? alert = state.activeWanderAlert;
    final List<Widget> items = <Widget>[];

    if (alert != null) {
      items.add(_AttentionRow(
        color: AppColors.danger,
        icon: Icons.warning_amber_rounded,
        title: '${state.patient.shortName} has left ${alert.zoneLabel}',
        body: '${alert.distanceMetres.round()} m outside. Open the map to see where.',
        onTap: () => onOpenTab?.call(3),
      ));
    }

    // The onboarding is no longer a gate in front of a signed-in caregiver
    // (see `CaregiverEntry`), so this is what keeps offering it. Top of the
    // list while it is unanswered, because almost everything below the fold
    // is derived from answers it has not been given yet.
    if (!state.intake.isComplete) {
      items.add(_AttentionRow(
        color: AppColors.primary,
        icon: Icons.assignment_outlined,
        title: 'Finish setting up',
        body: 'A few questions about how they are managing day to day. The '
            'activities and the reports are built from the answers.',
        onTap: () => Nav.open(
          context,
          IntakeFlowScreen(onFinished: () => Navigator.of(context).maybePop()),
        ),
      ));
    }

    if (state.mood == MoodLevel.low) {
      items.add(_AttentionRow(
        color: AppColors.secondary,
        icon: Icons.favorite_rounded,
        title: 'Low mood logged today',
        body: 'Activities have switched to gentler, more familiar ones. A call may help.',
        onTap: () => onOpenTab?.call(1),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? Insets.lg : 10),
            child: items[i],
          ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.md),
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.body.wght(800)),
                const SizedBox(height: 4),
                Text(body, style: AppText.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 20, color: color),
        ],
      ),
    );
  }
}

/// Today's four numbers, once. Each tile is the way in to the screen that
/// owns it, so the grid doubles as navigation rather than being a dead end.
class _TodayGrid extends StatelessWidget {
  const _TodayGrid({required this.state, required this.onOpenTab});

  final AppState state;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int done = state.completedToday.length;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth >= 600;
        final double w = wide
            ? (c.maxWidth - Insets.md * 3) / 4
            : (c.maxWidth - Insets.md) / 2;

        return Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: <Widget>[
            _GlanceTile(
              width: w,
              label: l.caregiverStatActivitiesCompleted,
              value: '$done/4',
              meter: done / 4,
              icon: Icons.extension_rounded,
              color: done >= 2 ? AppColors.seriesTeal : AppColors.seriesOchre,
            ),
            _GlanceTile(
              width: w,
              label: l.caregiverMedicationRemindersLabel,
              value: '${state.medicineDone}/${state.medicineTotal}',
              meter: state.medicineTotal == 0
                  ? 0
                  : state.medicineDone / state.medicineTotal,
              icon: Icons.medication_liquid_rounded,
              color: AppColors.terracotta,
              onTap: () => onOpenTab?.call(6),
            ),
            _GlanceTile(
              width: w,
              label: l.caregiverMoodLabel,
              value: state.mood == null
                  ? l.caregiverNotRecorded
                  : '${state.mood!.emoji} ${state.mood!.label}',
              icon: Icons.sentiment_satisfied_alt_rounded,
              color: state.mood == MoodLevel.low
                  ? AppColors.secondary
                  : (state.mood == null ? AppColors.inkMuted : AppColors.success),
              onTap: () => onOpenTab?.call(1),
            ),
            _GlanceTile(
              width: w,
              label: 'Engagement today',
              value: '${state.todayEngagement}%',
              meter: state.todayEngagement / 100,
              icon: Icons.local_fire_department_rounded,
              color: AppColors.primary,
            ),
          ],
        );
      },
    );
  }
}

class _GlanceTile extends StatelessWidget {
  const _GlanceTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.meter,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Null for a tile whose detail is further down this same screen rather
  /// than on a tab of its own — it stays a readout, not a dead link.
  final VoidCallback? onTap;

  /// 0–1. Null for a tile whose value is not a fraction of anything.
  final double? meter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: MmCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: Corners.r(Corners.sm),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.caption.wght(700).tint(AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Text(
              value,
              style: AppText.h3.sized(17).wght(800).tint(AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 5,
              child: meter == null
                  ? null
                  : MeterBar(value: meter!.clamp(0, 1), color: color, height: 5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where they are, and whether the boundary exists at all.
///
/// Three states, because the three mean genuinely different things to the
/// person reading: nobody has drawn a zone yet (so no alert can ever fire —
/// the one case that needs a button), a zone exists and they are inside it,
/// or they have left it and the distance matters.
class _SafeZoneSection extends StatelessWidget {
  const _SafeZoneSection({required this.state, required this.onOpenTab});

  final AppState state;
  final ValueChanged<int>? onOpenTab;

  /// "12 min ago" — how long the person has been outside, which is the part
  /// of a wandering alert that decides what the caregiver does next.
  String _sinceLabel(SafeZoneEvent event) {
    final DateTime? at = event.at;
    if (at == null) return '';
    final Duration d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final SafeZone? zone = state.safeZone;
    final SafeZoneEvent? alert = state.activeWanderAlert;

    // ── Nobody has drawn one ────────────────────────────────────────────
    if (zone == null) {
      return MmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SoftIcon(
                  icon: Icons.add_location_alt_outlined,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('No safe zone yet', style: AppText.body.wght(800)),
                      const SizedBox(height: 3),
                      Text(
                        'Draw a boundary around home and MemoryMitra will tell you '
                        'if ${state.patient.shortName} leaves it.',
                        style: AppText.bodySmall.tint(AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            BigButton(
              label: 'Set a safe zone',
              icon: Icons.map_outlined,
              height: 52,
              onPressed: () => onOpenTab?.call(3),
            ),
          ],
        ),
      );
    }

    final bool wandering = alert != null;
    final Color accent = wandering ? AppColors.danger : AppColors.success;

    return MmCard(
      onTap: () => onOpenTab?.call(3),
      color: wandering ? AppColors.dangerTint : null,
      border: wandering ? Border.all(color: AppColors.danger.withValues(alpha: 0.3)) : null,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(
                icon: wandering ? Icons.warning_amber_rounded : Icons.location_on_rounded,
                color: accent,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      wandering
                          ? '${state.patient.shortName} has left ${alert.zoneLabel}'
                          : 'Inside ${zone.label}',
                      style: AppText.h3.sized(17).tint(wandering ? AppColors.danger : AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      wandering
                          ? '${alert.distanceMetres.round()} m outside · ${_sinceLabel(alert)}'
                          : '${zone.radiusMetres.round()} m around ${zone.label}',
                      style: AppText.bodySmall.tint(AppColors.inkSoft),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PillTag(
                label: wandering ? 'Outside' : 'Safe',
                color: accent,
                dense: true,
              ),
            ],
          ),
          // A quiet footer, and the only place the boundary's own history
          // shows up on this screen.
          if (state.safeZoneEvents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(color: AppColors.hairline, height: 1),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Icon(Icons.history_rounded, size: 15, color: AppColors.inkMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Last boundary event ${_sinceLabel(state.safeZoneEvents.first)}',
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('Map',
                    style: AppText.caption.wght(800).tint(AppColors.primary)),
                const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The headline numbers: how engaged, how accurate, how much there is to go
/// on. The third matters as much as the first two — a 92% accuracy drawn
/// from two sessions is not the same claim as one drawn from sixty.
class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final List<SeriesPoint> week = state.engagementWeek;
    final double weekAvg =
        week.fold<double>(0, (double a, SeriesPoint p) => a + p.value) / week.length;

    // The back half of the week against the front half — a single day's dip
    // should not read as a decline, and a caregiver cannot act on noise.
    final int split = week.length ~/ 2;
    final double early =
        week.take(split).fold<double>(0, (double a, SeriesPoint p) => a + p.value) / split;
    final double later =
        week.skip(split).fold<double>(0, (double a, SeriesPoint p) => a + p.value) /
            (week.length - split);
    final double delta = later - early;
    final bool flat = delta.abs() < 2;

    return MmCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[AppColors.primaryTint, AppColors.backgroundAlt],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _BigStat(
                  label: 'Engagement this week',
                  value: '${weekAvg.round()}%',
                  color: AppColors.primary,
                  footnote: flat
                      ? 'Steady across the week'
                      : '${delta > 0 ? '+' : '−'}${delta.abs().round()} pts vs early week',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BigStat(
                  label: 'Average accuracy',
                  value: '${state.averageAccuracy().round()}%',
                  color: AppColors.seriesOchre,
                  footnote: '${state.gamesCompletedTotal()} sessions recorded',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.color,
    required this.footnote,
  });

  final String label;
  final String value;
  final Color color;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppText.label, maxLines: 2),
        const SizedBox(height: 6),
        Text(value, style: AppText.statLarge.tint(color)),
        const SizedBox(height: 4),
        Text(footnote, style: AppText.caption, maxLines: 2),
      ],
    );
  }
}

/// Nothing recorded yet — said once, plainly, rather than as a full-height
/// illustration for an absence.
class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SoftIcon(
          icon: Icons.hourglass_empty_rounded,
          color: AppColors.inkMuted,
          size: 44,
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.caregiverNothingCompletedTitle, style: AppText.body.wght(700)),
              const SizedBox(height: 3),
              Text(l.caregiverNothingCompletedBody, style: AppText.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's adherence, and the next couple of things still owed.
class _RemindersCard extends StatelessWidget {
  const _RemindersCard({required this.state, required this.due});

  final AppState state;
  final List<Reminder> due;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                value: state.adherencePercent / 100,
                size: 62,
                stroke: 7,
                color: AppColors.seriesBlue,
                center: Text('${state.adherencePercent}%',
                    style: AppText.caption.wght(800)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.caregiverAdherenceTodayLabel, style: AppText.body.wght(800)),
                    const SizedBox(height: 3),
                    Text(
                      l.caregiverRemindersMarkedDone(
                          state.remindersDone, state.remindersTotal),
                      style: AppText.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final Reminder r in due.take(2))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ListRow(
                padding: EdgeInsets.zero,
                leading: SoftIcon(icon: r.kind.icon, color: AppColors.secondary, size: 42),
                title: r.title,
                subtitle: '${r.time} · ${r.kind.localizedLabel(l)}',
                trailing: SoftButton(
                  label: l.caregiverDoneButton,
                  color: AppColors.success,
                  onPressed: () => state.toggleReminder(r.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled chart with a one-line explanation of what it plots.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.caption, required this.child});

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppText.h3),
          const SizedBox(height: 3),
          Text(caption, style: AppText.caption),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}

/// Average score per activity, across every session of it.
///
/// Only scored activities: Mood Canvas has no score to plot, and a zero bar
/// for it would read as "she did badly at it" rather than "it is not that
/// sort of activity".
class _ScoreByActivity extends StatelessWidget {
  const _ScoreByActivity({required this.state});

  final AppState state;

  static String _shortName(AppLocalizations l, GameId id) => switch (id) {
        GameId.procedure => l.caregiverChartLabelProcedure,
        GameId.story => l.caregiverChartLabelStory,
        GameId.familiarPlace => l.caregiverChartLabelPlace,
        GameId.melody => l.caregiverChartLabelMelody,
        GameId.weaves => l.caregiverChartLabelWeaves,
        GameId.memoryCards => l.caregiverChartLabelCards,
        GameId.villageMarket => l.caregiverChartLabelMarket,
        // Never charted — callers filter to `hasLevels` activities.
        GameId.moodCanvas => l.gameMoodCanvasName,
      };

  static double _averageFor(AppState state, GameId id) {
    final List<GameSession> list = state.sessionsFor(id);
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (double a, GameSession s) => a + s.performance.overall) /
        list.length;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<GameDefinition> scored =
        MockData.games.where((GameDefinition g) => g.hasLevels).toList(growable: false);

    return MmCard(
      child: BarSeriesChart(
        points: <SeriesPoint>[
          for (final GameDefinition g in scored)
            SeriesPoint(_shortName(l, g.id), _averageFor(state, g.id)),
        ],
        color: AppColors.seriesTeal,
        height: 170,
        showValues: true,
      ),
    );
  }
}

/// What level the adaptive engine has settled each activity at.
class _DifficultyList extends StatelessWidget {
  const _DifficultyList({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<GameDefinition> scored =
        MockData.games.where((GameDefinition g) => g.hasLevels).toList(growable: false);

    return MmCard(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < scored.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == scored.length - 1 ? 0 : 16),
              child: Row(
                children: <Widget>[
                  SceneImage(sceneId: scored[i].sceneId, size: 42, radius: Corners.sm),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(scored[i].localizedName(l),
                            style: AppText.body.wght(700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          localizedLevelDescription(
                              l, scored[i].id, state.levelOf(scored[i].id)),
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(l.gamesLevel(state.levelOf(scored[i].id)),
                          style: AppText.caption.wght(800)),
                      const SizedBox(height: 5),
                      DifficultyDots(
                        level: state.levelOf(scored[i].id),
                        color: scored[i].accent,
                        size: 7,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The last ten sessions, newest first, each labelled by the day it happened
/// on — so today's activity appears here the moment it is finished.
class _SessionHistory extends StatelessWidget {
  const _SessionHistory({required this.state, required this.l});

  final AppState state;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final List<GameSession> recent = state.sessions.take(10).toList();
    return MmCard(
      child: recent.isEmpty
          ? _EmptyToday(l: l)
          : Column(
              children: <Widget>[
                for (int i = 0; i < recent.length; i++)
                  _HistoryRow(session: recent[i], last: i == recent.length - 1),
              ],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session, required this.last});

  final GameSession session;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final GameDefinition g = MockData.game(session.gameId);
    final String when = session.dayOffset == 0
        ? l.todayTitle
        : (session.dayOffset == 1 ? l.caregiverYesterday : l.caregiverDaysAgo(session.dayOffset));

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: g.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(g.localizedName(l),
                    style: AppText.body.wght(700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  l.caregiverSessionMeta(
                    when,
                    session.timeLabel,
                    l.gamesLevel(session.level),
                    session.performance.hintsUsed == 1
                        ? l.caregiverHintsUsedOne(session.performance.hintsUsed)
                        : l.caregiverHintsUsedMany(session.performance.hintsUsed),
                  ),
                  style: AppText.caption,
                ),
                // Village Market repurposes `focus` as a budget-restraint
                // figure (see `VillageMarketGame._budgetRestraintScore`) —
                // surfaced here, the one per-session (not averaged)
                // clinician-facing view, and nowhere on the patient's own
                // result screen.
                if (session.gameId == GameId.villageMarket)
                  Text(
                    l.caregiverVillageMarketBudgetNote(session.performance.focus.round()),
                    style: AppText.caption.tint(AppColors.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${session.performance.overall}%',
              style: AppText.body.wght(800).tint(g.accent)),
        ],
      ),
    );
  }
}

/// The doorway from the caregiver's app into the patient's.
///
/// Deliberately unguarded: the caregiver has already authenticated once, and
/// the person whose app this is cannot be expected to hold a second password.
/// Putting a lock here would mean the only people it ever stopped are the two
/// it is meant to serve.
///
/// The username is claimed here rather than during the onboarding because
/// this is the moment it becomes meaningful: the caregiver is about to look
/// at an account that, from now on, the patient can also reach from their own
/// phone.
Future<void> _openPatientApp(BuildContext context) async {
  final AppState state = AppScope.read(context);
  if (!state.hasPatientUsername) {
    final String? claimed = await claimPatientUsername(context);
    if (claimed == null || !context.mounted) return;
    state.setPatientUsername(claimed);
  }
  if (context.mounted) await Nav.open(context, const PatientViewScreen());
}

class _OpenPatientAppRow extends StatelessWidget {
  const _OpenPatientAppRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // The app's own green, like every other actionable surface on this
    // screen. The terracotta this used to wear is the alert palette — it read
    // as something being wrong, on a card that is simply a doorway.
    return MmCard(
      onTap: () => _openPatientApp(context),
      color: AppColors.primaryTint,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const SoftIcon(
            icon: Icons.switch_account_rounded,
            size: 42,
            color: AppColors.primary,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(l.caregiverViewPatientTitle(name), style: AppText.body.wght(800)),
                const SizedBox(height: 2),
                Text(l.caregiverViewPatientBody,
                    style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
