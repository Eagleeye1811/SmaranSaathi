import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/mock_translator.dart';
import '../widgets/caregiver_top_bar.dart';

/// Reminder management for the caregiver, grouped by category.
class CaregiverRemindersScreen extends StatelessWidget {
  const CaregiverRemindersScreen({super.key});

  static Color colorOf(ReminderKind k) => switch (k) {
        ReminderKind.medicine => AppColors.terracotta,
        ReminderKind.hydration => AppColors.secondary,
        ReminderKind.cognitive => AppColors.primary,
        ReminderKind.appointment => AppColors.plum,
        ReminderKind.routine => AppColors.accent,
        ReminderKind.social => AppColors.indigo,
      };

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<Reminder> reminders = state.reminders;
    final AppLocalizations l = AppLocalizations.of(context);

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.accentTint.withValues(alpha: 0.75),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
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
                    child: MmCard(
                      shadow: AppColors.liftShadow(),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              ProgressRing(
                                value: state.adherencePercent / 100,
                                size: 76,
                                stroke: 9,
                                color: AppColors.seriesClay,
                                center: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text('${state.adherencePercent}%',
                                        style: AppText.body.wght(800)),
                                    Text(l.caregiverAdherenceToday, style: AppText.caption.sized(10)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(l.caregiverAdherenceTitle, style: AppText.h3),
                                    const SizedBox(height: 4),
                                    Text(
                                      l.caregiverAdherenceSummary(state.remindersDone,
                                          state.remindersTotal, state.medicineDone, state.medicineTotal),
                                      style: AppText.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.lg),
                          Text(l.caregiverAdherenceWeekLabel, style: AppText.overline),
                          const SizedBox(height: 10),
                          TrendLineChart(
                            points: state.adherenceWeek,
                            color: AppColors.seriesClay,
                            valueSuffix: '%',
                            minValue: 50,
                            height: 130,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  for (final ReminderKind kind in ReminderKind.values)
                    _KindSection(
                      kind: kind,
                      reminders:
                          reminders.where((Reminder r) => r.kind == kind).toList(),
                      onToggle: state.toggleReminder,
                    ),

                  const SizedBox(height: Insets.md),
                  MmCard(
                    color: AppColors.surfaceMuted,
                    child: Row(
                      children: <Widget>[
                        const SoftIcon(
                          icon: Icons.notifications_active_rounded,
                          color: AppColors.inkSoft,
                          size: 46,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(l.caregiverReminderChannelsTitle,
                                  style: AppText.body.wght(800)),
                              const SizedBox(height: 4),
                              Text(
                                'A large full-screen card on her phone, a spoken prompt from '
                                'Saathi in ${state.patient.language}, and a note to you if '
                                'something is missed twice.',
                                style: AppText.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _KindSection extends StatelessWidget {
  const _KindSection({
    required this.kind,
    required this.reminders,
    required this.onToggle,
  });

  final ReminderKind kind;
  final List<Reminder> reminders;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context)!;
    final Color color = CaregiverRemindersScreen.colorOf(kind);
    final int done = reminders.where((Reminder r) => r.done).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(kind.glyph, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 9),
              Expanded(child: Text(kind.localizedLabel(l), style: AppText.h3)),
              PillTag(label: '$done/${reminders.length}', color: color, dense: true),
            ],
          ),
          const SizedBox(height: 10),
          for (final Reminder r in reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MmCard(
                padding: const EdgeInsets.all(14),
                color: r.done ? AppColors.successTint.withValues(alpha: 0.5) : Colors.white,
                border: Border.all(
                  color: r.done
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.hairline,
                ),
                child: Row(
                  children: <Widget>[
                    SoftIcon(icon: kind.icon, color: color, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(MockTranslator.translateTime(r.time, l), style: AppText.caption.wght(800).tint(color)),
                          const SizedBox(height: 2),
                          Text(MockTranslator.translateTitle(r.title, l), style: AppText.body.wght(700)),
                          if (r.detail.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(MockTranslator.translateDetail(r.detail, l), style: AppText.caption),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: () => onToggle(r.id),
                      child: AnimatedContainer(
                        duration: Motion.normal,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: r.done ? AppColors.success : Colors.white,
                          border: Border.all(
                            color: r.done ? AppColors.success : AppColors.hairline,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: r.done ? Colors.white : AppColors.hairline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
