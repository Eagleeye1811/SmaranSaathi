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
import '../../../data/mock/mock_data.dart';
import '../../../core/models/safety.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/mock_translator.dart';
import '../onboarding/patient_onboarding_flow.dart';
import '../../patient/settings/language_selector.dart';
import '../safety/safe_zone_screen.dart';
import '../widgets/caregiver_top_bar.dart';

/// The caregiver's home: how the day has gone, and what needs attention.
class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

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
    final List<GameSession> today =
        state.sessions.where((GameSession s) => s.dayOffset == 0).toList();

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.8),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            CaregiverTopBar(subtitle: l.caregiverRoleLabel),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  if (state.offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: OfflineBanner(pending: state.pendingSync),
                    ),

                  FadeInUp(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('${_greeting(l)}, ${MockData.caregiverName}',
                                  style: AppText.h1.sized(26)),
                              const SizedBox(height: 4),
                              Text(_dateLabel(l), style: AppText.bodySmall),
                            ],
                          ),
                        ),
                        const SceneImage(
                          sceneId: 'portrait_priya',
                          size: 50,
                          circle: true,
                          borderColor: Colors.white,
                          borderWidth: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Patient hero ──────────────────────────────────────
                  FadeInUp(
                    delayMs: 50,
                    child: _PatientCard(
                      state: state,
                      onOpen: () => onOpenTab?.call(1),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Safe zone ─────────────────────────────────────────
                  //
                  // Directly under the patient card, above the day's numbers:
                  // "where are they" outranks "how did the puzzles go" for a
                  // caregiver opening this screen worried.
                  FadeInUp(delayMs: 70, child: _SafeZoneCard(state: state)),
                  const SizedBox(height: Insets.lg),

                  // ── Today's overview ──────────────────────────────────
                  FadeInUp(
                    delayMs: 90,
                    child: SectionHeader(
                        title: l.caregiverTodaysOverviewTitle, icon: Icons.insights_rounded),
                  ),
                  FadeInUp(
                    delayMs: 110,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          OverviewRow(
                            label: l.caregiverStatEngagement,
                            value: '${state.todayEngagement}%',
                            meter: state.todayEngagement / 100,
                            icon: Icons.psychology_alt_rounded,
                          ),
                          const Divider(color: AppColors.hairline),
                          OverviewRow(
                            label: l.caregiverStatActivitiesCompleted,
                            value: '${state.completedToday.length}/4',
                            meter: state.completedToday.length / 4,
                            color: AppColors.secondary,
                            icon: Icons.extension_rounded,
                          ),
                          const Divider(color: AppColors.hairline),
                          OverviewRow(
                            label: l.caregiverMedicationRemindersLabel,
                            value: '${state.medicineDone}/${state.medicineTotal}',
                            meter: state.medicineTotal == 0
                                ? 0
                                : state.medicineDone / state.medicineTotal,
                            color: AppColors.terracotta,
                            icon: Icons.medication_liquid_rounded,
                          ),
                          const Divider(color: AppColors.hairline),
                          OverviewRow(
                            label: l.caregiverMoodLabel,
                            value: state.mood?.label ?? l.caregiverNotRecorded,
                            color: state.mood == MoodLevel.low
                                ? AppColors.secondary
                                : AppColors.success,
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            badge: state.mood == null
                                ? PillTag(
                                    label: l.caregiverNotRecorded,
                                    color: AppColors.inkMuted,
                                    dense: true)
                                : PillTag(
                                    label: '${state.mood!.emoji}  ${state.mood!.label}',
                                    color: state.mood == MoodLevel.low
                                        ? AppColors.secondary
                                        : AppColors.success,
                                    dense: true,
                                  ),
                          ),
                          const Divider(color: AppColors.hairline),
                          OverviewRow(
                            label: l.caregiverLastActiveLabel,
                            value: state.lastActiveLabel,
                            color: AppColors.inkSoft,
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Cognitive progress ────────────────────────────────
                  FadeInUp(
                    delayMs: 140,
                    child: SectionHeader(
                      title: l.caregiverCognitiveProgressTitle,
                      icon: Icons.show_chart_rounded,
                      action: l.caregiverDetailsAction,
                      onAction: () => onOpenTab?.call(2),
                    ),
                  ),
                  FadeInUp(
                    delayMs: 160,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: StatTile(
                                  label: l.caregiverEngagementThisWeek,
                                  value: '${state.todayEngagement}',
                                  suffix: '%',
                                  color: AppColors.seriesTeal,
                                ),
                              ),
                              Expanded(
                                child: StatTile(
                                  label: l.caregiverStatAccuracy,
                                  value: state.averageAccuracy().round().toString(),
                                  suffix: '%',
                                  color: AppColors.seriesOchre,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          Text(l.caregiverDailyEngagementWeekLabel,
                              style: AppText.overline),
                          const SizedBox(height: 10),
                          TrendLineChart(
                            points: state.engagementWeek,
                            color: AppColors.seriesTeal,
                            valueSuffix: '%',
                            minValue: 40,
                            height: 158,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Today's activities ────────────────────────────────
                  FadeInUp(
                    delayMs: 190,
                    child: SectionHeader(
                        title: l.caregiverTodaysActivitiesTitle, icon: Icons.today_rounded),
                  ),
                  FadeInUp(
                    delayMs: 200,
                    child: MmCard(
                      child: today.isEmpty
                          ? Column(
                              children: <Widget>[
                                const SoftIcon(
                                  icon: Icons.hourglass_empty_rounded,
                                  color: AppColors.inkMuted,
                                  size: 54,
                                ),
                                const SizedBox(height: 12),
                                Text(l.caregiverNothingCompletedTitle,
                                    style: AppText.body.wght(700)),
                                const SizedBox(height: 4),
                                Text(
                                  l.caregiverNothingCompletedBody,
                                  textAlign: TextAlign.center,
                                  style: AppText.bodySmall,
                                ),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                for (int i = 0; i < today.length; i++)
                                  _SessionRow(
                                    session: today[i],
                                    last: i == today.length - 1,
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Reminders ─────────────────────────────────────────
                  FadeInUp(
                    delayMs: 220,
                    child: SectionHeader(
                      title: l.caregiverRemindersTitle,
                      icon: Icons.notifications_active_rounded,
                      action: l.caregiverManageAction,
                      onAction: () => onOpenTab?.call(3),
                    ),
                  ),
                  FadeInUp(
                    delayMs: 230,
                    child: MmCard(
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
                          const SizedBox(height: Insets.md),
                          for (final Reminder r
                              in state.reminders.where((Reminder r) => !r.done).take(2))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ListRow(
                                padding: EdgeInsets.zero,
                                leading: SoftIcon(
                                  icon: r.kind.icon,
                                  color: AppColors.secondary,
                                  size: 42,
                                ),
                                title: MockTranslator.translateTitle(r.title, l),
                                subtitle: '${MockTranslator.translateTime(r.time, l)} · ${r.kind.label}',
                                trailing: SoftButton(
                                  label: l.caregiverDoneButton,
                                  color: AppColors.success,
                                  onPressed: () => state.toggleReminder(r.id),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Alerts ────────────────────────────────────────────
                  FadeInUp(
                    delayMs: 250,
                    child: SectionHeader(
                        title: l.caregiverNotesForYouTitle, icon: Icons.campaign_rounded),
                  ),
                  FadeInUp(
                    delayMs: 260,
                    child: Column(
                      children: <Widget>[
                        _AlertCard(
                          color: AppColors.success,
                          icon: Icons.trending_up_rounded,
                          title: l.caregiverAlertProceduralTitle,
                          body: l.caregiverAlertProceduralBody(state.averageAccuracy().round()),
                        ),
                        const SizedBox(height: 10),
                        _AlertCard(
                          color: AppColors.accent,
                          icon: Icons.wb_twilight_rounded,
                          title: l.caregiverAlertEveningTitle,
                          body: l.caregiverAlertEveningBody(state.patient.shortName),
                        ),
                        if (state.mood == MoodLevel.low) ...<Widget>[
                          const SizedBox(height: 10),
                          _AlertCard(
                            color: AppColors.secondary,
                            icon: Icons.favorite_rounded,
                            title: l.caregiverAlertMoodTitle,
                            body: l.caregiverAlertMoodBody,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Personalisation ───────────────────────────────────
                  FadeInUp(
                    delayMs: 280,
                    child: SectionHeader(
                      title: l.caregiverPersonalisationTitle,
                      icon: Icons.auto_awesome_rounded,
                      subtitle: l.caregiverPersonalisationSubtitle,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 290,
                    child: MmCard(
                      color: AppColors.primaryTint,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final String line
                              in AppState.personalization.personalisationSummary(state.patient))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Icon(Icons.arrow_right_rounded,
                                      size: 22, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(line,
                                        style: AppText.bodySmall.tint(AppColors.primaryDeep)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Onboarding entry ──────────────────────────────────
                  FadeInUp(
                    delayMs: 310,
                    child: MmCard(
                      onTap: () => Nav.open(context, const PatientOnboardingFlow()),
                      child: Row(
                        children: <Widget>[
                          const SoftIcon(
                            icon: Icons.person_add_alt_1_rounded,
                            color: AppColors.plum,
                            size: 50,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(l.caregiverSetupPatientProfileTitle,
                                    style: AppText.body.wght(800)),
                                const SizedBox(height: 3),
                                Text(
                                  l.caregiverSetupPatientProfileDetail,
                                  style: AppText.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  FadeInUp(
                    delayMs: 330,
                    child: const LanguageSelector(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(AppLocalizations l) {
    final List<String> months = <String>[
      l.caregiverMonthJan, l.caregiverMonthFeb, l.caregiverMonthMar, l.caregiverMonthApr,
      l.caregiverMonthMay, l.caregiverMonthJun, l.caregiverMonthJul, l.caregiverMonthAug,
      l.caregiverMonthSep, l.caregiverMonthOct, l.caregiverMonthNov, l.caregiverMonthDec,
    ];
    final List<String> days = <String>[
      l.caregiverWeekdayMon, l.caregiverWeekdayTue, l.caregiverWeekdayWed, l.caregiverWeekdayThu,
      l.caregiverWeekdayFri, l.caregiverWeekdaySat, l.caregiverWeekdaySun,
    ];
    final DateTime n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.state, required this.onOpen});
  final AppState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: EdgeInsets.zero,
      clip: true,
      shadow: AppColors.liftShadow(),
      onTap: onOpen,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, 6),
            width: double.infinity,
            color: AppColors.primaryTint.withValues(alpha: 0.5),
            child: Text(l.caregiverYourPatientLabel, style: AppText.overline),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Row(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: AppColors.softShadow(y: 4, blur: 12),
                  ),
                  child: SceneImage(
                    sceneId: state.patient.portraitScene,
                    size: 70,
                    circle: true,
                    borderColor: Colors.white,
                    borderWidth: 3,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(state.patient.name,
                          style: AppText.h2.sized(21),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(l.caregiverAgeLocation(state.patient.age, state.patient.location),
                          style: AppText.bodySmall,
                          maxLines: 2),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PillTag(
                          label: state.patient.stageNote,
                          color: AppColors.secondary,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                ProgressRing(
                  value: state.todayEngagement / 100,
                  size: 60,
                  stroke: 7,
                  color: AppColors.primary,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${state.todayEngagement}',
                          style: AppText.body.wght(800).tint(AppColors.primary)),
                      Text(l.caregiverEngagedLabel, style: AppText.caption.sized(9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.schedule_rounded, size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(l.caregiverLastActiveInline(state.lastActiveLabel.toLowerCase()),
                      style: AppText.caption),
                ),
                Text(l.caregiverOpenProfileLabel,
                    style: AppText.caption.wght(800).tint(AppColors.primary)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.last});
  final GameSession session;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final GameDefinition g = MockData.game(session.gameId);
    final int score = session.performance.overall;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        children: <Widget>[
          SceneImage(sceneId: g.sceneId, size: 46, radius: Corners.sm),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(g.name,
                    style: AppText.body.wght(700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                    l.caregiverSessionLine(session.timeLabel, l.gamesLevel(session.level),
                        session.performance.durationLabel),
                    style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('$score%', style: AppText.body.wght(800).tint(g.accent)),
              const SizedBox(height: 4),
              SizedBox(width: 56, child: MeterBar(value: score / 100, color: g.accent, height: 5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return MmCard(
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
        ],
      ),
    );
  }
}

/// The dashboard's way in to the map, doubling as the wandering alert.
class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final SafeZone? zone = state.safeZone;
    final SafeZoneEvent? alert = state.activeWanderAlert;
    final bool wandering = alert != null;

    final Color accent = wandering
        ? AppColors.danger
        : (zone == null ? AppColors.inkMuted : AppColors.success);

    return MmCard(
      onTap: () => Nav.push(context, const SafeZoneScreen()),
      color: wandering ? AppColors.dangerTint : null,
      child: Row(
        children: <Widget>[
          SoftIcon(
            icon: wandering
                ? Icons.warning_amber_rounded
                : (zone == null ? Icons.add_location_alt_outlined : Icons.shield_outlined),
            color: accent,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  wandering
                      ? l.caregiverSafeZoneLeft(state.patient.shortName, alert.zoneLabel)
                      : (zone == null ? l.caregiverSetSafeZone : l.caregiverSafeZoneLabel(zone.label)),
                  style: AppText.h3.tint(wandering ? AppColors.danger : AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  wandering
                      ? l.caregiverSafeZoneOutsideDetail(alert.distanceMetres.round())
                      : (zone == null
                          ? l.caregiverSafeZoneWanderDetail
                          : l.caregiverSafeZoneRadiusDetail(zone.radiusMetres.round(), zone.label)),
                  style: AppText.bodySmall.tint(AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}
