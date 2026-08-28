import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../widgets/patient_widgets.dart';

/// "Today" — reminders and the memory journal in one place.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<Reminder> reminders = state.reminders;
    final List<JournalEntry> journal = state.journal;

    return MotifBackground(
      opacity: 0.045,
      washColors: <Color>[
        AppColors.secondaryTint.withValues(alpha: 0.85),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const PatientTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  FadeInUp(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Today', style: AppText.patientTitle.sized(28)),
                        const SizedBox(height: 6),
                        Text(
                          'Your reminders and what you remembered.',
                          style: AppText.body.tint(AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  if (state.offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: OfflineBanner(
                        pending: state.pendingSync,
                      ),
                    ),

                  // ── Progress summary ──────────────────────────────────
                  FadeInUp(
                    delayMs: 40,
                    child: MmCard(
                      child: Row(
                        children: <Widget>[
                          ProgressRing(
                            value: state.remindersTotal == 0
                                ? 0
                                : state.remindersDone / state.remindersTotal,
                            size: 68,
                            stroke: 8,
                            color: AppColors.secondary,
                            center: Text(
                              '${state.remindersDone}/${state.remindersTotal}',
                              style: AppText.body.wght(800),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Your reminders', style: AppText.h3),
                                const SizedBox(height: 4),
                                Text(
                                  'Medicine ${state.medicineDone} of ${state.medicineTotal} taken today.',
                                  style: AppText.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Reminder timeline ─────────────────────────────────
                  FadeInUp(
                    delayMs: 70,
                    child: SectionHeader(
                      title: 'Reminders',
                      icon: Icons.notifications_active_rounded,
                      subtitle: 'Tap the circle when something is done',
                    ),
                  ),
                  for (int i = 0; i < reminders.length; i++)
                    FadeInUp(
                      delayMs: 80 + i * 35,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReminderRow(
                          reminder: reminders[i],
                          onToggle: () => state.toggleReminder(reminders[i].id),
                        ),
                      ),
                    ),
                  const SizedBox(height: Insets.lg),

                  // ── Memory journal ────────────────────────────────────
                  FadeInUp(
                    delayMs: 120,
                    child: SectionHeader(
                      title: 'Today\'s memory journal',
                      icon: Icons.menu_book_rounded,
                      subtitle: 'What you and Mitra talked about',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 140,
                    child: MmCard(
                      child: journal.isEmpty
                          ? Column(
                              children: <Widget>[
                                const Companion(state: CompanionState.gentle, size: 96),
                                const SizedBox(height: 10),
                                Text(
                                  'Nothing written yet today.',
                                  style: AppText.bodyLarge.wght(700),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Answer a question on the home screen and it will appear here.',
                                  style: AppText.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                for (int i = 0; i < journal.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        bottom: i == journal.length - 1 ? 0 : 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          width: 28,
                                          height: 28,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: journal[i].positive
                                                ? AppColors.success
                                                : AppColors.secondary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            journal[i].positive
                                                ? Icons.check_rounded
                                                : Icons.chat_bubble_rounded,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(journal[i].label,
                                                  style: AppText.bodyLarge.wght(700)),
                                              const SizedBox(height: 2),
                                              Text('“${journal[i].answer}” · ${journal[i].time}',
                                                  style: AppText.bodySmall),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Evening reflection ────────────────────────────────
                  FadeInUp(
                    delayMs: 170,
                    child: MmCard(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Colors.white, AppColors.plumTint],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CompanionSpeech(
                            message: state.journeyDone.contains('reflection')
                                ? 'Thank you for today, ${state.patient.shortName}. Sleep well.'
                                : 'Shall we close the day together?',
                            state: CompanionState.gentle,
                            companionSize: 66,
                            compact: true,
                          ),
                          const SizedBox(height: Insets.md),
                          if (!state.journeyDone.contains('reflection'))
                            BigButton(
                              label: 'Finish the day',
                              icon: Icons.nightlight_round,
                              color: AppColors.plum,
                              height: 60,
                              onPressed: state.completeReflection,
                            )
                          else
                            Row(
                              children: <Widget>[
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 24),
                                const SizedBox(width: 10),
                                Text('Evening reflection complete',
                                    style: AppText.bodyLarge.wght(700)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Daily routine ─────────────────────────────────────
                  FadeInUp(
                    delayMs: 200,
                    child: SectionHeader(
                      title: 'Your usual day',
                      icon: Icons.wb_twilight_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 220,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < state.patient.routine.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == state.patient.routine.length - 1 ? 0 : 14),
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: 78,
                                    child: Text(state.patient.routine[i].time,
                                        style: AppText.label.wght(800)),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _routineColor(state.patient.routine[i].kind),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(state.patient.routine[i].title,
                                        style: AppText.bodyLarge.wght(600)),
                                  ),
                                ],
                              ),
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

  static Color _routineColor(RoutineKind k) => switch (k) {
        RoutineKind.meal => AppColors.accent,
        RoutineKind.activity => AppColors.primary,
        RoutineKind.rest => AppColors.secondary,
        RoutineKind.cognitive => AppColors.plum,
        RoutineKind.medicine => AppColors.terracotta,
        RoutineKind.social => AppColors.indigo,
      };
}
