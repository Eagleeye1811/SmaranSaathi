import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../patient/patient_shell.dart';
import '../onboarding/patient_onboarding_flow.dart';
import '../widgets/caregiver_top_bar.dart';

/// Caregiver account, patient-side accessibility controls and the demo
/// switches judges will want to press.
class CaregiverProfileScreen extends StatelessWidget {
  const CaregiverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.75),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const CaregiverTopBar(title: 'Profile'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  FadeInUp(
                    child: MmCard(
                      shadow: AppColors.liftShadow(),
                      child: Row(
                        children: <Widget>[
                          const SceneImage(
                            sceneId: 'portrait_priya',
                            size: 74,
                            circle: true,
                            borderColor: Colors.white,
                            borderWidth: 3,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(MockData.caregiverName, style: AppText.h2.sized(22)),
                                const SizedBox(height: 3),
                                Text('Daughter · primary caregiver',
                                    style: AppText.bodySmall),
                                const SizedBox(height: 8),
                                const PillTag(
                                  label: 'Caring for Aama Devi',
                                  color: AppColors.primary,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 50,
                    child: SectionHeader(
                      title: 'Patient experience',
                      icon: Icons.accessibility_new_rounded,
                      subtitle: 'Set these on her behalf',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 70,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('TEXT SIZE IN PATIENT MODE', style: AppText.overline),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              for (final TextSizePreference t in TextSizePreference.values)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        right: t == TextSizePreference.extraLarge ? 0 : 8),
                                    child: Pressable(
                                      onTap: () => state.textSize = t,
                                      child: AnimatedContainer(
                                        duration: Motion.quick,
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        decoration: BoxDecoration(
                                          color: state.textSize == t
                                              ? AppColors.primary
                                              : Colors.white,
                                          borderRadius: Corners.r(Corners.md),
                                          border: Border.all(
                                            color: state.textSize == t
                                                ? AppColors.primary
                                                : AppColors.hairline,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: <Widget>[
                                            Text('Aa',
                                                style: AppText.body
                                                    .sized(13 * t.scale)
                                                    .wght(800)
                                                    .tint(state.textSize == t
                                                        ? Colors.white
                                                        : AppColors.inkSoft)),
                                            const SizedBox(height: 3),
                                            Text(t.label,
                                                textAlign: TextAlign.center,
                                                style: AppText.caption.sized(11).tint(
                                                      state.textSize == t
                                                          ? Colors.white
                                                          : AppColors.inkMuted,
                                                    )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          _Toggle(
                            icon: Icons.contrast_rounded,
                            label: 'High contrast',
                            value: state.highContrast,
                            onChanged: (bool v) => state.highContrast = v,
                          ),
                          _Toggle(
                            icon: Icons.animation_rounded,
                            label: 'Reduce motion',
                            value: state.reduceMotion,
                            onChanged: (bool v) => state.reduceMotion = v,
                          ),
                          _Toggle(
                            icon: Icons.record_voice_over_rounded,
                            label: 'Voice prompts in ${state.patient.language}',
                            value: state.voicePrompts,
                            onChanged: (bool v) => state.voicePrompts = v,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 100,
                    child: SectionHeader(
                      title: 'Offline-first',
                      icon: Icons.cloud_off_rounded,
                      subtitle: 'Built for patchy connectivity across the region',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 120,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _Toggle(
                            icon: state.offline
                                ? Icons.cloud_off_rounded
                                : Icons.cloud_done_rounded,
                            label: 'Simulate offline mode',
                            value: state.offline,
                            onChanged: (bool v) {
                              state.setOffline(v);
                              if (!v) state.syncNow();
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(Insets.md),
                            decoration: BoxDecoration(
                              color: state.offline
                                  ? AppColors.warningTint
                                  : AppColors.successTint,
                              borderRadius: Corners.r(Corners.md),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  state.offline
                                      ? Icons.download_done_rounded
                                      : Icons.check_circle_rounded,
                                  color: state.offline
                                      ? AppColors.warning
                                      : AppColors.success,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    state.offline
                                        ? 'All games and content are on the device. '
                                            '${state.pendingSync} activities are waiting to sync.'
                                        : state.pendingSync > 0
                                            ? '${state.pendingSync} activities ready to sync.'
                                            : 'All activities synced.',
                                    style: AppText.bodySmall.tint(AppColors.ink),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!state.offline && state.pendingSync > 0) ...<Widget>[
                            const SizedBox(height: 12),
                            SoftButton(
                              label: state.syncing ? 'Syncing…' : 'Sync now',
                              icon: Icons.cloud_upload_rounded,
                              filled: true,
                              color: AppColors.secondary,
                              onPressed: state.syncing ? null : state.syncNow,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 150,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          ListRow(
                            leading: const SoftIcon(
                              icon: Icons.person_add_alt_1_rounded,
                              color: AppColors.plum,
                              size: 46,
                            ),
                            title: 'Set up a patient profile',
                            subtitle: 'Run the six-step onboarding again',
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                            onTap: () => Nav.open(context, const PatientOnboardingFlow()),
                          ),
                          const Divider(color: AppColors.hairline),
                          ListRow(
                            leading: const SoftIcon(
                              icon: Icons.elderly_woman_rounded,
                              color: AppColors.terracotta,
                              size: 46,
                            ),
                            title: 'Open her experience',
                            subtitle: 'See exactly what Aama sees',
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                            onTap: () {
                              state.setRole(AppRole.patient);
                              Nav.push(context, const PatientShell());
                            },
                          ),
                          const Divider(color: AppColors.hairline),
                          const ListRow(
                            leading: SoftIcon(
                              icon: Icons.medical_information_rounded,
                              color: AppColors.secondary,
                              size: 46,
                            ),
                            title: 'Dr. Neha Sharma',
                            subtitle: 'Memory clinic · next visit Thursday, 11:00 AM',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 180,
                    child: BigButton(
                      label: 'Switch to another role',
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.inkSoft,
                      outlined: true,
                      height: 58,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const Center(child: BrandLockup(size: 34, center: true)),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Prototype for SIH 2026 · PS 26003\nDemo data only. Not a diagnostic tool.',
                      textAlign: TextAlign.center,
                      style: AppText.caption,
                    ),
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

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: value ? AppColors.primary : AppColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.body.wght(600))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
