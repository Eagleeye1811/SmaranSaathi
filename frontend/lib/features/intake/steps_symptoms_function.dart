import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/ui_kit.dart';
import 'intake_kit.dart';

/// Step 5 — the symptom questionnaire, one group per screen.
///
/// Twenty-three questions on one page is a wall; five groups of four or five
/// is a conversation. The grouping is not cosmetic either — reported symptoms
/// are read *by group*, because a picture concentrated in one area is a
/// different observation from the same total spread evenly across all five.
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

  @override
  void initState() {
    super.initState();
    _assessment = AppScope.read(context).intake.symptoms;
  }

  SymptomDomain get _domain => SymptomDomain.values[_group];

  bool get _groupComplete => _assessment.isDomainComplete(_domain);

  void _next() {
    final AppState state = AppScope.read(context);
    state.saveSymptoms(_assessment);
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
    return IntakeScaffold(
      stepIndex: 5,
      stepCount: 8,
      onBack: _back,
      title: _domain.label,
      subtitle: '${_domain.prompt}  (${_group + 1} of ${SymptomDomain.values.length})',
      onContinue: _groupComplete ? _next : null,
      continueLabel:
          _group == SymptomDomain.values.length - 1 ? 'Finish symptoms' : 'Next group',
      footnote: _groupComplete ? null : 'Answer every question in this group.',
      children: <Widget>[
        for (final SymptomItem item in items)
          ScaleQuestion(
            question: item.text,
            options: SymptomFrequency.values
                .map((SymptomFrequency f) => f.label)
                .toList(growable: false),
            selectedIndex: _assessment.responses[item.id]?.index,
            onSelect: (int i) => setState(() {
              _assessment = _assessment.withResponse(item.id, SymptomFrequency.values[i]);
            }),
          ),
        const SizedBox(height: Insets.sm),
        const NotADiagnosisNote(
          message:
              'These questions describe what you notice. They are not a test and '
              'there are no wrong answers.',
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
    _assessment = AppScope.read(context).intake.function;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final bool complete = _assessment.isComplete;
    return IntakeScaffold(
      stepIndex: 6,
      stepCount: 8,
      onBack: widget.onBack,
      title: 'Everyday activities',
      subtitle: 'How independently are these managed at the moment?',
      onContinue: complete
          ? () {
              state.saveFunction(_assessment);
              widget.onDone();
            }
          : null,
      footnote: complete ? null : 'Answer for each activity to continue.',
      children: <Widget>[
        if (_assessment.levels.isNotEmpty) ...<Widget>[
          MmCard(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text('Reported independence', style: AppText.label)),
                    const SizedBox(width: Insets.sm),
                    Text('${_assessment.independencePercent}%',
                        style: AppText.stat.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                MeterBar(value: _assessment.independencePercent / 100),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
        ],
        for (final FunctionalItem item in FunctionCatalogue.items)
          ScaleQuestion(
            question: item.label,
            options: FunctionLevel.values
                .map((FunctionLevel l) => l.shortLabel)
                .toList(growable: false),
            selectedIndex: _assessment.levels[item.id]?.index,
            onSelect: (int i) => setState(() {
              _assessment = _assessment.withLevel(item.id, FunctionLevel.values[i]);
            }),
          ),
        const SizedBox(height: Insets.sm),
        const NotADiagnosisNote(
          message:
              'Needing help with an activity is common and has many causes — '
              'eyesight, arthritis, confidence, habit. This is recorded as '
              'context, not as evidence of a condition.',
        ),
      ],
    );
  }
}
