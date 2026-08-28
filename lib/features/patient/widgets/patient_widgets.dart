import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';

/// Header used on every patient screen: identity on the left, the two controls
/// an elderly user might need on the right, and nothing else.
class PatientTopBar extends StatelessWidget {
  const PatientTopBar({super.key, this.trailing, this.onExit});

  final Widget? trailing;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 10),
      child: Row(
        children: <Widget>[
          const BrandMark(size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text('MemoryMitra', style: AppText.h3.wght(800)),
          ),
          if (trailing != null) ...<Widget>[trailing!, const SizedBox(width: 8)],
          ConnectivityChip(
            offline: state.offline,
            pending: state.pendingSync,
            syncing: state.syncing,
            onTap: () {
              final bool goingOnline = state.offline;
              state.setOffline(!state.offline);
              if (goingOnline) state.syncNow();
            },
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.logout_rounded,
            size: 40,
            tooltip: 'Switch role',
            onPressed: onExit ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Three enormous mood buttons — the only "form control" a patient ever meets.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.selected, required this.onSelect});

  final MoodLevel? selected;
  final ValueChanged<MoodLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    const List<(MoodLevel, Color)> moods = <(MoodLevel, Color)>[
      (MoodLevel.good, AppColors.success),
      (MoodLevel.okay, AppColors.accent),
      (MoodLevel.low, AppColors.secondary),
    ];
    return Row(
      children: <Widget>[
        for (final (MoodLevel m, Color c) in moods)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: m == MoodLevel.low ? 0 : 10),
              child: Pressable(
                onTap: () => onSelect(m),
                child: AnimatedContainer(
                  duration: Motion.normal,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: selected == m ? c.withValues(alpha: 0.16) : Colors.white,
                    borderRadius: Corners.r(Corners.md),
                    border: Border.all(
                      color: selected == m ? c : AppColors.hairline,
                      width: selected == m ? 2.4 : 1.4,
                    ),
                    boxShadow: selected == m ? null : AppColors.softShadow(y: 3, blur: 10, opacity: 0.04),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(m.emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(
                        m.label,
                        textAlign: TextAlign.center,
                        style: AppText.body.wght(selected == m ? 800 : 600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Today's Journey" — four gentle steps, never framed as a score.
class JourneyStrip extends StatelessWidget {
  const JourneyStrip({super.key, required this.steps, required this.done});

  final List<JourneyStep> steps;
  final Set<String> done;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 4),
            child: Row(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    AnimatedContainer(
                      duration: Motion.normal,
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done.contains(steps[i].id)
                            ? AppColors.success
                            : AppColors.surfaceMuted,
                        border: Border.all(
                          color: done.contains(steps[i].id)
                              ? AppColors.success
                              : AppColors.hairline,
                          width: 1.6,
                        ),
                      ),
                      child: Icon(
                        done.contains(steps[i].id) ? Icons.check_rounded : steps[i].icon,
                        size: 18,
                        color: done.contains(steps[i].id) ? Colors.white : AppColors.inkMuted,
                      ),
                    ),
                    if (i != steps.length - 1)
                      Container(
                        width: 2,
                        height: 18,
                        color: done.contains(steps[i].id)
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.hairline,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 18),
                    child: Text(
                      steps[i].label,
                      style: AppText.bodyLarge.wght(done.contains(steps[i].id) ? 700 : 500).tint(
                            done.contains(steps[i].id) ? AppColors.ink : AppColors.inkSoft,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One personalised question with big tappable answers.
class DailyQuestionCard extends StatefulWidget {
  const DailyQuestionCard({
    super.key,
    required this.question,
    required this.onAnswer,
    this.compact = false,
  });

  final DailyQuestion question;
  final void Function(QuestionOption option) onAnswer;
  final bool compact;

  @override
  State<DailyQuestionCard> createState() => _DailyQuestionCardState();
}

class _DailyQuestionCardState extends State<DailyQuestionCard> {
  QuestionOption? _chosen;

  @override
  Widget build(BuildContext context) {
    final DailyQuestion q = widget.question;
    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (q.sceneId != null) ...<Widget>[
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: Corners.r(Corners.md),
                  boxShadow: AppColors.softShadow(y: 4, blur: 14),
                ),
                child: SceneImage(sceneId: q.sceneId!, size: 118, radius: Corners.md),
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
          Text(q.text, style: AppText.patientBody.wght(700).sized(widget.compact ? 19 : 21)),
          if (q.subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(q.subtitle, style: AppText.bodySmall),
          ],
          const SizedBox(height: Insets.md),
          if (_chosen == null)
            Column(
              children: <Widget>[
                for (final QuestionOption o in q.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BigButton(
                      label: o.label,
                      emoji: o.emoji,
                      height: 62,
                      color: o.positive ? AppColors.primary : AppColors.secondary,
                      outlined: !o.positive,
                      onPressed: () {
                        setState(() => _chosen = o);
                        widget.onAnswer(o);
                      },
                    ),
                  ),
              ],
            )
          else
            AnimatedOpacity(
              opacity: 1,
              duration: Motion.normal,
              child: Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: Corners.r(Corners.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _chosen!.response ?? q.warmFollowUp,
                        style: AppText.bodyLarge.wght(600).tint(AppColors.primaryDeep),
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

/// A gentle "next up" reminder row.
class ReminderRow extends StatelessWidget {
  const ReminderRow({
    super.key,
    required this.reminder,
    required this.onToggle,
    this.large = true,
  });

  final Reminder reminder;
  final VoidCallback onToggle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (reminder.kind) {
      ReminderKind.medicine => AppColors.terracotta,
      ReminderKind.hydration => AppColors.secondary,
      ReminderKind.cognitive => AppColors.primary,
      ReminderKind.appointment => AppColors.plum,
      ReminderKind.routine => AppColors.accent,
    };

    return AnimatedContainer(
      duration: Motion.normal,
      padding: EdgeInsets.all(large ? 16 : 13),
      decoration: BoxDecoration(
        color: reminder.done ? AppColors.successTint.withValues(alpha: 0.6) : Colors.white,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(
          color: reminder.done ? AppColors.success.withValues(alpha: 0.35) : AppColors.hairline,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: large ? 52 : 44,
            height: large ? 52 : 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: Corners.r(Corners.sm),
            ),
            child: Center(
              child: Text(reminder.kind.glyph,
                  style: TextStyle(fontSize: large ? 24 : 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(reminder.time, style: AppText.label.tint(color).wght(800)),
                const SizedBox(height: 2),
                Text(
                  reminder.title,
                  style: (large ? AppText.bodyLarge : AppText.body).wght(700).copyWith(
                        decoration: reminder.done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.inkMuted,
                      ),
                ),
                if (reminder.detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(reminder.detail, style: AppText.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: Motion.normal,
              width: large ? 46 : 38,
              height: large ? 46 : 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reminder.done ? AppColors.success : Colors.white,
                border: Border.all(
                  color: reminder.done ? AppColors.success : AppColors.hairline,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: large ? 24 : 20,
                color: reminder.done ? Colors.white : AppColors.hairline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
