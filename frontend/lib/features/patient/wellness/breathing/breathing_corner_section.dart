import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wellness.dart';
import '../../../../core/widgets/ui_kit.dart';
import 'breathing_exercise_screen.dart';

/// Section component displaying all available breathing techniques in a clean single solid color theme.
class BreathingCornerSection extends StatelessWidget {
  const BreathingCornerSection({super.key});

  @override
  Widget build(BuildContext context) {
    const List<BreathingTechnique> items = WellnessRepositoryData.breathingTechniques;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Select a breathing technique to begin',
          style: AppText.body.tint(AppColors.inkMuted),
        ),
        const SizedBox(height: Insets.md),
        for (final BreathingTechnique item in items) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: MmCard(
              onTap: () => Nav.open(context, BreathingExerciseScreen(technique: item)),
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppText.h3.wght(800).tint(AppColors.primaryDeep),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 24),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    style: AppText.bodySmall.tint(AppColors.inkMuted),
                  ),
                  const SizedBox(height: 16),

                  // Phase timing visualization bars using single primary color
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _PhaseTimingBar(
                        label: '${item.inhaleSeconds}s',
                        subLabel: 'Inhale',
                        isVertical: true,
                        color: AppColors.primary,
                      ),
                      if (item.holdSeconds > 0)
                        _PhaseTimingBar(
                          label: '${item.holdSeconds}s',
                          subLabel: 'Hold',
                          isVertical: false,
                          color: AppColors.primarySoft,
                        ),
                      _PhaseTimingBar(
                        label: '${item.exhaleSeconds}s',
                        subLabel: 'Exhale',
                        isVertical: true,
                        color: AppColors.primary,
                      ),
                      if (item.holdAfterExhaleSeconds > 0)
                        _PhaseTimingBar(
                          label: '${item.holdAfterExhaleSeconds}s',
                          subLabel: 'Rest',
                          isVertical: false,
                          color: AppColors.primarySoft,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhaseTimingBar extends StatelessWidget {
  const _PhaseTimingBar({
    required this.label,
    required this.subLabel,
    required this.isVertical,
    required this.color,
  });

  final String label;
  final String subLabel;
  final bool isVertical;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: isVertical ? 8 : 36,
          height: isVertical ? 36 : 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Corners.r(Corners.sm),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppText.caption.wght(800)),
        Text(subLabel, style: AppText.caption.sized(11).tint(AppColors.inkMuted)),
      ],
    );
  }
}
