import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/onboarding.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../l10n/app_localizations.dart';
import 'assessment_l10n.dart';
import 'intake_kit.dart';
import 'onboarding_l10n.dart';

/// Everything an onboarding screen needs to read and write its answers.
///
/// The record lives in [AppState]; a screen edits a local copy and files it on
/// "Continue". Editing in place would write a half-answered screen to disk on
/// every tap, and a resumed intake would then land in the middle of a question
/// rather than at the start of it.
mixin OnboardingStep<T extends StatefulWidget> on State<T> {
  late final AppState state = AppScope.read(context);

  /// The working copy. Seeded from what is already stored, so going back to a
  /// finished screen shows the answers rather than a blank form.
  late OnboardingRecord draft = state.intake.onboarding;

  void edit(OnboardingRecord Function(OnboardingRecord) change) =>
      setState(() => draft = change(draft));

  /// Files the screen and moves on.
  void commit(VoidCallback onDone) {
    state.saveOnboarding(draft);
    onDone();
  }

  /// 1-based position of [step] in the onboarding, for the progress line.
  int indexOf(IntakeStep step) => IntakeRecord.order.indexOf(step) + 1;

  int get stepTotal => IntakeRecord.order.length;

  String partLabelFor(AppLocalizations l, IntakeStep step) => switch (step.part) {
        IntakePart.knowThePerson => l.onbPartKnowPerson,
        IntakePart.knowTheirLife => l.onbPartKnowLife,
        IntakePart.setup => '',
      };

  /// Toggles a value in a set answer, the gesture every multi-select uses.
  Set<E> toggled<E>(Set<E> current, E value) {
    final Set<E> next = <E>{...current};
    if (!next.remove(value)) next.add(value);
    return next;
  }

  /// The same, but for an answer where one option means "none of the above"
  /// and so has to clear everything else — and be cleared by everything else.
  Set<E> toggledExclusive<E>(Set<E> current, E value, E exclusive) {
    if (value == exclusive) {
      return current.contains(exclusive) ? <E>{} : <E>{exclusive};
    }
    final Set<E> next = toggled(current, value)..remove(exclusive);
    return next;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Q1 — about the person
// ─────────────────────────────────────────────────────────────────────────

/// Name, age, language, education, occupation, and who is answering.
///
/// Six details on one screen rather than six screens, because none of them is
/// hard and splitting them would make the onboarding feel twice as long as it
/// is. The two that are *not* obvious — education and who is answering — carry
/// a short note saying why they are asked, since both look like idle curiosity
/// and neither is.
class PersonStep extends StatefulWidget {
  const PersonStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<PersonStep> createState() => _PersonStepState();
}

class _PersonStepState extends State<PersonStep> with OnboardingStep<PersonStep> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _occupation;
  late final TextEditingController _caregiverName;
  late String _language;

  static const List<String> _languages = <String>[
    'Assamese', 'Hindi', 'English', 'Bodo', 'Khasi', 'Mizo', 'Manipuri', 'Nepali',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: state.patient.name);
    _age = TextEditingController(
        text: state.patient.age > 0 ? state.patient.age.toString() : '');
    _occupation = TextEditingController(text: state.patient.occupation);
    _caregiverName = TextEditingController(text: draft.caregiverName);
    _language =
        _languages.contains(state.patient.language) ? state.patient.language : 'Assamese';
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _occupation.dispose();
    _caregiverName.dispose();
    super.dispose();
  }

  /// Someone answering for another person has to say who they are; someone
  /// answering for themselves has nobody else to name.
  bool get _needsCaregiverName => draft.helper?.isSomeoneElse ?? false;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (int.tryParse(_age.text.trim()) ?? 0) > 0 &&
      draft.education != null &&
      draft.helper != null &&
      (!_needsCaregiverName || _caregiverName.text.trim().isNotEmpty);

  void _save() {
    edit((OnboardingRecord d) => d.copyWith(caregiverName: _caregiverName.text.trim()));
    // The identifying details belong to the patient, not to the questionnaire:
    // the occupation in particular is what PersonalizationService reads to
    // decide whether the activities rebuild a loom or a classroom.
    state.saveIntakeProfile(
      name: _name.text,
      age: int.parse(_age.text.trim()),
      language: _language,
      occupation: _occupation.text,
      completedBy: draft.helper?.completedBy,
    );
    commit(widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.person;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbPersonTitle,
      subtitle: l.onbPersonSubtitle,
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeProfileNamePrompt,
          answered: _name.text,
          onSpeak: (String value) => setState(() => _name.text = value),
        ),
        VoiceIntakeQuestion.number(
          prompt: l.intakeProfileAgePrompt,
          answered: _age.text,
          onSpeak: (int value) => setState(() => _age.text = value.toString()),
        ),
        VoiceIntakeQuestion(
          prompt: l.intakeProfileLanguagePrompt,
          options: _languages,
          answeredIndex: _languages.indexOf(_language),
          onSelect: (int i) => setState(() => _language = _languages[i]),
        ),
        VoiceIntakeQuestion(
          prompt: l.onbEducationLabel,
          options: EducationLevel.values
              .map((EducationLevel e) => educationLabel(l, e))
              .toList(growable: false),
          answeredIndex: draft.education?.index,
          onSelect: (int i) =>
              edit((OnboardingRecord d) => d.copyWith(education: EducationLevel.values[i])),
        ),
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeProfileProfessionPrompt,
          answered: _occupation.text,
          onSpeak: (String value) => setState(() => _occupation.text = value),
        ),
        VoiceIntakeQuestion(
          prompt: l.onbHelperLabel,
          options:
              HelperRole.values.map((HelperRole r) => helperRoleLabel(l, r)).toList(growable: false),
          answeredIndex: draft.helper?.index,
          onSelect: (int i) =>
              edit((OnboardingRecord d) => d.copyWith(helper: HelperRole.values[i])),
        ),
        if (_needsCaregiverName)
          VoiceIntakeQuestion.dictated(
            prompt: l.onbCaregiverNamePrompt,
            answered: _caregiverName.text,
            onSpeak: (String value) => setState(() => _caregiverName.text = value),
          ),
      ],
      onContinue: _valid ? _save : null,
      children: <Widget>[
        IntakeField(
          label: l.intakeProfileNameLabel,
          controller: _name,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: l.intakeProfileAgeLabel,
          controller: _age,
          keyboardType: TextInputType.number,
          onChanged: () => setState(() {}),
        ),
        Text(l.intakeProfileLanguageLabel, style: AppText.label),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String lang in _languages)
              ChipChoice(
                label: lang,
                selected: _language == lang,
                onTap: () => setState(() => _language = lang),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbEducationLabel),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final EducationLevel e in EducationLevel.values)
              ChipChoice(
                label: educationLabel(l, e),
                selected: draft.education == e,
                onTap: () => edit((OnboardingRecord d) => d.copyWith(education: e)),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        WhyWeAsk(l.onbEducationWhy),
        IntakeField(
          label: l.intakeProfileProfessionLabel,
          hint: l.intakeProfileProfessionHint,
          controller: _occupation,
          onChanged: () => setState(() {}),
        ),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String job in ProfessionSuggestions.common)
              ChipChoice(
                label: job,
                selected: _occupation.text.trim().toLowerCase() == job.toLowerCase(),
                onTap: () => setState(() => _occupation.text = job),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbHelperLabel),
        for (final HelperRole r in HelperRole.values)
          ChoiceTile(
            label: helperRoleLabel(l, r),
            selected: draft.helper == r,
            onTap: () => edit((OnboardingRecord d) => d.copyWith(helper: r)),
          ),
        // Only once they have said they are someone else. Asking "and your
        // name?" of a person who just answered "myself" would be absurd.
        if (_needsCaregiverName) ...<Widget>[
          const SizedBox(height: Insets.md),
          IntakeField(
            label: l.onbCaregiverNameLabel,
            hint: l.onbCaregiverNameHint,
            controller: _caregiverName,
            onChanged: () => setState(() {}),
          ),
        ],
        const SizedBox(height: Insets.sm),
        WhyWeAsk(l.onbHelperWhy),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Q2–Q5 — health and care background
// ─────────────────────────────────────────────────────────────────────────

/// Diagnosis, the condition named, who is involved, and current treatment.
///
/// The condition question only opens when a diagnosis was actually given, and
/// the medicine questions only when treatment was. A caregiver who answered
/// "no" twice sees two questions here, not five.
class HealthBackgroundStep extends StatefulWidget {
  const HealthBackgroundStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<HealthBackgroundStep> createState() => _HealthBackgroundStepState();
}

class _HealthBackgroundStepState extends State<HealthBackgroundStep>
    with OnboardingStep<HealthBackgroundStep> {
  late final TextEditingController _medicines;

  @override
  void initState() {
    super.initState();
    _medicines = TextEditingController(text: draft.medicines.join('\n'));
  }

  @override
  void dispose() {
    _medicines.dispose();
    super.dispose();
  }

  List<String> get _medicineLines => <String>[
        for (final String line in _medicines.text.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];

  bool get _showsCondition => draft.diagnosisStatus == DiagnosisStatus.yes;
  bool get _showsMedicines => draft.treatmentStatus == TreatmentStatus.yes;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const IntakeStep here = IntakeStep.health;

    return IntakeScaffold(
      stepIndex: indexOf(here),
      stepCount: stepTotal,
      partLabel: partLabelFor(l, here),
      onBack: widget.onBack,
      title: l.onbHealthTitle,
      subtitle: l.onbHealthSubtitle,
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion(
          prompt: l.onbDiagnosisQuestion,
          options: DiagnosisStatus.values
              .map((DiagnosisStatus s) => diagnosisStatusLabel(l, s))
              .toList(growable: false),
          answeredIndex: draft.diagnosisStatus?.index,
          onSelect: (int i) => edit((OnboardingRecord d) =>
              d.copyWith(diagnosisStatus: DiagnosisStatus.values[i])),
        ),
        VoiceIntakeQuestion(
          prompt: l.onbTreatmentQuestion,
          options: TreatmentStatus.values
              .map((TreatmentStatus s) => treatmentStatusLabel(l, s))
              .toList(growable: false),
          answeredIndex: draft.treatmentStatus?.index,
          onSelect: (int i) => edit((OnboardingRecord d) =>
              d.copyWith(treatmentStatus: TreatmentStatus.values[i])),
        ),
      ],
      // The medicine box is free text, so it is read off the controller at
      // the moment of saving rather than on every keystroke.
      onContinue: draft.healthDone
          ? () {
              edit((OnboardingRecord d) => d.copyWith(medicines: _medicineLines));
              commit(widget.onDone);
            }
          : null,
      children: <Widget>[
        QuestionLabel(l.onbDiagnosisQuestion, number: 2),
        for (final DiagnosisStatus s in DiagnosisStatus.values)
          ChoiceTile(
            label: diagnosisStatusLabel(l, s),
            selected: draft.diagnosisStatus == s,
            onTap: () =>
                edit((OnboardingRecord d) => d.copyWith(diagnosisStatus: s)),
          ),

        if (_showsCondition) ...<Widget>[
          const SizedBox(height: Insets.lg),
          QuestionLabel(l.onbConditionQuestion, number: 3, hint: l.onbSelectAll),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final DiagnosedCondition c in DiagnosedCondition.values)
                ChipChoice(
                  label: diagnosedConditionLabel(l, c),
                  selected: draft.diagnosedConditions.contains(c),
                  onTap: () => edit((OnboardingRecord d) => d.copyWith(
                        diagnosedConditions: toggled(d.diagnosedConditions, c),
                      )),
                ),
            ],
          ),
        ],

        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbProfessionalsQuestion, number: 4, hint: l.onbSelectAll),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final CareProfessional p in CareProfessional.values)
              ChipChoice(
                label: careProfessionalLabel(l, p),
                selected: draft.professionals.contains(p),
                onTap: () => edit((OnboardingRecord d) => d.copyWith(
                      professionals: toggledExclusive(
                          d.professionals, p, CareProfessional.noRegularSupport),
                    )),
              ),
          ],
        ),

        const SizedBox(height: Insets.lg),
        QuestionLabel(l.onbTreatmentQuestion, number: 5),
        for (final TreatmentStatus s in TreatmentStatus.values)
          ChoiceTile(
            label: treatmentStatusLabel(l, s),
            selected: draft.treatmentStatus == s,
            onTap: () =>
                edit((OnboardingRecord d) => d.copyWith(treatmentStatus: s)),
          ),

        if (_showsMedicines) ...<Widget>[
          const SizedBox(height: Insets.md),
          IntakeField(
            label: '${l.onbMedicinesLabel}  ·  ${l.onbOptional}',
            hint: l.onbMedicinesHint,
            controller: _medicines,
            lines: 3,
            onChanged: () => setState(() {}),
          ),
          QuestionLabel(l.onbSedatingQuestion, hint: l.onbSelectAll),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final SedatingMedicineClass c in SedatingMedicineClass.values)
                ChipChoice(
                  label: sedatingMedicineLabel(l, c),
                  selected: draft.sedatingMedicines.contains(c),
                  onTap: () => edit((OnboardingRecord d) => d.copyWith(
                        sedatingMedicines: toggledExclusive(
                            d.sedatingMedicines, c, SedatingMedicineClass.noneOfThese),
                      )),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          // Shown only once something has been ticked, so it reads as an
          // answer to what was just said rather than as a general warning.
          if (draft.anticholinergicBurden > 0)
            _MedicineCaution(message: l.onbSedatingNote),
        ],

        const SizedBox(height: Insets.lg),
        QuestionLabel('${l.onbHealthConditionsLabel}  ·  ${l.onbOptional}',
            hint: l.onbSelectAll),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final MedicalCondition c in MedicalCondition.values)
              ChipChoice(
                label: medicalConditionLabel(l, c),
                selected: draft.healthConditions.contains(c),
                onTap: () => edit((OnboardingRecord d) =>
                    d.copyWith(healthConditions: toggled(d.healthConditions, c))),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        const NotADiagnosisNote(),
      ],
    );
  }
}

/// The anticholinergic note.
///
/// Amber rather than red, and phrased as "ask", because the only correct
/// action here is a conversation with the prescriber — a caregiver who stops a
/// medicine on the strength of an app screen has been actively harmed by it.
class _MedicineCaution extends StatelessWidget {
  const _MedicineCaution({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.medication_outlined, size: 20, color: AppColors.accent),
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
