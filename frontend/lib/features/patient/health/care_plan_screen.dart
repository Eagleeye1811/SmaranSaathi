import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/assessment.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../intake/intake_kit.dart';

/// What happens next.
///
/// A monitoring app that ends at "here is your score" leaves the person
/// exactly where they started. The plan is generated from their own record —
/// what they are already doing, what is due, and what the results suggest
/// keeping an eye on — and it is explicit that the clinical parts are for a
/// clinician to confirm.
class CarePlanScreen extends StatelessWidget {
  const CarePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;
    final IntakeRecord intake = state.intake;
    final DateTime nextReview = DateTime.now().add(const Duration(days: 28));

    final List<({IconData icon, String title, String detail, bool done})> items =
        <({IconData icon, String title, String detail, bool done})>[
      (
        icon: Icons.event_repeat_rounded,
        title: l.carePlanWeeklyAssessmentTitle,
        detail: l.carePlanWeeklyAssessmentDetail(
            snapshot.assessmentsCompleted, snapshot.assessmentsExpected),
        done: snapshot.adherencePercent >= 70,
      ),
      (
        icon: Icons.extension_rounded,
        title: l.carePlanDailyActivityTitle,
        detail: l.carePlanDailyActivityDetail,
        done: state.completedToday.isNotEmpty,
      ),
      if (state.medicineTotal > 0)
        (
          icon: Icons.medication_outlined,
          title: l.carePlanMedicationTitle,
          detail: l.carePlanMedicationDetail(state.medicineDone, state.medicineTotal),
          done: state.medicineDone == state.medicineTotal,
        ),
      if (intake.caregiver != null)
        (
          icon: Icons.people_alt_outlined,
          title: l.carePlanCaregiverCheckInTitle,
          detail: l.carePlanCaregiverCheckInDetail(intake.caregiver!.caregiverName),
          done: true,
        ),
      (
        icon: Icons.medical_information_outlined,
        title: snapshot.suggestsClinicalDiscussion
            ? l.carePlanDiscussWithDoctor
            : l.carePlanKeepSummaryReady,
        detail: snapshot.suggestsClinicalDiscussion
            ? l.carePlanDiscussDetail
            : l.carePlanKeepReadyDetail,
        done: false,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
          children: <Widget>[
            ScreenHeader(
              eyebrow: l.carePlanEyebrow,
              title: l.carePlanTitle,
              subtitle: l.carePlanSubtitle,
              leading: RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: Insets.lg),
            for (final ({IconData icon, String title, String detail, bool done}) item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: MmCard(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SoftIcon(
                        icon: item.done ? Icons.check_rounded : item.icon,
                        color: item.done ? AppColors.success : AppColors.primary,
                        background:
                            item.done ? AppColors.successTint : AppColors.primaryTint,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.title,
                                style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(item.detail,
                                style: AppText.bodySmall.copyWith(height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Insets.md),
            MmCard(
              color: AppColors.secondaryTint,
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: <Widget>[
                  const SoftIcon(
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.secondary,
                    background: Colors.white,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.carePlanNextReview, style: AppText.label),
                        Text(
                          '${nextReview.day} '
                          '${monthFullLabel(l, nextReview.month)} ${nextReview.year}',
                          style: AppText.h3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            NotADiagnosisNote(
              message: l.carePlanDisclaimer,
            ),
          ],
        ),
      ),
    );
  }
}
