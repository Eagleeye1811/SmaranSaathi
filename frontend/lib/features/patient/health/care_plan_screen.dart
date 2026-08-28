import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/assessment.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
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
    final MonitoringSnapshot snapshot = state.monitoring;
    final IntakeRecord intake = state.intake;
    final DateTime nextReview = DateTime.now().add(const Duration(days: 28));

    final List<({IconData icon, String title, String detail, bool done})> items =
        <({IconData icon, String title, String detail, bool done})>[
      (
        icon: Icons.event_repeat_rounded,
        title: 'Weekly assessment',
        detail: 'Six activities once a week keeps the trend meaningful. '
            '${snapshot.assessmentsCompleted} of ${snapshot.assessmentsExpected} weeks completed so far.',
        done: snapshot.adherencePercent >= 70,
      ),
      (
        icon: Icons.extension_rounded,
        title: 'Daily activity',
        detail: 'One short activity a day, chosen for you.',
        done: state.completedToday.isNotEmpty,
      ),
      if (state.medicineTotal > 0)
        (
          icon: Icons.medication_outlined,
          title: 'Medication reminders',
          detail: '${state.medicineDone} of ${state.medicineTotal} taken today.',
          done: state.medicineDone == state.medicineTotal,
        ),
      if (intake.caregiver != null)
        (
          icon: Icons.people_alt_outlined,
          title: 'Caregiver check-in',
          detail: '${intake.caregiver!.caregiverName} has added observations. '
              'Refresh them each month.',
          done: true,
        ),
      (
        icon: Icons.medical_information_outlined,
        title: snapshot.suggestsClinicalDiscussion
            ? 'Discuss the summary with a doctor'
            : 'Keep the summary ready',
        detail: snapshot.suggestsClinicalDiscussion
            ? 'Change was observed in more than one area alongside reported '
                'difficulty with daily activities.'
            : 'Nothing here needs urgent action. Take the summary along at your '
                'next routine appointment.',
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
              eyebrow: 'Monitoring plan',
              title: 'Your care plan',
              subtitle: 'Built from your own record',
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
                        Text('Next review', style: AppText.label),
                        Text(
                          '${nextReview.day} '
                          '${_month(nextReview.month)} ${nextReview.year}',
                          style: AppText.h3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            const NotADiagnosisNote(
              message:
                  'This plan is generated from your answers and your activity '
                  'history. It is a monitoring routine, not a treatment plan — a '
                  'clinician decides what care you need.',
            ),
          ],
        ),
      ),
    );
  }

  static String _month(int m) => const <String>[
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][m - 1];
}
