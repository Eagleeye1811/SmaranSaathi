import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/onboarding.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';
import 'onboarding_l10n.dart';
import 'steps_person_health.dart';

// ─────────────────────────────────────────────────────────────────────────
// Part B · Q12–Q13 — what they enjoy, what they still do well
// ─────────────────────────────────────────────────────────────────────────

/// Where the onboarding stops asking about loss.
///
/// Part B exists because a profile assembled only from deficits is both
/// clinically incomplete and, for the family who reads it back, quietly
/// cruel. The answers here are also load-bearing rather than decorative:
/// the activities, the companion's prompts and the daily plan are all built
/// from what the person still enjoys and can still do.
class StrengthsStep extends StatefulWidget {
  const StrengthsStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<StrengthsStep> createState() => _StrengthsStepState();
}

class _StrengthsStepState extends State<StrengthsStep> with OnboardingStep<StrengthsStep> {
  late final TextEditingController _stillDoesWell;

  @override
  void initState() {
    super.initState();
    _stillDoesWell = TextEditingController(text: draft.stillDoesWell);
  }

  @override
  void dispose() {
    _stillDoesWell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.strengths;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbStrengthsTitle,
      subtitle: l.onbStrengthsSubtitle,
      accent: AppColors.secondary,
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion.multiSelect(
          prompt: l.onbStrengthsTitle,
          options: <String>[
            for (final EnjoyedActivity e in EnjoyedActivity.values) enjoyedActivityLabel(l, e),
          ],
          selectedIndices: <int>{
            for (int i = 0; i < EnjoyedActivity.values.length; i++)
              if (draft.enjoys.contains(EnjoyedActivity.values[i])) i,
          },
          onSelect: (int i) => edit((OnboardingRecord d) =>
              d.copyWith(enjoys: toggled(d.enjoys, EnjoyedActivity.values[i]))),
        ),
        VoiceIntakeQuestion.dictated(
          prompt: l.onbStillDoesWellLabel,
          answered: _stillDoesWell.text,
          onSpeak: (String value) => setState(() => _stillDoesWell.text = value),
        ),
      ],
      onContinue: draft.strengthsDone
          ? () {
              edit((OnboardingRecord d) =>
                  d.copyWith(stillDoesWell: _stillDoesWell.text.trim()));
              commit(widget.onDone);
            }
          : null,
      children: <Widget>[
        QuestionLabel.forTitle(number: 12, hint: l.onbSelectAll),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final EnjoyedActivity e in EnjoyedActivity.values)
              ChipChoice(
                label: enjoyedActivityLabel(l, e),
                selected: draft.enjoys.contains(e),
                accent: AppColors.secondary,
                onTap: () =>
                    edit((OnboardingRecord d) => d.copyWith(enjoys: toggled(d.enjoys, e))),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbStillDoesWellLabel, number: 13, hint: l.onbOptional),
        IntakeField(
          controller: _stillDoesWell,
          hint: l.onbStillDoesWellHint,
          lines: 4,
          onChanged: () => setState(() {}),
        ),
        WhyWeAsk(l.onbStrengthsWhy, icon: Icons.favorite_border_rounded),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Part B · Q14–Q15 — what to help with, and anything else
// ─────────────────────────────────────────────────────────────────────────

/// What the family actually wants from the app, in their words and not ours.
///
/// These three choices decide what the dashboard leads with, so the question
/// is not a courtesy — asking someone to rank what they want is the only way
/// the daily plan can be about their problem rather than about the app's
/// favourite feature.
class GoalsStep extends StatefulWidget {
  const GoalsStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends State<GoalsStep> with OnboardingStep<GoalsStep> {
  late final TextEditingController _anythingElse;

  @override
  void initState() {
    super.initState();
    _anythingElse = TextEditingController(text: draft.anythingElse);
  }

  @override
  void dispose() {
    _anythingElse.dispose();
    super.dispose();
  }

  void _toggleGoal(SupportGoal g) {
    edit((OnboardingRecord draft) {
      final List<SupportGoal> next = <SupportGoal>[...draft.goals];
      if (!next.remove(g)) {
        if (next.length >= OnboardingRecord.maxGoals) return draft;
        next.add(g);
      }
      return draft.copyWith(goals: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.goals;
    final bool full = draft.goals.length >= OnboardingRecord.maxGoals;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbGoalsTitle,
      subtitle: l.onbGoalsSubtitle,
      accent: AppColors.secondary,
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion.multiSelect(
          prompt: l.onbGoalsTitle,
          options: <String>[
            for (final SupportGoal g in SupportGoal.values) supportGoalLabel(l, g),
          ],
          selectedIndices: <int>{
            for (int i = 0; i < SupportGoal.values.length; i++)
              if (draft.goals.contains(SupportGoal.values[i])) i,
          },
          maxSelectable: OnboardingRecord.maxGoals,
          onSelect: (int i) => _toggleGoal(SupportGoal.values[i]),
        ),
        VoiceIntakeQuestion.dictated(
          prompt: l.onbAnythingElseLabel,
          answered: _anythingElse.text,
          onSpeak: (String value) => setState(() => _anythingElse.text = value),
        ),
      ],
      onContinue: draft.goalsDone
          ? () {
              edit((OnboardingRecord d) =>
                  d.copyWith(anythingElse: _anythingElse.text.trim()));
              commit(widget.onDone);
            }
          : null,
      children: <Widget>[
        QuestionLabel.forTitle(number: 14, hint: l.onbChooseUpToThree),
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: PillTag(
            label: l.onbTopChosenCount(draft.goals.length),
            color: full ? AppColors.success : AppColors.secondary,
            icon: full ? Icons.check_rounded : Icons.filter_3_rounded,
          ),
        ),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final SupportGoal g in SupportGoal.values)
              ChipChoice(
                label: supportGoalLabel(l, g),
                selected: draft.goals.contains(g),
                accent: AppColors.secondary,
                enabled: !full,
                badge: draft.goals.contains(g) ? draft.goals.indexOf(g) + 1 : null,
                onTap: () => _toggleGoal(g),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbAnythingElseLabel, number: 15, hint: l.onbOptional),
        IntakeField(
          controller: _anythingElse,
          hint: l.onbAnythingElseHint,
          lines: 4,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }
}
