import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/mock_translator.dart';
import '../settings/language_picker_button.dart';
import '../today/today_screen.dart';

/// The bar across the top of every patient screen.
class PatientTopBar extends StatelessWidget {
  const PatientTopBar({
    super.key,
    this.trailing,
    this.onExit,
    this.showExit = false,
    this.showStatus = true,
    this.showTodayButton = true,
  });

  final Widget? trailing;
  final VoidCallback? onExit;
  final bool showExit;
  final bool showStatus;
  final bool showTodayButton;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 6, Insets.gutter, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          if (Navigator.of(context).canPop()) ...<Widget>[
            RoundIconButton(
              icon: Icons.arrow_back_rounded,
              size: 40,
              tooltip: l.actionBack,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
          ],
          const Expanded(child: _Wordmark()),
          if (trailing != null) ...<Widget>[trailing!, const SizedBox(width: 8)],
          if (showTodayButton) ...<Widget>[
            Pressable(
              onTap: () => Nav.open(context, const TodayScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: Corners.r(Corners.pill),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Today',
                      style: AppText.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          const LanguagePickerButton(),
          if (onExit != null && showExit) ...<Widget>[
            const SizedBox(width: 8),
            RoundIconButton(
              icon: Icons.logout_rounded,
              size: 40,
              tooltip: l.actionSwitchRole,
              onPressed: onExit!,
            ),
          ],
        ],
      ),
    );
  }
}

/// The name, set in two weights so it reads as a mark rather than as a label.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: 'Memory', style: AppText.h3.wght(800).tint(AppColors.ink)),
          TextSpan(text: 'Saathi', style: AppText.h3.wght(800).tint(AppColors.primary)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
    final AppLocalizations l = AppLocalizations.of(context);
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
                        switch (m) {
                          MoodLevel.good => l.moodGood,
                          MoodLevel.okay => l.moodOkay,
                          MoodLevel.low => l.moodLow,
                        },
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
    final AppLocalizations l = AppLocalizations.of(context)!;
    final Color color = switch (reminder.kind) {
      ReminderKind.medicine => AppColors.terracotta,
      ReminderKind.hydration => AppColors.secondary,
      ReminderKind.cognitive => AppColors.primary,
      ReminderKind.appointment => AppColors.plum,
      ReminderKind.routine => AppColors.accent,
      ReminderKind.social => AppColors.indigo,
    };

    return AnimatedContainer(
      duration: Motion.normal,
      padding: EdgeInsets.all(large ? 16 : 14),
      decoration: BoxDecoration(
        color: reminder.done ? AppColors.primaryTint.withValues(alpha: 0.4) : Colors.white,
        borderRadius: Corners.r(Corners.lg),
        border: Border.all(
          color: reminder.done
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.hairline.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow(y: 3, blur: 12, opacity: 0.05),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: large ? 52 : 44,
            height: large ? 52 : 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: Corners.r(Corners.md),
            ),
            child: Center(
              child: Text(
                reminder.kind.glyph,
                style: TextStyle(fontSize: large ? 24 : 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reminder.time,
                  style: AppText.label.tint(accentColor).wght(800).sized(12),
                ),
                const SizedBox(height: 3),
                Text(
                  reminder.title,
                  style: (large ? AppText.bodyLarge : AppText.body).wght(700).tint(
                        reminder.done ? AppColors.inkSoft : AppColors.ink,
                      ).copyWith(
                        decoration: reminder.done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.inkMuted,
                      ),
                ),
                if (reminder.detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    reminder.detail,
                    style: AppText.bodySmall.tint(AppColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: Motion.normal,
              width: large ? 46 : 38,
              height: large ? 46 : 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reminder.done ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: reminder.done ? AppColors.primary : AppColors.hairline,
                  width: 2,
                ),
                boxShadow: reminder.done
                    ? AppColors.softShadow(y: 2, blur: 6, opacity: 0.18)
                    : null,
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
