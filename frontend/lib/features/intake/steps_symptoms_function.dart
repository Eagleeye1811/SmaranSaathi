import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'assessment_l10n.dart';
import 'intake_kit.dart';

/// Step 5 — the symptom questionnaire, one group per screen.
///
/// Twenty-three separate questions is a wall, and a wall gets abandoned or
/// clicked through — neither of which produces usable answers. So each group
/// asks **one** question first, with the things it covers listed underneath:
/// "how often does anything like this happen?" Answering "never" or "rarely"
/// is a real answer about the whole group, given by someone looking at the
/// list, and it ends the group there.
///
/// Only a group where something *is* happening opens up into its individual
/// questions, pre-filled with what was just said — which is exactly where the
/// detail is worth the person's time. Five taps for someone with nothing to
/// report; full detail where there is something to describe.
///
/// The grouping is not cosmetic either: reported symptoms are read *by group*,
/// because a picture concentrated in one area is a different observation from
/// the same total spread evenly across all five.
class SymptomStep extends StatefulWidget {
  const SymptomStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<SymptomStep> createState() => _SymptomStepState();
}

class _SymptomStepState extends State<SymptomStep> {
  late SymptomAssessment _assessment;
  int _group = 0;

  /// The stem answer per group, and whether this group has been opened up.
  final Map<SymptomDomain, SymptomFrequency> _stem =
      <SymptomDomain, SymptomFrequency>{};
  final Set<SymptomDomain> _detailed = <SymptomDomain>{};

  @override
  void initState() {
    super.initState();
    _assessment = AppScope.read(context).intake.symptoms;
    // Coming back to a part-finished questionnaire: a group that already has
    // answers is shown in the detailed form it was answered in.
    for (final SymptomDomain domain in SymptomDomain.values) {
      if (_assessment.isDomainComplete(domain)) {
        _detailed.add(domain);
        _stem[domain] = SymptomCatalogue.of(domain)
            .map((SymptomItem i) => _assessment.responses[i.id]!)
            .reduce((SymptomFrequency a, SymptomFrequency b) =>
                a.index >= b.index ? a : b);
      }
    }
  }

  SymptomDomain get _domain => SymptomDomain.values[_group];

  bool get _groupAnswered => _stem.containsKey(_domain);

  /// A stem answer of "never" or "rarely" stands for the whole group: the
  /// person was shown everything it covers and told us none of it is
  /// happening. Anything more than that opens the individual questions.
  void _answerStem(SymptomFrequency frequency) {
    setState(() {
      _stem[_domain] = frequency;
      for (final SymptomItem item in SymptomCatalogue.of(_domain)) {
        _assessment = _assessment.withResponse(item.id, frequency);
      }
      if (frequency.index >= SymptomFrequency.sometimes.index) {
        _detailed.add(_domain);
      } else {
        _detailed.remove(_domain);
      }
    });
  }

  void _next() {
    AppScope.read(context).saveSymptoms(_assessment);
    if (_group < SymptomDomain.values.length - 1) {
      setState(() => _group++);
    } else {
      widget.onDone();
    }
  }

  void _back() {
    if (_group == 0) {
      widget.onBack?.call();
    } else {
      setState(() => _group--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SymptomItem> items = SymptomCatalogue.of(_domain);
    final bool detailed = _detailed.contains(_domain);
    final AppLocalizations l = AppLocalizations.of(context);

    return IntakeScaffold(
      stepIndex: 5,
      stepCount: 8,
      onBack: _back,
      // The stem question first; the individual ones only once the group has
      // opened up, so a spoken run through a quiet group is one answer long.
      voiceKey: _domain,
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion(
          prompt: '${symptomDomainLabel(l, _domain)}. ${symptomDomainPrompt(l, _domain)} '
              '${items.map((SymptomItem i) => symptomItemText(l, i).toLowerCase()).join(', ')}. '
              '${l.intakeSymptomFrequencyQuestion}',
          options: SymptomFrequency.values
              .map((SymptomFrequency f) => symptomFrequencyLabel(l, f))
              .toList(growable: false),
          answeredIndex: _stem[_domain]?.index,
          onSelect: (int i) => _answerStem(SymptomFrequency.values[i]),
        ),
        if (detailed)
          for (final SymptomItem item in items)
            VoiceIntakeQuestion(
              prompt: '${symptomDomainPrompt(l, _domain)} ${symptomItemText(l, item).toLowerCase()}?',
              options: SymptomFrequency.values
                  .map((SymptomFrequency f) => symptomFrequencyLabel(l, f))
                  .toList(growable: false),
              answeredIndex: _assessment.responses[item.id]?.index,
              onSelect: (int i) => setState(() {
                _assessment =
                    _assessment.withResponse(item.id, SymptomFrequency.values[i]);
              }),
            ),
      ],
      title: symptomDomainLabel(l, _domain),
      subtitle: '${_group + 1} of ${SymptomDomain.values.length}',
      onContinue: _groupAnswered ? _next : null,
      continueLabel: _group == SymptomDomain.values.length - 1
          ? l.intakeSymptomsFinish
          : l.intakeSymptomsNextGroup,
      footnote: _groupAnswered ? null : l.intakeSymptomsFootnote,
      children: <Widget>[
        MmCard(
          padding: const EdgeInsets.all(Insets.md),
          color: AppColors.surfaceMuted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${symptomDomainPrompt(l, _domain)}…', style: AppText.label),
              const SizedBox(height: Insets.sm),
              for (final SymptomItem item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('•  ', style: TextStyle(height: 1.4)),
                      Expanded(
                        child: Text(symptomItemText(l, item).toLowerCase(), style: AppText.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        ScaleQuestion(
          question: l.intakeSymptomFrequencyQuestion,
          options: SymptomFrequency.values
              .map((SymptomFrequency f) => symptomFrequencyLabel(l, f))
              .toList(growable: false),
          selectedIndex: _stem[_domain]?.index,
          onSelect: (int i) => _answerStem(SymptomFrequency.values[i]),
        ),
        if (detailed) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            l.intakeSymptomsDetailIntro,
            style: AppText.bodySmall,
          ),
          const SizedBox(height: Insets.sm),
          for (final SymptomItem item in items)
            ScaleQuestion(
              question: symptomItemText(l, item),
              options: SymptomFrequency.values
                  .map((SymptomFrequency f) => symptomFrequencyLabel(l, f))
                  .toList(growable: false),
              selectedIndex: _assessment.responses[item.id]?.index,
              onSelect: (int i) => setState(() {
                _assessment =
                    _assessment.withResponse(item.id, SymptomFrequency.values[i]);
              }),
            ),
        ] else if (_groupAnswered) ...<Widget>[
          const SizedBox(height: Insets.sm),
          MmCard(
            color: AppColors.successTint,
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: <Widget>[
                const SoftIcon(
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  background: AppColors.successTint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.intakeSymptomsNothingToReport(items.length),
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          SoftButton(
            label: l.intakeSymptomsAnswerIndividually,
            icon: Icons.tune_rounded,
            onPressed: () => setState(() => _detailed.add(_domain)),
          ),
        ],
        const SizedBox(height: Insets.sm),
        NotADiagnosisNote(
          message: l.intakeSymptomsDisclaimer,
        ),
      ],
    );
  }
}

/// Step 6 — daily function.
///
/// Arguably the most important screen in the intake. Cognitive scores describe
/// a task in an app; this describes whether life still works. A modest change
/// in performance that comes with new difficulty managing money or medication
/// matters far more than a larger change with no functional impact at all.
///
/// Asked as a checklist of what someone *still does*, everything ticked to
/// begin with. Most people managing their own lives can then continue without
/// touching anything, and the screen reads as a list of what they can do
/// rather than as an eight-row grid of ways to be dependent. The "how much
/// help" question only appears for the things actually unticked — usually
/// none, often one or two.
class FunctionStep extends StatefulWidget {
  const FunctionStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<FunctionStep> createState() => _FunctionStepState();
}

class _FunctionStepState extends State<FunctionStep> {
  late FunctionalAssessment _assessment;

  @override
  void initState() {
    super.initState();
    final FunctionalAssessment stored = AppScope.read(context).intake.function;
    // Independent is the starting assumption, so someone for whom it is true
    // answers this screen by pressing Continue.
    _assessment = stored.isEmpty
        ? FunctionalAssessment(levels: <String, FunctionLevel>{
            for (final FunctionalItem item in FunctionCatalogue.items)
              item.id: FunctionLevel.independent,
          })
        : stored;
  }

  FunctionLevel _levelOf(FunctionalItem item) =>
      _assessment.levels[item.id] ?? FunctionLevel.independent;

  void _set(FunctionalItem item, FunctionLevel level) {
    setState(() => _assessment = _assessment.withLevel(item.id, level));
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final int needing = _assessment.needingHelp.length;

    return IntakeScaffold(
      stepIndex: 6,
      stepCount: 8,
      onBack: widget.onBack,
      voiceQuestions: <VoiceIntakeQuestion>[
        for (final FunctionalItem item in FunctionCatalogue.items)
          VoiceIntakeQuestion(
            prompt: '${functionalItemLabel(l, item)}. ${l.intakeFunctionHelpPrompt}',
            options: <String>[
              l.intakeFunctionByMyself,
              l.intakeFunctionLittleHelp,
              l.intakeFunctionLotHelp,
            ],
            answeredIndex: _levelOf(item).index,
            onSelect: (int i) => _set(item, FunctionLevel.values[i]),
          ),
      ],
      title: l.intakeFunctionTitle,
      subtitle: l.intakeFunctionSubtitle,
      onContinue: () {
        state.saveFunction(_assessment);
        widget.onDone();
      },
      footnote: needing == 0 ? l.intakeFunctionAllTickedFootnote : null,
      children: <Widget>[
        // The instruction, in the same two states the rows themselves use.
        // "Untick what you need help with" was the whole instruction before,
        // and a tick that is already on does not read as a control.
        MmCard(
          color: AppColors.primaryTint,
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.intakeFunctionTapToChange, style: AppText.body.wght(700)),
              const SizedBox(height: Insets.sm),
              _Legend(
                ticked: true,
                text: l.intakeFunctionLegendTicked,
              ),
              const SizedBox(height: Insets.xs),
              _Legend(
                ticked: false,
                text: l.intakeFunctionLegendUnticked,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                l.intakeFunctionStartTickedNote,
                style: AppText.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        for (final FunctionalItem item in FunctionCatalogue.items)
          _ActivityTick(
            item: item,
            level: _levelOf(item),
            onToggle: () => _set(
              item,
              _levelOf(item) == FunctionLevel.independent
                  ? FunctionLevel.needsHelp
                  : FunctionLevel.independent,
            ),
            onLevel: (FunctionLevel level) => _set(item, level),
          ),
        MmCard(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(l.intakeFunctionDoingByYourselfLabel, style: AppText.label)),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${FunctionCatalogue.items.length - needing} of '
                    '${FunctionCatalogue.items.length}',
                    style: AppText.stat.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              MeterBar(value: _assessment.independencePercent / 100),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        NotADiagnosisNote(
          message: l.intakeFunctionDisclaimer,
        ),
      ],
    );
  }
}

/// One line of the legend, drawn with the same indicator the rows use so the
/// explanation and the control cannot drift apart.
class _Legend extends StatelessWidget {
  const _Legend({required this.ticked, required this.text});

  final bool ticked;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _TickBox(ticked: ticked),
        const SizedBox(width: Insets.sm),
        Expanded(child: Text(text, style: AppText.bodySmall)),
      ],
    );
  }
}

/// The checkbox itself — the same square, size and accent as every other
/// "select all that apply" question in the intake.
class _TickBox extends StatelessWidget {
  const _TickBox({required this.ticked});

  final bool ticked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.quick,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: ticked ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: ticked ? AppColors.primary : AppColors.inkMuted,
          width: 2,
        ),
        borderRadius: Corners.r(8),
      ),
      child: ticked
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : null,
    );
  }
}

/// One activity: a tick, and — only when unticked — how much help it needs.
///
/// Built on the same shape as [ChoiceTile], because it *is* a "select all
/// that apply" question and should not look like a different kind of control
/// three screens after the last one. One accent throughout: primary for
/// ticked, plain surface for not.
class _ActivityTick extends StatelessWidget {
  const _ActivityTick({
    required this.item,
    required this.level,
    required this.onToggle,
    required this.onLevel,
  });

  final FunctionalItem item;
  final FunctionLevel level;
  final VoidCallback onToggle;
  final ValueChanged<FunctionLevel> onLevel;

  @override
  Widget build(BuildContext context) {
    final bool independent = level == FunctionLevel.independent;
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: MmCard(
        padding: EdgeInsets.zero,
        color: independent
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        border: Border.all(
          color: independent ? AppColors.primary : AppColors.hairline,
          width: independent ? 2 : 1,
        ),
        child: Column(
          children: <Widget>[
            // Only the row toggles. An `onTap` on the whole card would swallow
            // taps on the help chips below it, which is how "a lot of help"
            // silently stayed on "a little".
            Pressable(
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
                child: Row(
                  children: <Widget>[
                    _TickBox(ticked: independent),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        functionalItemLabel(l, item),
                        style: AppText.body.copyWith(
                          fontWeight:
                              independent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      independent ? l.intakeFunctionByMyself : l.intakeFunctionWithHelp,
                      style: AppText.caption.copyWith(
                        color: independent ? AppColors.primary : AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!independent)
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
                child: ScaleQuestion(
                  question: l.intakeFunctionHowMuchHelp(functionalItemLabel(l, item).toLowerCase()),
                  options: <String>[l.intakeFunctionALittle, l.intakeFunctionALot],
                  selectedIndex: level == FunctionLevel.needsHelp ? 0 : 1,
                  onSelect: (int i) => onLevel(
                    i == 0 ? FunctionLevel.needsHelp : FunctionLevel.dependent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
