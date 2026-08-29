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

/// Step 3 — why the person is here.
///
/// This is asked before anything is measured, and it is the most informative
/// screen in the intake. What someone came in worried about, when it started
/// and how it has changed frames every number that follows: the same score
/// means something different after "six months, gradually worse" than after
/// "I just want to keep an eye on things".
class ReasonStep extends StatefulWidget {
  const ReasonStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<ReasonStep> createState() => _ReasonStepState();
}

class _ReasonStepState extends State<ReasonStep> {
  late Set<PresentingConcern> _concerns;
  OnsetWindow? _onset;
  ProgressionPattern? _progression;

  @override
  void initState() {
    super.initState();
    final ReasonForVisit existing = AppScope.read(context).intake.reason;
    _concerns = Set<PresentingConcern>.from(existing.concerns);
    _onset = existing.onset;
    _progression = existing.progression;
  }

  bool get _valid => _concerns.isNotEmpty && _onset != null && _progression != null;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    return IntakeScaffold(
      stepIndex: 3,
      stepCount: 8,
      onBack: widget.onBack,
      title: l.intakeReasonTitle,
      subtitle: l.intakeReasonSubtitle,
      onContinue: _valid
          ? () {
              state.saveReason(ReasonForVisit(
                concerns: _concerns,
                onset: _onset,
                progression: _progression,
              ));
              widget.onDone();
            }
          : null,
      footnote: _valid ? null : l.intakeReasonFootnote,
      children: <Widget>[
        for (final PresentingConcern c in PresentingConcern.values)
          ChoiceTile(
            label: presentingConcernLabel(l, c),
            selected: _concerns.contains(c),
            multiple: true,
            onTap: () => setState(() {
              if (!_concerns.remove(c)) _concerns.add(c);
            }),
          ),
        const SizedBox(height: Insets.lg),
        Text(l.intakeReasonOnsetLabel, style: AppText.h3),
        const SizedBox(height: Insets.md),
        for (final OnsetWindow o in OnsetWindow.values)
          ChoiceTile(
            label: onsetWindowLabel(l, o),
            selected: _onset == o,
            onTap: () => setState(() => _onset = o),
          ),
        const SizedBox(height: Insets.lg),
        Text(l.intakeReasonProgressionLabel, style: AppText.h3),
        const SizedBox(height: Insets.md),
        for (final ProgressionPattern p in ProgressionPattern.values)
          ChoiceTile(
            label: progressionPatternLabel(l, p),
            selected: _progression == p,
            onTap: () => setState(() => _progression = p),
          ),
      ],
    );
  }
}

/// Step 4 — the safety screen.
///
/// Cognitive change that began within hours or days, or that arrives with
/// weakness, speech difficulty, fainting, seizure or a severe headache, is not
/// something to monitor over twelve weeks — several of its possible causes are
/// treatable and time-critical, so the app has to say so immediately.
///
/// It says so *in place*, as a compact warning on this screen, rather than by
/// taking the journey over. A full-screen interruption that has to be
/// dismissed reads as an obstacle and gets tapped past without being read;
/// keeping the questionnaire moving while the warning stays visible respects
/// both the urgency and the person's own judgement. Two ways forward, both
/// explicit: read the advice, or continue.
class SafetyStep extends StatefulWidget {
  const SafetyStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<SafetyStep> createState() => _SafetyStepState();
}

class _SafetyStepState extends State<SafetyStep> {
  late SafetyCheck _check;

  @override
  void initState() {
    super.initState();
    _check = AppScope.read(context).intake.safety;
  }

  void _showUrgentAdvice() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => const _UrgentAdviceDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final bool urgent = _check.requiresUrgentReview;

    return IntakeScaffold(
      stepIndex: 4,
      stepCount: 8,
      onBack: widget.onBack,
      voiceQuestions: <VoiceIntakeQuestion>[
        for (final (String prompt, bool? value, ValueChanged<bool> set)
            in <(String, bool?, ValueChanged<bool>)>[
          (
            l.intakeSafetyQuestionSuddenOnset,
            _check.suddenOnset,
            (bool v) => setState(() => _check = _check.copyWith(suddenOnset: v)),
          ),
          (
            l.intakeSafetyQuestionAlertness,
            _check.fluctuatingAlertness,
            (bool v) => setState(() => _check = _check.copyWith(fluctuatingAlertness: v)),
          ),
          (
            l.intakeSafetyQuestionNeuroRedFlag,
            _check.neurologicalRedFlag,
            (bool v) => setState(() => _check = _check.copyWith(neurologicalRedFlag: v)),
          ),
        ])
          VoiceIntakeQuestion(
            prompt: prompt,
            options: <String>[l.intakeYes, l.intakeNo],
            answeredIndex: value == null ? null : (value ? 0 : 1),
            onSelect: (int i) => set(i == 0),
          ),
      ],
      title: l.intakeSafetyTitle,
      subtitle: l.intakeSafetySubtitle,
      accent: AppColors.terracotta,
      footnote: urgent ? l.intakeSafetyFootnote : null,
      onContinue: _check.isComplete
          ? () {
              state.saveSafetyCheck(_check);
              widget.onDone();
            }
          : null,
      children: <Widget>[
        if (urgent) ...<Widget>[
          _UrgentNote(onConsult: _showUrgentAdvice),
          const SizedBox(height: Insets.md),
        ],
        _YesNo(
          question: l.intakeSafetyQuestionSuddenOnset,
          value: _check.suddenOnset,
          onChanged: (bool v) => setState(() => _check = _check.copyWith(suddenOnset: v)),
        ),
        _YesNo(
          question: l.intakeSafetyQuestionAlertnessDetailed,
          value: _check.fluctuatingAlertness,
          onChanged: (bool v) =>
              setState(() => _check = _check.copyWith(fluctuatingAlertness: v)),
        ),
        _YesNo(
          question: l.intakeSafetyQuestionNeuroRedFlag,
          value: _check.neurologicalRedFlag,
          onChanged: (bool v) =>
              setState(() => _check = _check.copyWith(neurologicalRedFlag: v)),
        ),
      ],
    );
  }
}

class _YesNo extends StatelessWidget {
  const _YesNo({required this.question, required this.value, required this.onChanged});

  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: MmCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(question, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: BigButton(
                    label: l.intakeNo,
                    height: 52,
                    outlined: value != false,
                    color: value == false ? AppColors.primary : AppColors.inkMuted,
                    onPressed: () => onChanged(false),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: BigButton(
                    label: l.intakeYes,
                    height: 52,
                    outlined: value != true,
                    color: value == true ? AppColors.terracotta : AppColors.inkMuted,
                    onPressed: () => onChanged(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The compact warning. Small on purpose: it has to be read, not dismissed.
class _UrgentNote extends StatelessWidget {
  const _UrgentNote({required this.onConsult});

  final VoidCallback onConsult;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      color: AppColors.dangerTint,
      padding: const EdgeInsets.all(Insets.md),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: Insets.sm),
              // Expanded, or a long translation runs off the right edge.
              Expanded(
                child: Text(
                  l.intakeSafetyUrgentTitle,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.intakeSafetyUrgentBody,
            style: AppText.bodySmall.copyWith(height: 1.45, color: AppColors.ink),
          ),
          const SizedBox(height: Insets.sm),
          SoftButton(
            label: l.intakeSafetyConsultDoctor,
            icon: Icons.local_hospital_outlined,
            color: AppColors.danger,
            filled: true,
            onPressed: onConsult,
          ),
        ],
      ),
    );
  }
}

/// The full advice, shown only when asked for.
class _UrgentAdviceDialog extends StatelessWidget {
  const _UrgentAdviceDialog();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.lg)),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(l.intakeSafetyDialogTitle, style: AppText.h3)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l.intakeSafetyDialogBody1,
              style: AppText.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: Insets.md),
            Text(
              l.intakeSafetyDialogBody2,
              style: AppText.body.copyWith(fontWeight: FontWeight.w700, height: 1.5),
            ),
            const SizedBox(height: Insets.md),
            NotADiagnosisNote(
              compact: true,
              message: l.intakeSafetyDialogDisclaimer,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose, style: AppText.body.copyWith(color: AppColors.primary)),
        ),
      ],
    );
  }
}