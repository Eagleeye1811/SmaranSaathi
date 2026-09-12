import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/onboarding.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'assessment_l10n.dart';
import 'intake_kit.dart';
import 'onboarding_l10n.dart';

/// The screen that closes the onboarding.
///
/// It reads the answers back rather than thanking the person and vanishing.
/// Two reasons, and both are about trust: someone who has just spent fifteen
/// minutes answering questions about a person they love should be shown that
/// it was heard, and a caregiver who misread a question finds out here rather
/// than three weeks later in a report.
///
/// The order is deliberate — difficulties, then what the app will do, then
/// what has *not* changed about the person. Ending on the strengths is the
/// point of Part B, so it is the last thing on the screen before the button.
class OnboardingSummaryScreen extends StatelessWidget {
  const OnboardingSummaryScreen({super.key, required this.onFinish, this.onBack});

  final VoidCallback onFinish;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.read(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final OnboardingRecord o = state.intake.onboarding;

    final List<DailyDifficulty> reported = <DailyDifficulty>[
      for (final DailyDifficulty d in DailyDifficulty.values)
        if (d.isDifficulty && o.difficulties.contains(d)) d,
    ];

    return IntakeScaffold(
      stepIndex: IntakeRecord.order.length,
      stepCount: IntakeRecord.order.length,
      onBack: onBack,
      title: l.onbSummaryTitle,
      subtitle: l.onbSummarySubtitle,
      accent: AppColors.secondary,
      continueLabel: l.onbSummaryFinish,
      onContinue: () {
        state.completeIntakeQuestionnaire();
        onFinish();
      },
      children: <Widget>[
        if (o.helper != null && o.helper!.isSomeoneElse)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: PillTag(
              label: l.onbSummaryAnsweredBy(helperRoleLabel(l, o.helper!).toLowerCase()),
              color: AppColors.inkSoft,
              icon: Icons.person_outline_rounded,
            ),
          ),

        // ── what was reported ──────────────────────────────────────────
        _SummaryCard(
          icon: Icons.visibility_outlined,
          title: l.onbSummaryHeardTitle,
          accent: AppColors.primary,
          lines: <String>[
            if (reported.isEmpty)
              l.onbSummaryNoDifficulty
            else
              reported.map((DailyDifficulty d) => dailyDifficultyLabel(l, d)).join(' · '),
            if (o.onset != null)
              '${l.onbOnsetQuestion}  ${onsetWindowLabel(l, o.onset!)}',
            if (o.course != null)
              '${l.onbCourseQuestion}  ${progressionPatternLabel(l, o.course!)}',
          ],
        ),

        // ── the three we will act on ───────────────────────────────────
        if (o.topDifficulties.isNotEmpty)
          _SummaryCard(
            icon: Icons.flag_outlined,
            title: l.onbSummaryFocusTitle,
            accent: AppColors.plum,
            numbered: true,
            lines: <String>[
              for (final DailyDifficulty d in o.topDifficulties)
                dailyDifficultyLabel(l, d),
            ],
          ),

        if (o.goals.isNotEmpty)
          _SummaryCard(
            icon: Icons.favorite_border_rounded,
            title: l.onbSummaryHelpWith,
            accent: AppColors.accent,
            numbered: true,
            lines: <String>[
              for (final SupportGoal g in o.goals) supportGoalLabel(l, g),
            ],
          ),

        // ── and what has not changed ───────────────────────────────────
        _SummaryCard(
          icon: Icons.spa_outlined,
          title: l.onbSummaryStrengthsTitle,
          accent: AppColors.secondary,
          lines: <String>[
            if (o.enjoys.isEmpty && o.stillDoesWell.trim().isEmpty)
              l.onbSummaryNoStrengths
            else ...<String>[
              if (o.enjoys.isNotEmpty)
                o.enjoys
                    .map((EnjoyedActivity e) => enjoyedActivityLabel(l, e))
                    .join(' · '),
              if (o.stillDoesWell.trim().isNotEmpty) o.stillDoesWell.trim(),
            ],
          ],
        ),

        const SizedBox(height: Insets.sm),
        MmCard(
          color: AppColors.primaryTint,
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.onbSummaryNextTitle, style: AppText.label),
              const SizedBox(height: Insets.xs),
              Text(l.onbSummaryNextBody,
                  style: AppText.bodySmall.copyWith(color: AppColors.ink, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        NotADiagnosisNote(message: l.onbSummaryAnswersSafe),
        const SizedBox(height: Insets.sm),
        const NotADiagnosisNote(),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.accent,
    this.numbered = false,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Color accent;

  /// Ranked answers keep their numbers here, so the caregiver can see that
  /// the order they chose was the order that was kept.
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: MmCard(
        padding: const EdgeInsets.all(Insets.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(title, style: AppText.overline.copyWith(color: accent)),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            for (int i = 0; i < lines.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (numbered) ...<Widget>[
                      Text('${i + 1}.',
                          style: AppText.body.copyWith(
                              color: accent, fontWeight: FontWeight.w800)),
                      const SizedBox(width: Insets.sm),
                    ],
                    Expanded(
                      child: Text(lines[i], style: AppText.body.copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
