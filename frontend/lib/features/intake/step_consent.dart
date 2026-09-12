import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';

/// Consent — the screen the onboarding opens on.
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
      stepCount: IntakeRecord.order.length,
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
