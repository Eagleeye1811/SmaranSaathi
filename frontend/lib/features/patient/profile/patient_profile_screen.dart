import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../settings/language_selector.dart';
import '../widgets/patient_widgets.dart';

/// Patient profile and accessibility settings.
///
/// Every control here is oversized and self-explanatory, and every change is
/// applied live so a caregiver can tune the app while sitting beside the
/// patient.
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final Patient p = state.patient;

    return MotifBackground(
      opacity: 0.045,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.85),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const PatientTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  // ── Identity card ─────────────────────────────────────
                  FadeInUp(
                    child: MmCard(
                      shadow: AppColors.liftShadow(),
                      child: Column(
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: AppColors.softShadow(y: 6, blur: 18),
                            ),
                            child: SceneImage(
                              sceneId: p.portraitScene,
                              size: 120,
                              circle: true,
                              borderColor: Colors.white,
                              borderWidth: 4,
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          Text(p.name.isEmpty ? 'Aama Devi' : p.name,
                              style: AppText.h1.sized(27)),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              PillTag(label: '${p.age} years', color: AppColors.primary, dense: true),
                              PillTag(
                                  label: p.location.isEmpty ? 'Assam' : p.location,
                                  icon: Icons.place_rounded,
                                  color: AppColors.terracotta,
                                  dense: true),
                              PillTag(
                                  label: p.language,
                                  icon: Icons.translate_rounded,
                                  color: AppColors.secondary,
                                  dense: true),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          const WovenStrip(height: 10, opacity: 0.6),
                          const SizedBox(height: Insets.md),
                          Wrap(
                            alignment: WrapAlignment.spaceAround,
                            spacing: 10,
                            runSpacing: 14,
                            children: <Widget>[
                              _Fact(label: 'Her work', value: p.occupation.isEmpty ? 'Weaver' : p.occupation),
                              _Fact(
                                  label: 'She loves',
                                  value: p.favouriteFood.isEmpty ? 'Pitha' : p.favouriteFood),
                              _Fact(label: 'Family', value: '${p.family.length} people'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Language ──────────────────────────────────────────
                  // Above accessibility on purpose: language is the most
                  // fundamental of these settings — the others only help
                  // someone who can already read the screen.
                  const FadeInUp(
                    delayMs: 50,
                    child: LanguageSelector(),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Accessibility ─────────────────────────────────────
                  FadeInUp(
                    delayMs: 60,
                    child: SectionHeader(
                      title: l.settingsEasier,
                      icon: Icons.accessibility_new_rounded,
                      subtitle: 'These change how the app looks right away',
                    ),
                  ),
                  FadeInUp(
                    delayMs: 80,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('TEXT SIZE', style: AppText.overline),
                          const SizedBox(height: 12),
                          for (final TextSizePreference t in TextSizePreference.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _RadioRow(
                                label: t.label,
                                selected: state.textSize == t,
                                sampleScale: t.scale,
                                onTap: () => state.textSize = t,
                              ),
                            ),
                          const SizedBox(height: 6),
                          const Divider(color: AppColors.hairline),
                          const SizedBox(height: 6),
                          _SwitchRow(
                            icon: Icons.contrast_rounded,
                            label: l.settingsHighContrast,
                            detail: l.settingsHighContrastNote,
                            value: state.highContrast,
                            onChanged: (bool v) => state.highContrast = v,
                          ),
                          _SwitchRow(
                            icon: Icons.animation_rounded,
                            label: l.settingsReduceMotion,
                            detail: l.settingsReduceMotionNote,
                            value: state.reduceMotion,
                            onChanged: (bool v) => state.reduceMotion = v,
                          ),
                          _SwitchRow(
                            icon: Icons.record_voice_over_rounded,
                            label: 'Voice prompts',
                            detail: 'Mitra reads questions aloud in ${p.language}',
                            value: state.voicePrompts,
                            onChanged: (bool v) => state.voicePrompts = v,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Connectivity ──────────────────────────────────────
                  FadeInUp(
                    delayMs: 110,
                    child: SectionHeader(
                      title: l.settingsConnection,
                      icon: Icons.cloud_rounded,
                      subtitle: l.settingsOfflineNote,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 130,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          _SwitchRow(
                            icon: state.offline
                                ? Icons.cloud_off_rounded
                                : Icons.cloud_done_rounded,
                            label: l.settingsOfflineMode,
                            detail: state.offline
                                ? '${state.pendingSync} activities saved on this device'
                                : l.settingsConnected,
                            value: state.offline,
                            onChanged: (bool v) {
                              state.setOffline(v);
                              if (!v) state.syncNow();
                            },
                          ),
                          if (!state.offline && state.pendingSync > 0) ...<Widget>[
                            const SizedBox(height: 8),
                            BigButton(
                              label: state.syncing
                                  ? 'Syncing…'
                                  : 'Sync ${state.pendingSync} activities',
                              icon: Icons.cloud_upload_rounded,
                              color: AppColors.secondary,
                              height: 58,
                              onPressed: state.syncing ? null : state.syncNow,
                            ),
                          ],
                          if (!state.offline && state.pendingSync == 0) ...<Widget>[
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 20),
                                const SizedBox(width: 10),
                                Text(l.settingsAllSynced,
                                    style: AppText.body.wght(600).tint(AppColors.success)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 160,
                    child: MmCard(
                      color: AppColors.surfaceMuted,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Care team', style: AppText.h3),
                          const SizedBox(height: 12),
                          ListRow(
                            leading: const SceneImage(
                                sceneId: 'portrait_priya', size: 48, circle: true),
                            title: p.family.isEmpty ? 'Priya' : p.family.first.name,
                            subtitle: 'Caregiver · calls every evening',
                          ),
                          const Divider(color: AppColors.hairline),
                          const ListRow(
                            leading: SoftIcon(
                              icon: Icons.medical_information_rounded,
                              color: AppColors.secondary,
                              size: 48,
                            ),
                            title: 'Dr. Neha Sharma',
                            subtitle: 'Memory clinic · Thursdays, 11:00 AM',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 190,
                    child: BigButton(
                      label: l.actionSwitchRole,
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.inkSoft,
                      outlined: true,
                      height: 62,
                      onPressed: () => Navigator.of(context).maybePop(),
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

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: <Widget>[
          Text(label.toUpperCase(), style: AppText.overline.sized(10)),
          const SizedBox(height: 5),
          Text(value,
              textAlign: TextAlign.center,
              style: AppText.body.wght(700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.sampleScale,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double sampleScale;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : Colors.white,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1.3,
          ),
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: Motion.quick,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.hairline,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppText.bodyLarge.wght(selected ? 800 : 600))),
            Text('Aa',
                style: AppText.body.sized(15 * sampleScale).wght(700).tint(
                      selected ? AppColors.primary : AppColors.inkMuted,
                    )),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          SoftIcon(
            icon: icon,
            color: value ? AppColors.primary : AppColors.inkMuted,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppText.bodyLarge.wght(700)),
                const SizedBox(height: 2),
                Text(detail, style: AppText.bodySmall),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.15,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
