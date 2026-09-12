import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../l10n/app_localizations.dart';
import 'assessment_l10n.dart';
import 'intake_kit.dart';

/// Step 7 — medical and lifestyle context.
///
/// Collected because several ordinary, treatable things move a cognitive score
/// on their own: short or poor sleep, low mood, thyroid problems, a long
/// medication list. Without them, a dip in performance reads as decline when
/// it may be a bad fortnight.
class MedicalStep extends StatefulWidget {
  const MedicalStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<MedicalStep> createState() => _MedicalStepState();
}

class _MedicalStepState extends State<MedicalStep> {
  late MedicalHistory _history;
  final TextEditingController _medication = TextEditingController();

  @override
  void initState() {
    super.initState();
    _history = AppScope.read(context).intake.medical;
  }

  @override
  void dispose() {
    _medication.dispose();
    super.dispose();
  }

  void _addMedication() {
    final String value = _medication.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _history = _history.copyWith(
        medications: <String>[..._history.medications, value],
      );
      _medication.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    return IntakeScaffold(
      stepIndex: 7,
      stepCount: 8,
      onBack: widget.onBack,
      // The two questions that gate this step. The conditions and medication
      // lists are not read aloud: picking from a long list by voice is slower
      // than tapping it, and both are optional.
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion(
          prompt: l.intakeMedicalSleepPrompt,
          options: SleepQuality.values
              .map((SleepQuality q) => sleepQualityLabel(l, q))
              .toList(growable: false),
          answeredIndex: _history.sleepQuality?.index,
          onSelect: (int i) => setState(
              () => _history = _history.copyWith(sleepQuality: SleepQuality.values[i])),
        ),
        VoiceIntakeQuestion(
          prompt: l.intakeMedicalMoodPrompt,
          options: MoodFrequency.values
              .map((MoodFrequency m) => moodFrequencyLabel(l, m))
              .toList(growable: false),
          answeredIndex: _history.lowMood?.index,
          onSelect: (int i) => setState(
              () => _history = _history.copyWith(lowMood: MoodFrequency.values[i])),
        ),
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeMedicalAddMedicationPrompt,
          onSpeak: (String value) {
            final String v = value.trim();
            if (v.isEmpty) return;
            setState(() {
              _history =
                  _history.copyWith(medications: <String>[..._history.medications, v]);
            });
          },
        ),
      ],
      title: l.intakeMedicalTitle,
      subtitle: l.intakeMedicalSubtitle,
      onContinue: _history.isComplete
          ? () {
              state.saveMedicalHistory(_history);
              widget.onDone();
            }
          : null,
      footnote: _history.isComplete ? null : l.intakeMedicalFootnote,
      children: <Widget>[
        Text(l.intakeMedicalConditionsLabel, style: AppText.label),
        const SizedBox(height: Insets.sm),
        for (final MedicalCondition c in MedicalCondition.values)
          ChoiceTile(
            label: medicalConditionLabel(l, c),
            selected: _history.conditions.contains(c),
            multiple: true,
            onTap: () => setState(() {
              final Set<MedicalCondition> next =
                  Set<MedicalCondition>.from(_history.conditions);
              if (!next.remove(c)) next.add(c);
              _history = _history.copyWith(conditions: next);
            }),
          ),
        const SizedBox(height: Insets.lg),
        Text(l.intakeMedicalSleepSectionTitle, style: AppText.h3),
        const SizedBox(height: Insets.sm),
        MmCard(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(l.intakeMedicalSleepHoursLabel, style: AppText.body)),
                  const SizedBox(width: Insets.sm),
                  Text('${_history.sleepHours.toStringAsFixed(1)} h',
                      style: AppText.stat.copyWith(color: AppColors.secondary)),
                ],
              ),
              Slider(
                value: _history.sleepHours,
                min: 3,
                max: 12,
                divisions: 18,
                activeColor: AppColors.secondary,
                onChanged: (double v) =>
                    setState(() => _history = _history.copyWith(sleepHours: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        ScaleQuestion(
          question: l.intakeMedicalSleepQualityLabel,
          options: SleepQuality.values
              .map((SleepQuality q) => sleepQualityLabel(l, q))
              .toList(growable: false),
          selectedIndex: _history.sleepQuality?.index,
          onSelect: (int i) => setState(
              () => _history = _history.copyWith(sleepQuality: SleepQuality.values[i])),
        ),
        const SizedBox(height: Insets.md),
        Text(l.intakeMedicalMoodSectionTitle, style: AppText.h3),
        const SizedBox(height: Insets.sm),
        ScaleQuestion(
          question: l.intakeMedicalMoodPrompt,
          options: MoodFrequency.values
              .map((MoodFrequency m) => moodFrequencyLabel(l, m))
              .toList(growable: false),
          selectedIndex: _history.lowMood?.index,
          onSelect: (int i) =>
              setState(() => _history = _history.copyWith(lowMood: MoodFrequency.values[i])),
        ),
        const SizedBox(height: Insets.md),
        Text(l.intakeMedicalMedicationSectionTitle, style: AppText.h3),
        const SizedBox(height: Insets.sm),
        for (final String m in _history.medications)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.xs),
            child: MmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
              child: Row(
                children: <Widget>[
                  const SoftIcon(icon: Icons.medication_outlined, size: 36),
                  const SizedBox(width: Insets.sm),
                  Expanded(child: Text(m, style: AppText.body)),
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    size: 36,
                    tooltip: l.intakeMedicalRemoveMedication,
                    onPressed: () => setState(() {
                      _history = _history.copyWith(
                        medications: _history.medications
                            .where((String x) => x != m)
                            .toList(growable: false),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _medication,
                style: AppText.body,
                onSubmitted: (_) => _addMedication(),
                decoration: InputDecoration(
                  hintText: l.intakeMedicalAddMedicationHint,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: Corners.r(Corners.md),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: Corners.r(Corners.md),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            RoundIconButton(icon: Icons.add_rounded, onPressed: _addMedication),
          ],
        ),
      ],
    );
  }
}

/// Step 8 — caregiver corroboration.
///
/// Optional, and the highest-value optional screen in the app. People with
/// cognitive change frequently under-report it; the person who lives with them
/// frequently does not. Two independent accounts of the same three months are
/// worth more than either alone, and the report keeps them clearly separate.
class CaregiverStep extends StatefulWidget {
  const CaregiverStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<CaregiverStep> createState() => _CaregiverStepState();
}

class _CaregiverStepState extends State<CaregiverStep> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _relation = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final Map<String, bool> _observations = <String, bool>{};
  bool _invited = false;

  @override
  void initState() {
    super.initState();
    final CaregiverObservation? existing = AppScope.read(context).intake.caregiver;
    if (existing != null) {
      _name.text = existing.caregiverName;
      _relation.text = existing.relation;
      _note.text = existing.note;
      _observations.addAll(existing.observations);
      _invited = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    state.saveCaregiverObservation(CaregiverObservation(
      caregiverName:
          _name.text.trim().isEmpty ? l.intakeCaregiverDefaultName : _name.text.trim(),
      relation: _relation.text.trim(),
      observations: Map<String, bool>.from(_observations),
      note: _note.text.trim(),
      receivedAtIso: DateTime.now().toIso8601String(),
    ));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (!_invited) {
      return IntakeScaffold(
        stepIndex: 8,
        stepCount: 8,
        onBack: widget.onBack,
        title: l.intakeCaregiverInviteTitle,
        subtitle: l.intakeCaregiverInviteSubtitle,
        continueLabel: l.intakeCaregiverAddObservations,
        onContinue: () => setState(() => _invited = true),
        secondaryLabel: l.intakeCaregiverSkip,
        onSecondary: widget.onDone,
        children: <Widget>[
          MmCard(
            color: AppColors.secondaryTint,
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SoftIcon(
                  icon: Icons.people_alt_rounded,
                  color: AppColors.secondary,
                  size: 52,
                ),
                const SizedBox(height: Insets.md),
                Text(l.intakeCaregiverWhyHelpsTitle, style: AppText.h3),
                const SizedBox(height: Insets.xs),
                Text(
                  l.intakeCaregiverWhyHelpsBody,
                  style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return IntakeScaffold(
      stepIndex: 8,
      stepCount: 8,
      onBack: () => setState(() => _invited = false),
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeCaregiverNamePrompt,
          answered: _name.text,
          onSpeak: (String value) => setState(() => _name.text = value),
        ),
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeCaregiverRelationPrompt,
          answered: _relation.text,
          onSpeak: (String value) => setState(() => _relation.text = value),
        ),
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeCaregiverNotePrompt,
          answered: _note.text,
          onSpeak: (String value) => setState(() => _note.text = value),
        ),
      ],
      title: l.intakeCaregiverObservationsTitle,
      subtitle: l.intakeCaregiverObservationsSubtitle,
      accent: AppColors.secondary,
      onContinue: _observations.isEmpty ? null : _save,
      secondaryLabel: l.intakeCaregiverSkip,
      onSecondary: widget.onDone,
      footnote: _observations.isEmpty ? l.intakeCaregiverObservationsFootnote : null,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _MiniField(label: l.intakeCaregiverNameLabel, controller: _name)),
            const SizedBox(width: Insets.sm),
            Expanded(
                child: _MiniField(label: l.intakeCaregiverRelationLabel, controller: _relation)),
          ],
        ),
        const SizedBox(height: Insets.md),
        for (final ({String id, String label}) o in CaregiverObservation.catalogue)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: MmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(caregiverObservationLabel(l, o.id, o.label), style: AppText.body)),
                  _TinyToggle(
                    value: _observations[o.id],
                    onChanged: (bool v) => setState(() => _observations[o.id] = v),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Insets.sm),
        _MiniField(label: l.intakeCaregiverNoteLabel, controller: _note, lines: 3),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.label, required this.controller, this.lines = 1});

  final String label;
  final TextEditingController controller;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppText.label),
        const SizedBox(height: Insets.xs),
        TextField(
          controller: controller,
          maxLines: lines,
          style: AppText.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: Corners.r(Corners.md),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Corners.r(Corners.md),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
          ),
        ),
      ],
    );
  }
}

class _TinyToggle extends StatelessWidget {
  const _TinyToggle({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Opt(label: l.intakeNo, selected: value == false, color: AppColors.inkMuted, onTap: () => onChanged(false)),
        const SizedBox(width: Insets.xs),
        _Opt(label: l.intakeYes, selected: value == true, color: AppColors.secondary, onTap: () => onChanged(true)),
      ],
    );
  }
}

class _Opt extends StatelessWidget {
  const _Opt({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surfaceMuted,
          borderRadius: Corners.r(Corners.pill),
          border: Border.all(color: selected ? color : AppColors.hairline),
        ),
        child: Text(label,
            style: AppText.bodySmall.copyWith(
              color: selected ? Colors.white : AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}
