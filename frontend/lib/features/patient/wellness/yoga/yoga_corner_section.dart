import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wellness.dart';
import '../../../../core/widgets/ui_kit.dart';
import 'yoga_detail_screen.dart';

/// Section component displaying all gentle yoga pose cards in single solid color.
class YogaCornerSection extends StatelessWidget {
  const YogaCornerSection({super.key});

  @override
  Widget build(BuildContext context) {
    const List<YogaPose> poses = WellnessRepositoryData.yogaPoses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Gentle Yoga Corner',
          subtitle: 'Simple, low-intensity postures for joint mobility and steady balance.',
          icon: Icons.self_improvement_rounded,
        ),
        const SizedBox(height: Insets.sm),
        for (final YogaPose pose in poses) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: MmCard(
              onTap: () => Nav.open(context, YogaDetailScreen(pose: pose)),
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: <Widget>[
                  SoftIcon(
                    icon: pose.icon,
                    color: AppColors.primary,
                    size: 54,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: <Widget>[
                            Text(
                              pose.name,
                              style: AppText.h3.wght(800),
                            ),
                            PillTag(
                              label: pose.sanskritName,
                              color: AppColors.primary,
                              dense: true,
                            ),
                            if (pose.videoAssetPath != null)
                              PillTag(
                                label: 'Video Guide',
                                color: AppColors.primary,
                                dense: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pose.description,
                          style: AppText.bodySmall.tint(AppColors.inkMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.timer_outlined, size: 16, color: AppColors.inkMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${pose.durationMinutes} minutes gentle stretch',
                                style: AppText.caption.tint(AppColors.inkMuted).wght(600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: AppColors.inkMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
