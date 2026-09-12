import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/account_section.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../intake/welcome_screens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../widgets/caregiver_top_bar.dart';
import '../life_profile/life_profile_screen.dart';
import '../patient_view_screen.dart';

/// Caregiver account, patient-side accessibility controls and the demo
/// switches judges will want to press.
class CaregiverProfileScreen extends StatelessWidget {
  const CaregiverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);

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
            CaregiverTopBar(title: l.caregiverNavProfile),
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
                                Text(
                                  state.hasCaregiverProfile
                                      ? state.caregiverName
                                      : l.caregiverProfileNotSetUp,
                                  style: AppText.h2.sized(22),
                                ),
                                const SizedBox(height: 3),
                                Text(l.caregiverRelationLabel,
                                    style: AppText.bodySmall),
                                const SizedBox(height: 8),
                                PillTag(
                                  label: l.caregiverCaringForLabel(state.patient.name),
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
                      title: l.caregiverPatientExperienceTitle,
                      icon: Icons.accessibility_new_rounded,
                      subtitle: l.caregiverPatientExperienceSubtitle,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 70,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l.caregiverTextSizeLabel, style: AppText.overline),
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
                                            Text(t.localizedLabel(l),
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
                            label: l.settingsHighContrast,
                            value: state.highContrast,
                            onChanged: (bool v) => state.highContrast = v,
                          ),
                          _Toggle(
                            icon: Icons.animation_rounded,
                            label: l.settingsReduceMotion,
                            value: state.reduceMotion,
                            onChanged: (bool v) => state.reduceMotion = v,
                          ),
                          _Toggle(
                            icon: Icons.record_voice_over_rounded,
                            label: l.caregiverVoicePromptsToggle(state.patient.language),
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
                      title: l.caregiverOfflineFirstTitle,
                      icon: Icons.cloud_off_rounded,
                      subtitle: l.caregiverOfflineFirstSubtitle,
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
                            label: l.caregiverSimulateOfflineLabel,
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
                                        ? l.caregiverOfflineAllOnDevice(state.pendingSync)
                                        : state.pendingSync > 0
                                            ? l.caregiverActivitiesReadyToSync(state.pendingSync)
                                            : l.caregiverAllActivitiesSynced,
                                    style: AppText.bodySmall.tint(AppColors.ink),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!state.offline && state.pendingSync > 0) ...<Widget>[
                            const SizedBox(height: 12),
                            SoftButton(
                              label: state.syncing ? l.caregiverSyncing : l.caregiverSyncNow,
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
                          // "Add patient" is gone: this app follows one person,
                          // and the way to describe them is the life profile
                          // rather than a second onboarding that created a
                          // second, competing record.
                          ListRow(
                            leading: const SoftIcon(
                              icon: Icons.favorite_border_rounded,
                              color: AppColors.plum,
                              size: 46,
                            ),
                            title: l.lifeTitle,
                            subtitle: l.lifeOpenAction,
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                            onTap: () => Nav.open(context, const LifeProfileScreen()),
                          ),
                          const Divider(color: AppColors.hairline),
                          ListRow(
                            leading: const SoftIcon(
                              icon: Icons.elderly_woman_rounded,
                              color: AppColors.terracotta,
                              size: 46,
                            ),
                            title: l.caregiverOpenHerExperienceTitle,
                            subtitle: l.caregiverOpenHerExperienceSubtitle(state.patient.shortName),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                            // Through the preview screen, never a raw
                            // setRole + push: that left the caregiver holding
                            // their own app with the patient's role the moment
                            // they pressed back.
                            onTap: () => Nav.open(context, const PatientViewScreen()),
                          ),
                          const Divider(color: AppColors.hairline),
                          ListRow(
                            leading: const SoftIcon(
                              icon: Icons.medical_information_rounded,
                              color: AppColors.secondary,
                              size: 46,
                            ),
                            // Demo doctor's name — a proper name, not translated content.
                            title: 'Dr. Neha Sharma',
                            subtitle: l.caregiverDoctorAppointmentSubtitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  const AccountSection(),

                  FadeInUp(
                    delayMs: 180,
                    child: BigButton(
                      label: l.caregiverSwitchRoleButton,
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.inkSoft,
                      onPressed: () async {
                        final AppState state = AppScope.read(context);
                        final AuthService? service = AuthScope.maybeOf(context);
                        await state.signOutAccount();
                        state.setRole(AppRole.none);
                        if (service != null) {
                          try { await service.signOut(); } catch (_) {}
                        }
                        if (!context.mounted) return;
                        Nav.rootTo(context, const WelcomeScreen());
                      },
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  const Center(child: BrandLockup(size: 34, center: true)),
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
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
