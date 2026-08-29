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

/// Step 1 — consent.
///
/// Deliberately one screen rather than a scrolling agreement: the person needs
/// to know what is collected, what it is for, and that it is not a diagnosis.
/// Everything else belongs in a privacy policy, not in front of someone who
/// came here worried about their memory.
class ConsentStep extends StatefulWidget {
  const ConsentStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<ConsentStep> createState() => _ConsentStepState();
}

class _ConsentStepState extends State<ConsentStep> {
  bool _understood = false;

  static List<({IconData icon, String label, String detail})> _collected(AppLocalizations l) =>
      <({IconData icon, String label, String detail})>[
    (
      icon: Icons.psychology_alt_rounded,
      label: l.intakeConsentSymptomsLabel,
      detail: l.intakeConsentSymptomsDetail,
    ),
    (
      icon: Icons.home_work_outlined,
      label: l.intakeConsentDailyActivitiesLabel,
      detail: l.intakeConsentDailyActivitiesDetail,
    ),
    (
      icon: Icons.insights_rounded,
      label: l.intakeConsentActivityPerformanceLabel,
      detail: l.intakeConsentActivityPerformanceDetail,
    ),
    (
      icon: Icons.medical_information_outlined,
      label: l.intakeConsentHealthHistoryLabel,
      detail: l.intakeConsentHealthHistoryDetail,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    return IntakeScaffold(
      stepIndex: 1,
      stepCount: 8,
      onBack: widget.onBack,
      // Voice starts here, on the first screen of the intake, so someone who
      // cannot read the consent text can still be told it and agree to it.
      voiceQuestions: <VoiceIntakeQuestion>[
        VoiceIntakeQuestion(
          prompt: l.intakeConsentVoicePrompt,
          options: <String>[l.intakeYes, l.intakeNo],
          answeredIndex: _understood ? 0 : null,
          onSelect: (int i) => setState(() => _understood = i == 0),
        ),
      ],
      title: l.intakeConsentTitle,
      subtitle: l.intakeConsentSubtitle,
      onContinue: _understood
          ? () {
              state.giveConsent();
              widget.onDone();
            }
          : null,
      footnote: _understood ? null : l.intakeConsentFootnote,
      children: <Widget>[
        for (final ({IconData icon, String label, String detail}) c in _collected(l))
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: MmCard(
              padding: const EdgeInsets.all(Insets.md),
              child: ListRow(
                leading: SoftIcon(icon: c.icon, size: 42),
                title: c.label,
                subtitle: c.detail,
              ),
            ),
          ),
        const SizedBox(height: Insets.sm),
        MmCard(
          color: AppColors.primaryTint,
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.intakeConsentUsageTitle, style: AppText.label),
              const SizedBox(height: Insets.xs),
              Text(
                l.intakeConsentUsageBody,
                style: AppText.bodySmall.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        ChoiceTile(
          label: l.intakeConsentDiagnosisAck,
          description: l.intakeConsentDiagnosisAckDetail,
          selected: _understood,
          multiple: true,
          onTap: () => setState(() => _understood = !_understood),
        ),
      ],
    );
  }
}

/// Step 2 — who this is about.
///
/// Age, language and profession are collected because they change how a
/// cognitive result should be read, and they are printed on the report so the
/// clinician can weigh them rather than the app adjusting a score silently.
///
/// The profession earns its place twice over: it is also what
/// `PersonalizationService` reads to decide which procedures and stories the
/// activities are built from, so a weaver rebuilds a loom sequence rather than
/// a generic one.
class ProfileStep extends StatefulWidget {
  const ProfileStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _profession;
  String _language = 'Assamese';
  CompletedBy? _completedBy;

  static const List<String> _languages = <String>[
    'Assamese', 'Hindi', 'English', 'Bodo', 'Khasi', 'Mizo', 'Manipuri', 'Nepali',
  ];

  @override
  void initState() {
    super.initState();
    final AppState state = AppScope.read(context);
    _name = TextEditingController(text: state.patient.name);
    _age = TextEditingController(text: state.patient.age.toString());
    _profession = TextEditingController(text: state.patient.occupation);
    _language = _languages.contains(state.patient.language) ? state.patient.language : 'Assamese';
    _completedBy = state.intake.completedBy;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _profession.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (int.tryParse(_age.text.trim()) ?? 0) > 0 &&
      _profession.text.trim().isNotEmpty &&
      _completedBy != null;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    return IntakeScaffold(
      stepIndex: 2,
      stepCount: 8,
      onBack: widget.onBack,
      // Name and profession are dictated, age is a spoken number, and the
      // last two are ordinary choices — so the whole screen can be completed
      // without touching the keyboard, which for this app's users is the
      // difference between filling it in and not.
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
        VoiceIntakeQuestion.dictated(
          prompt: l.intakeProfileProfessionPrompt,
          answered: _profession.text,
          onSpeak: (String value) => setState(() => _profession.text = value),
        ),
        VoiceIntakeQuestion(
          prompt: l.intakeProfileCompletedByPrompt,
          options: CompletedBy.values
              .map((CompletedBy c) => completedByLabel(l, c))
              .toList(growable: false),
          answeredIndex: _completedBy?.index,
          onSelect: (int i) => setState(() => _completedBy = CompletedBy.values[i]),
        ),
      ],
      title: l.intakeProfileTitle,
      subtitle: l.intakeProfileSubtitle,
      onContinue: _valid
          ? () {
              state.saveIntakeProfile(
                name: _name.text,
                age: int.parse(_age.text.trim()),
                language: _language,
                occupation: _profession.text,
                completedBy: _completedBy,
              );
              widget.onDone();
            }
          : null,
      children: <Widget>[
        _Field(label: l.intakeProfileNameLabel, controller: _name, onChanged: () => setState(() {})),
        _Field(
          label: l.intakeProfileAgeLabel,
          controller: _age,
          keyboardType: TextInputType.number,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: Insets.sm),
        Text(l.intakeProfileLanguageLabel, style: AppText.label),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String l in _languages)
              Pressable(
                onTap: () => setState(() => _language = l),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: _language == l ? AppColors.primary : AppColors.surface,
                    borderRadius: Corners.r(Corners.pill),
                    border: Border.all(
                        color: _language == l ? AppColors.primary : AppColors.hairline),
                  ),
                  child: Text(l,
                      style: AppText.bodySmall.copyWith(
                        color: _language == l ? Colors.white : AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        _Field(
          label: l.intakeProfileProfessionLabel,
          controller: _profession,
          onChanged: () => setState(() {}),
          hint: l.intakeProfileProfessionHint,
        ),
        // Quick picks rather than a fixed list: one tap for the common cases,
        // free text for everything else.
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String job in ProfessionSuggestions.common)
              Pressable(
                onTap: () => setState(() => _profession.text = job),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _profession.text.trim().toLowerCase() == job.toLowerCase()
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: Corners.r(Corners.pill),
                    border: Border.all(
                      color: _profession.text.trim().toLowerCase() == job.toLowerCase()
                          ? AppColors.primary
                          : AppColors.hairline,
                    ),
                  ),
                  child: Text(
                    job,
                    style: AppText.bodySmall.copyWith(
                      color: _profession.text.trim().toLowerCase() == job.toLowerCase()
                          ? Colors.white
                          : AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        Text(l.intakeProfileCompletedByLabel, style: AppText.label),
        const SizedBox(height: Insets.sm),
        for (final CompletedBy c in CompletedBy.values)
          ChoiceTile(
            label: completedByLabel(l, c),
            selected: _completedBy == c,
            onTap: () => setState(() => _completedBy = c),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppText.label),
          const SizedBox(height: Insets.xs),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppText.bodyLarge,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: Corners.r(Corners.md),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: Corners.r(Corners.md),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: Corners.r(Corners.md),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
