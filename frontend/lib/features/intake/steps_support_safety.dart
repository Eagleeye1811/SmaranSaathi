import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/onboarding.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';
import 'onboarding_l10n.dart';
import 'steps_person_health.dart';

// ─────────────────────────────────────────────────────────────────────────
// Q9 — independence and support
// ─────────────────────────────────────────────────────────────────────────

/// Eight everyday activities on one screen, each with the same four-point
/// scale beside it.
///
/// One screen rather than eight questions, and four levels rather than three:
/// "needs reminders" is where most people with early change actually sit, and
/// folding it into either neighbour would erase the earliest functional signal
/// there is. The level is what later separates a memory problem from a memory
/// problem that has started to cost independence.
class IndependenceStep extends StatefulWidget {
  const IndependenceStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<IndependenceStep> createState() => _IndependenceStepState();
}

class _IndependenceStepState extends State<IndependenceStep>
    with OnboardingStep<IndependenceStep> {
  void _set(DailyActivity a, SupportLevel level) {
    edit((OnboardingRecord d) => d.copyWith(
          support: <DailyActivity, SupportLevel>{...d.support, a: level},
        ));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.independence;
    final List<String> options = SupportLevel.values
        .map((SupportLevel s) => supportLevelLabel(l, s))
        .toList(growable: false);

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbIndependenceTitle,
      subtitle: l.onbIndependenceSubtitle,
      voiceQuestions: <VoiceIntakeQuestion>[
        for (final DailyActivity a in DailyActivity.values)
          VoiceIntakeQuestion(
            prompt: dailyActivityLabel(l, a),
            options: options,
            answeredIndex: draft.support[a]?.index,
            onSelect: (int i) => _set(a, SupportLevel.values[i]),
          ),
      ],
      onContinue: draft.independenceDone ? () => commit(widget.onDone) : null,
      footnote: draft.independenceDone
          ? null
          : l.onbIndependenceProgress(draft.support.length, DailyActivity.values.length),
      children: <Widget>[
        const QuestionLabel.forTitle(number: 9),
        for (final DailyActivity a in DailyActivity.values)
          ScaleQuestion(
            question: dailyActivityLabel(l, a),
            options: options,
            selectedIndex: draft.support[a]?.index,
            onSelect: (int i) => _set(a, SupportLevel.values[i]),
          ),
        WhyWeAsk(l.onbSupportRemindersNote),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Q10 — mood and behaviour
// ─────────────────────────────────────────────────────────────────────────

/// What has changed in mood, behaviour, sleep and perception.
///
/// Asked separately from the everyday difficulties because these are what
/// most often exhausts a family — and because, unlike the memory changes,
/// several of them respond well to routine, light, timing and a conversation
/// with the prescriber. They are the most actionable answers in the intake.
class BehaviourStep extends StatefulWidget {
  const BehaviourStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<BehaviourStep> createState() => _BehaviourStepState();
}

class _BehaviourStepState extends State<BehaviourStep> with OnboardingStep<BehaviourStep> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.behaviour;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbBehaviourTitle,
      subtitle: l.onbBehaviourSubtitle,
      onContinue: draft.behaviourDone ? () => commit(widget.onDone) : null,
      children: <Widget>[
        QuestionLabel.forTitle(number: 10, hint: l.onbSelectAll),
        // Only when a reported diagnosis makes seeing things and fluctuating
        // alertness expected. Saying so turns a frightening symptom into an
        // ordinary answer, which is the difference between it being reported
        // and it being hidden.
        if (draft.asksPerceptualSymptoms)
          WhyWeAsk(l.onbLewyPerceptualNote, icon: Icons.visibility_outlined),
        for (final BehaviourChange b in BehaviourChange.values)
          ChoiceTile(
            label: behaviourChangeLabel(l, b),
            selected: draft.behaviourChanges.contains(b),
            multiple: true,
            onTap: () => edit((OnboardingRecord d) => d.copyWith(
                  behaviourChanges: toggledExclusive(
                      d.behaviourChanges, b, BehaviourChange.noMajorChanges),
                )),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Q11 — safety
// ─────────────────────────────────────────────────────────────────────────

/// Everyday safety, and the one follow-up that decides whether the location
/// features are worth offering.
///
/// Wandering is the concern the rest of the product is built around, so
/// choosing it opens "has this happened before?" — the answer separates a
/// worry from a pattern, and only the pattern warrants a safe zone and alerts.
class DailySafetyStep extends StatefulWidget {
  const DailySafetyStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<DailySafetyStep> createState() => _DailySafetyStepState();
}

class _DailySafetyStepState extends State<DailySafetyStep>
    with OnboardingStep<DailySafetyStep> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.dailySafety;
    final bool asksWandering =
        draft.safetyConcerns.any((SafetyConcern c) => c.isWandering);

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbSafetyTitle,
      subtitle: l.onbSafetySubtitle,
      voiceQuestions: <VoiceIntakeQuestion>[
        if (asksWandering)
          VoiceIntakeQuestion(
            prompt: l.onbWanderingQuestion,
            options: IncidentFrequency.values
                .map((IncidentFrequency f) => incidentFrequencyLabel(l, f))
                .toList(growable: false),
            answeredIndex: draft.wanderingHistory?.index,
            onSelect: (int i) => edit((OnboardingRecord d) =>
                d.copyWith(wanderingHistory: IncidentFrequency.values[i])),
          ),
      ],
      onContinue: draft.safetyDone ? () => commit(widget.onDone) : null,
      children: <Widget>[
        QuestionLabel.forTitle(number: 11, hint: l.onbSelectAll),
        for (final SafetyConcern c in SafetyConcern.values)
          ChoiceTile(
            label: safetyConcernLabel(l, c),
            selected: draft.safetyConcerns.contains(c),
            multiple: true,
            onTap: () => edit((OnboardingRecord d) => d.copyWith(
                  safetyConcerns: toggledExclusive(
                      d.safetyConcerns, c, SafetyConcern.noMajorConcerns),
                )),
          ),
        if (asksWandering) ...<Widget>[
          const SizedBox(height: Insets.lg),
          QuestionLabel(l.onbWanderingQuestion),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final IncidentFrequency f in IncidentFrequency.values)
                ChipChoice(
                  label: incidentFrequencyLabel(l, f),
                  selected: draft.wanderingHistory == f,
                  accent: AppColors.danger,
                  onTap: () =>
                      edit((OnboardingRecord d) => d.copyWith(wanderingHistory: f)),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (draft.hasWanderingRisk) _SafetyOffer(message: l.onbSafetyLocationNote),
        ],
      ],
    );
  }
}

/// Shown only once wandering has actually happened. An offer of a feature,
/// not an alarm — the caregiver has just told us something difficult, and the
/// useful reply is what the app can do about it.
class _SafetyOffer extends StatelessWidget {
  const _SafetyOffer({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryTint,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.location_on_outlined, size: 20, color: AppColors.secondary),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(message,
                style: AppText.bodySmall.copyWith(color: AppColors.ink, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
