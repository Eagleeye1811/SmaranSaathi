import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/daily.dart';
import '../../../core/models/medical_report.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../widgets/caregiver_top_bar.dart';

/// Wellbeing page — 7-day mood timeline, reminder adherence, activity level.
/// Mood data comes from the patient's explicit check-in, never AI inference.
class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  // Mock 7-day mood history
  static const List<MoodCheckIn> _moodHistory = <MoodCheckIn>[
    MoodCheckIn(
        dayLabel: 'Monday',
        shortDay: 'Mon',
        moodLabel: 'Calm',
        moodEmoji: '😊',
        moodColor: AppColors.success),
    MoodCheckIn(
        dayLabel: 'Tuesday',
        shortDay: 'Tue',
        moodLabel: 'Happy',
        moodEmoji: '😄',
        moodColor: AppColors.success),
    MoodCheckIn(
        dayLabel: 'Wednesday',
        shortDay: 'Wed',
        moodLabel: 'Okay',
        moodEmoji: '😐',
        moodColor: AppColors.secondary),
    MoodCheckIn(
        dayLabel: 'Thursday',
        shortDay: 'Thu',
        moodLabel: 'Not great',
        moodEmoji: '😔',
        moodColor: AppColors.warning),
    MoodCheckIn(
        dayLabel: 'Friday',
        shortDay: 'Fri',
        moodLabel: 'Calm',
        moodEmoji: '😊',
        moodColor: AppColors.success),
    MoodCheckIn(
        dayLabel: 'Saturday',
        shortDay: 'Sat',
        moodLabel: 'Calm',
        moodEmoji: '😊',
        moodColor: AppColors.success),
    MoodCheckIn(
        dayLabel: 'Sunday',
        shortDay: 'Sun',
        moodLabel: 'Happy',
        moodEmoji: '😄',
        moodColor: AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.accentTint.withValues(alpha: 0.6),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            CaregiverTopBar(
              title: 'Mood & Wellbeing',
              subtitle: '${state.patient.shortName} — daily check-ins',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  // ── Today's mood card ─────────────────────────────────
                  FadeInUp(
                    child: MmCard(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.accentTint,
                          AppColors.backgroundAlt,
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          const Text('😊', style: TextStyle(fontSize: 48)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text("Today's mood",
                                    style: AppText.label),
                                const SizedBox(height: 4),
                                Text(
                                    state.mood?.label ?? 'Not checked in yet',
                                    style: AppText.h3),
                                const SizedBox(height: 4),
                                Text(
                                    'From ${state.patient.shortName}\'s morning check-in',
                                    style: AppText.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Source disclaimer ─────────────────────────────────
                  FadeInUp(
                    delayMs: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryTint,
                        borderRadius: Corners.r(Corners.md),
                        border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mood comes from ${state.patient.shortName}\'s own check-in, not from AI observation.',
                              style: AppText.caption.tint(AppColors.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── 7-day mood timeline ───────────────────────────────
                  FadeInUp(
                    delayMs: 70,
                    child: SectionHeader(
                      title: 'Past 7 Days',
                      icon: Icons.calendar_view_week_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 90,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < _moodHistory.length; i++)
                            _MoodRow(
                              checkin: _moodHistory[i],
                              last: i == _moodHistory.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Reminder adherence ────────────────────────────────
                  FadeInUp(
                    delayMs: 120,
                    child: SectionHeader(
                      title: 'Reminder Adherence',
                      icon: Icons.notifications_active_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 140,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              ProgressRing(
                                value: state.adherencePercent / 100,
                                size: 72,
                                stroke: 8,
                                color: AppColors.seriesTeal,
                                center: Text(
                                    '${state.adherencePercent}%',
                                    style: AppText.caption.wght(800)),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('This week',
                                        style: AppText.label),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${state.remindersDone} of ${state.remindersTotal} reminders acknowledged',
                                        style: AppText.bodySmall),
                                    const SizedBox(height: 8),
                                    TrendBadge(
                                        direction: state.adherencePercent >= 80
                                            ? 1
                                            : state.adherencePercent >= 60
                                                ? 0
                                                : -1,
                                        dense: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          Text('Daily adherence — last 7 days',
                              style: AppText.overline),
                          const SizedBox(height: 10),
                          TrendLineChart(
                            points: state.adherenceWeek,
                            color: AppColors.seriesTeal,
                            valueSuffix: '%',
                            minValue: 50,
                            height: 130,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Activity level ─────────────────────────────────────
                  FadeInUp(
                    delayMs: 170,
                    child: SectionHeader(
                      title: 'Daily Activity',
                      icon: Icons.directions_walk_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 190,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Cognitive activities per day',
                              style: AppText.h3),
                          const SizedBox(height: 4),
                          Text(
                              'Number of activities completed each day — target is 4.',
                              style: AppText.caption),
                          const SizedBox(height: Insets.md),
                          WeekStrip(
                            days: <SeriesPoint>[
                              for (final SeriesPoint p
                                  in state.gamesWeek)
                                SeriesPoint(
                                    p.label, (p.value / 4).clamp(0, 1)),
                            ],
                            color: AppColors.seriesBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Engagement chart ──────────────────────────────────
                  FadeInUp(
                    delayMs: 220,
                    child: SectionHeader(
                      title: 'Engagement Trend',
                      icon: Icons.insights_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 240,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Daily engagement — last 7 days',
                              style: AppText.overline),
                          const SizedBox(height: 10),
                          TrendLineChart(
                            points: state.engagementWeek,
                            color: AppColors.seriesOchre,
                            valueSuffix: '%',
                            minValue: 40,
                            height: 150,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── AI insight ────────────────────────────────────────
                  FadeInUp(
                    delayMs: 270,
                    child: AiInsightBanner(
                      insight:
                          'Over the past 7 days, ${state.patient.shortName} showed a positive mood on '
                          '5 out of 7 days. The one lower mood day did not noticeably affect '
                          'reminder adherence. Engagement remained stable throughout.',
                      color: AppColors.accent,
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
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.checkin, required this.last});
  final MoodCheckIn checkin;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 36,
            child: Text(checkin.shortDay,
                style: AppText.label, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Text(checkin.moodEmoji,
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(checkin.moodLabel,
                style: AppText.body.wght(600)),
          ),
          PillTag(
            label: checkin.moodLabel,
            color: checkin.moodColor,
            dense: true,
          ),
        ],
      ),
    );
  }
}
