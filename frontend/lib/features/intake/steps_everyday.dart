import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/onboarding.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'assessment_l10n.dart';
import 'intake_kit.dart';
import 'onboarding_l10n.dart';
import 'steps_person_health.dart';

// ─────────────────────────────────────────────────────────────────────────
// Q6–Q7 — what has changed, and what matters most
// ─────────────────────────────────────────────────────────────────────────

/// The screen the whole onboarding is built around.
///
/// One broad "what have you noticed?" replaces fifteen individual symptom
/// questions. It gives a complete picture in one pass, and — more importantly
/// — it lets the caregiver describe the situation in their own order rather
/// than being marched through a checklist in someone else's.
///
/// The ranking question below it is what makes the depth affordable: only the
/// three named here are followed up, so the questionnaire can go as deep as a
/// clinician would on the things that matter and skip everything else.
class EverydayStep extends StatefulWidget {
  const EverydayStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<EverydayStep> createState() => _EverydayStepState();
}

class _EverydayStepState extends State<EverydayStep> with OnboardingStep<EverydayStep> {
  /// Ticking a difficulty on Q6 while it was already ranked on Q7 has to
  /// un-rank it too, or the record ends up naming a "biggest difficulty" that
  /// was never reported at all.
  void _toggleDifficulty(DailyDifficulty d) {
    edit((OnboardingRecord draft) {
      final Set<DailyDifficulty> next =
          toggledExclusive(draft.difficulties, d, DailyDifficulty.nothingNoticed);
      return draft.copyWith(
        difficulties: next,
        topDifficulties: <DailyDifficulty>[
          for (final DailyDifficulty t in draft.topDifficulties)
            if (next.contains(t)) t,
        ],
      );
    });
  }

  /// Ranking is by order of tapping, and the order is kept: the first thing
  /// named is the one the app starts with, so it must not be reshuffled into
  /// declaration order behind the caregiver's back.
  void _toggleTop(DailyDifficulty d) {
    edit((OnboardingRecord draft) {
      final List<DailyDifficulty> next = <DailyDifficulty>[...draft.topDifficulties];
      if (!next.remove(d)) {
        if (next.length >= OnboardingRecord.maxTopDifficulties) return draft;
        next.add(d);
      }
      return draft.copyWith(topDifficulties: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.everyday;

    final List<DailyDifficulty> chosen = <DailyDifficulty>[
      for (final DailyDifficulty d in DailyDifficulty.values)
        if (d.isDifficulty && draft.difficulties.contains(d)) d,
    ];
    final bool canRank = chosen.isNotEmpty;
    final bool topFull =
        draft.topDifficulties.length >= OnboardingRecord.maxTopDifficulties;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbEverydayTitle,
      subtitle: l.onbEverydaySubtitle,
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion(
          prompt: l.onbOnsetQuestion,
          options: OnsetWindow.values
              .map((OnsetWindow o) => onsetWindowLabel(l, o))
              .toList(growable: false),
          answeredIndex: draft.onset?.index,
          onSelect: (int i) =>
              edit((OnboardingRecord d) => d.copyWith(onset: OnsetWindow.values[i])),
        ),
        VoiceIntakeQuestion(
          prompt: l.onbCourseQuestion,
          options: ProgressionPattern.values
              .map((ProgressionPattern p) => progressionPatternLabel(l, p))
              .toList(growable: false),
          answeredIndex: draft.course?.index,
          onSelect: (int i) => edit(
              (OnboardingRecord d) => d.copyWith(course: ProgressionPattern.values[i])),
        ),
      ],
      onContinue: draft.everydayDone ? () => commit(widget.onDone) : null,
      children: <Widget>[
        QuestionLabel.forTitle(number: 6, hint: l.onbSelectAll),
        for (final DailyDifficulty d in DailyDifficulty.values)
          ChoiceTile(
            label: dailyDifficultyLabel(l, d),
            selected: draft.difficulties.contains(d),
            multiple: true,
            onTap: () => _toggleDifficulty(d),
          ),

        if (canRank) ...<Widget>[
          const SizedBox(height: Insets.lg),
          QuestionLabel(l.onbTopQuestion, number: 7, hint: l.onbTopHint),
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: PillTag(
              label: l.onbTopChosenCount(draft.topDifficulties.length),
              color: topFull ? AppColors.success : AppColors.primary,
              icon: topFull ? Icons.check_rounded : Icons.filter_3_rounded,
            ),
          ),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final DailyDifficulty d in chosen)
                ChipChoice(
                  label: dailyDifficultyLabel(l, d),
                  selected: draft.topDifficulties.contains(d),
                  enabled: !topFull,
                  badge: draft.topDifficulties.contains(d)
                      ? draft.topDifficulties.indexOf(d) + 1
                      : null,
                  onTap: () => _toggleTop(d),
                ),
            ],
          ),
        ],

        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbOnsetQuestion),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final OnsetWindow o in OnsetWindow.values)
              ChipChoice(
                label: onsetWindowLabel(l, o),
                selected: draft.onset == o,
                onTap: () => edit((OnboardingRecord d) => d.copyWith(onset: o)),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        QuestionLabel(l.onbCourseQuestion),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final ProgressionPattern p in ProgressionPattern.values)
              ChipChoice(
                label: progressionPatternLabel(l, p),
                selected: draft.course == p,
                onTap: () => edit((OnboardingRecord d) => d.copyWith(course: p)),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        WhyWeAsk(l.onbOnsetWhy),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Adaptive follow-ups
// ─────────────────────────────────────────────────────────────────────────

/// The screen that makes this an interview rather than a form.
///
/// Nothing here is fixed: the questions are whatever [ProbeCatalogue] has for
/// the three difficulties the caregiver named as the biggest, grouped under
/// the difficulty that raised them. Someone who named misplacing, getting lost
/// and medicines answers eight short questions; someone who named three
/// difficulties with no follow-ups never sees this screen at all.
class ProbesStep extends StatefulWidget {
  const ProbesStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<ProbesStep> createState() => _ProbesStepState();
}

class _ProbesStepState extends State<ProbesStep> with OnboardingStep<ProbesStep> {
  void _answer(ProbeQuestion q, String optionId) {
    edit((OnboardingRecord draft) {
      final Map<String, Set<String>> next = <String, Set<String>>{...draft.probeAnswers};
      final Set<String> current = next[q.id] ?? const <String>{};
      next[q.id] = switch (q.kind) {
        // A single-choice answer replaces; tapping the chosen one clears it,
        // so a mis-tap is undoable without a "clear" button.
        ProbeKind.single =>
          current.contains(optionId) ? <String>{} : <String>{optionId},
        ProbeKind.multi => toggled(current, optionId),
      };
      next.removeWhere((String _, Set<String> v) => v.isEmpty);
      return draft.copyWith(probeAnswers: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.probes;

    // Grouped by the difficulty that raised them, so the caregiver can see
    // which of their own answers each block is following up on.
    final List<DailyDifficulty> withProbes = <DailyDifficulty>[
      for (final DailyDifficulty d in draft.topDifficulties)
        if (ProbeCatalogue.forDifficulty(d).isNotEmpty) d,
    ];
    final Set<String> rendered = <String>{};

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbProbesTitle,
      subtitle: l.onbProbesSubtitle,
      voiceQuestions: <VoiceIntakeQuestion>[
        for (final ProbeQuestion q in draft.activeProbes)
          if (q.kind == ProbeKind.single)
            VoiceIntakeQuestion(
              prompt: probePrompt(l, q.id),
              options: q.optionIds
                  .map((String id) => probeOptionLabel(l, id))
                  .toList(growable: false),
              answeredIndex: draft.probeChoice(q.id) == null
                  ? null
                  : q.optionIds.indexOf(draft.probeChoice(q.id)!),
              onSelect: (int i) => _answer(q, q.optionIds[i]),
            ),
      ],
      onContinue: draft.probesDone ? () => commit(widget.onDone) : null,
      children: <Widget>[
        for (final DailyDifficulty d in withProbes) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: PillTag(
              label: dailyDifficultyLabel(l, d),
              color: AppColors.plum,
              icon: Icons.subdirectory_arrow_right_rounded,
            ),
          ),
          for (final ProbeQuestion q in ProbeCatalogue.forDifficulty(d))
            // A probe shared by two chosen difficulties — the memory pair —
            // is asked once, under the first of them.
            if (rendered.add(q.id))
              _ProbeCard(
                question: q,
                prompt: probePrompt(l, q.id),
                selected: draft.probeAnswers[q.id] ?? const <String>{},
                labelFor: (String id) => probeOptionLabel(l, id),
                onTap: (String id) => _answer(q, id),
                multipleHint: l.onbSelectAll,
              ),
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }
}

class _ProbeCard extends StatelessWidget {
  const _ProbeCard({
    required this.question,
    required this.prompt,
    required this.selected,
    required this.labelFor,
    required this.onTap,
    required this.multipleHint,
  });

  final ProbeQuestion question;
  final String prompt;
  final Set<String> selected;
  final String Function(String) labelFor;
  final ValueChanged<String> onTap;
  final String multipleHint;

  @override
  Widget build(BuildContext context) {
    final bool answered = selected.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: MmCard(
        padding: const EdgeInsets.all(Insets.md),
        border: Border.all(
          color: answered ? AppColors.primary.withValues(alpha: 0.4) : AppColors.hairline,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(prompt, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
            if (question.kind == ProbeKind.multi) ...<Widget>[
              const SizedBox(height: 3),
              Text(multipleHint, style: AppText.caption),
            ],
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String id in question.optionIds)
                  ChipChoice(
                    label: labelFor(id),
                    selected: selected.contains(id),
                    onTap: () => onTap(id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Q8 — one concrete recent example
// ─────────────────────────────────────────────────────────────────────────

/// The most informative question in the onboarding, and the only one that is
/// asked in the caregiver's own words.
///
/// A real episode carries severity, context and consequence that no checkbox
/// does — "she looked for the keys for an hour and then said someone had taken
/// them" is worth more than every tick on the previous screen. It is offered
/// rather than demanded: a caregiver with no words to spare should still be
/// able to finish, and an example extracted under protest is not worth having.
class RecentExampleStep extends StatefulWidget {
  const RecentExampleStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<RecentExampleStep> createState() => _RecentExampleStepState();
}

class _RecentExampleStepState extends State<RecentExampleStep>
    with OnboardingStep<RecentExampleStep> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: draft.recentExample);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    edit((OnboardingRecord d) => d.copyWith(recentExample: _text.text.trim()));
    commit(widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.example;
    final DailyDifficulty? focus =
        draft.topDifficulties.isEmpty ? null : draft.topDifficulties.first;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbExampleTitle,
      subtitle: l.onbExampleSubtitle,
      // Dictation matters more here than anywhere else in the intake: this is
      // a paragraph, and a caregiver who would never type one will happily
      // say it.
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion.dictated(
          prompt: l.onbExampleLabel,
          answered: _text.text,
          onSpeak: (String value) => setState(() => _text.text = value),
        ),
      ],
      onContinue: _save,
      secondaryLabel: _text.text.trim().isEmpty ? l.onbExampleSkip : null,
      onSecondary: _text.text.trim().isEmpty ? _save : null,
      children: <Widget>[
        if (focus != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: PillTag(
              label: dailyDifficultyLabel(l, focus),
              color: AppColors.plum,
              icon: Icons.push_pin_outlined,
            ),
          ),
        QuestionLabel(l.onbExampleLabel, number: 8),
        IntakeField(
          controller: _text,
          hint: l.onbExampleHint,
          lines: 5,
          onChanged: () => setState(() {}),
        ),
        WhyWeAsk(l.onbExampleWhy, icon: Icons.auto_awesome_outlined),
      ],
    );
  }
}
