import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../widgets/patient_widgets.dart';
import 'breathing/breathing_corner_section.dart';
import 'meditation/meditation_corner_section.dart';
import 'yoga/yoga_corner_section.dart';

/// The main Wellness Hub screen matching the single solid color theme of SmaranSaathi.
class WellnessCornerScreen extends StatelessWidget {
  const WellnessCornerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      backgroundColor: state.highContrast ? Colors.white : AppColors.background,
      body: MotifBackground(
        opacity: 0.045,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.8),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const PatientTopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.xs, Insets.gutter, Insets.xxl),
                  children: <Widget>[
                    // Header title & subtitle
                    FadeInUp(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Wellness Hub',
                                  style: AppText.patientTitle.sized(28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Choose from our collection of wellness tools to improve your mental health',
                                  style: AppText.body.tint(AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          const Companion(state: CompanionState.gentle, size: 54),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // 3 Wellness Hub Category Cards (Breathing, Yoga, Meditation)
                    FadeInUp(
                      delayMs: 60,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: SizedBox(
                              height: 155,
                              child: _WellnessCategoryCard(
                                title: 'Breathing',
                                subtitle: 'Controlled rhythms for instant calm',
                                icon: Icons.air_rounded,
                                onTap: () => Nav.open(
                                  context,
                                  const _WellnessSectionDetailScreen(
                                    title: 'Breathing Exercises',
                                    child: BreathingCornerSection(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 155,
                              child: _WellnessCategoryCard(
                                title: 'Yoga',
                                subtitle: 'Low-intensity postures & stretch',
                                icon: Icons.self_improvement_rounded,
                                onTap: () => Nav.open(
                                  context,
                                  const _WellnessSectionDetailScreen(
                                    title: 'Gentle Yoga Corner',
                                    child: YogaCornerSection(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeInUp(
                      delayMs: 110,
                      child: _WellnessWideCategoryCard(
                        title: 'Meditation',
                        subtitle: 'Calm your mind with guided relaxation sessions',
                        icon: Icons.spa_rounded,
                        onTap: () => Nav.open(
                          context,
                          const _WellnessSectionDetailScreen(
                            title: 'Guided Meditation',
                            child: MeditationCornerSection(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // Saathi Companion Recommendation Card
                    FadeInUp(
                      delayMs: 160,
                      child: MmCard(
                        padding: const EdgeInsets.all(Insets.md),
                        border: Border.all(color: AppColors.hairline),
                        child: Row(
                          children: <Widget>[
                            const SoftIcon(
                              icon: Icons.auto_awesome_rounded,
                              color: AppColors.primary,
                              size: 44,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'SAATHI RECOMMENDS TODAY',
                                    style: AppText.overline.tint(AppColors.primaryDeep).wght(800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    state.wellnessRecommendation,
                                    style: AppText.body.wght(700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category Card matching single solid color app theme
class _WellnessCategoryCard extends StatelessWidget {
  const _WellnessCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: Border.all(color: AppColors.hairline),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SoftIcon(
                icon: icon,
                color: AppColors.primary,
                size: 40,
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 16),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: AppText.h3.sized(17).tint(AppColors.ink).wght(800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppText.caption.tint(AppColors.inkMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Wide Category Card for Meditation section
class _WellnessWideCategoryCard extends StatelessWidget {
  const _WellnessWideCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.lg),
      border: Border.all(color: AppColors.hairline),
      child: Row(
        children: <Widget>[
          SoftIcon(
            icon: icon,
            color: AppColors.primary,
            size: 54,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.h3.sized(20).tint(AppColors.ink).wght(800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppText.bodySmall.tint(AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail screen host for each wellness section
class _WellnessSectionDetailScreen extends StatelessWidget {
  const _WellnessSectionDetailScreen({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      backgroundColor: state.highContrast ? Colors.white : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Wellness Hub',
        ),
        title: Text(title, style: AppText.h3.wght(800)),
        centerTitle: true,
      ),
      body: MotifBackground(
        opacity: 0.035,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Insets.gutter),
            children: <Widget>[child],
          ),
        ),
      ),
    );
  }
}
