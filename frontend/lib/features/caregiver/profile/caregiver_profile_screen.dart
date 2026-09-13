import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/onboarding.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../intake/welcome_screens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../patient/settings/language_selector.dart';
import '../life_profile/life_profile_screen.dart';

/// Caregiver account, patient-side accessibility controls and the demo
/// switches judges will want to press.
class CaregiverProfileScreen extends StatelessWidget {
  const CaregiverProfileScreen({super.key, this.onOpenTab});

  /// Index into `CaregiverShell`'s destinations. Memories & Family is not on
  /// the bottom bar — six destinations is already the most a thumb can pick
  /// between — so this page is how it is reached.
  final ValueChanged<int>? onOpenTab;

  /// Back to the role picker, account intact. Nothing is signed out of:
  /// this is a caregiver looking at another side of the app, not leaving.
  Future<void> _switchRole(BuildContext context) async {
    AppScope.read(context).setRole(AppRole.none);
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  /// Leaves the account properly — locally first, then Firebase.
  ///
  /// Local first because the app must end up signed out even with no network,
  /// which on a rural connection is often the case; a failed Firebase call
  /// must not leave someone still signed in on the phone in front of them.
  /// Nothing is deleted: the answers stay on disk under the account's own id
  /// and come back at the next sign-in.
  Future<void> _logOut(BuildContext context) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Log out?'),
            content: Text('Nothing is deleted. This record stays on the phone under your '
                'account and comes back the next time you sign in.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final AppState state = AppScope.read(context);
    final AuthService? service = AuthScope.maybeOf(context);
    await state.signOutAccount();
    state.setRole(AppRole.none);
    if (service != null) {
      try {
        await service.signOut();
      } catch (error) {
        debugPrint('CaregiverProfileScreen: signing out of Firebase failed ($error)');
      }
    }
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);

    return MotifBackground(
      opacity: 0.04,
      showTopWash: false,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  FadeInUp(child: _CaregiverCard(state: state)),
                  const SizedBox(height: Insets.lg),

                  // ── Language ──────────────────────────────────────────
                  //
                  // Changing it rebuilds the app in place, both sides of it:
                  // this was previously reachable only from the patient's own
                  // settings, which a caregiver setting the phone up for
                  // someone else never opens.
                  FadeInUp(
                    delayMs: 30,
                    child: SectionHeader(
                      title: l.settingsLanguage,
                      icon: Icons.translate_rounded,
                    ),
                  ),
                  const FadeInUp(delayMs: 40, child: LanguageSelector()),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 60,
                    child: SectionHeader(
                      title: 'Their record',
                      icon: Icons.folder_shared_outlined,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 70,
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
                              icon: Icons.groups_2_rounded,
                              color: AppColors.terracotta,
                              size: 46,
                            ),
                            title: 'Memories & family',
                            subtitle: 'The people, photographs and routine behind their day',
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                            onTap: () => onOpenTab?.call(2),
                          ),
                          // "Open her experience" lives on the dashboard,
                          // where it is the doorway a caregiver actually uses,
                          // and the doctor row named one hardcoded demo
                          // clinician while a whole Doctors tab holds the real
                          // ones. Neither earned a second home here.
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  FadeInUp(
                    delayMs: 90,
                    child: SectionHeader(
                      title: l.caregiverPatientExperienceTitle,
                      icon: Icons.accessibility_new_rounded,
                      subtitle: l.caregiverPatientExperienceSubtitle,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 100,
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
                    delayMs: 130,
                    child: SectionHeader(
                      title: l.caregiverOfflineFirstTitle,
                      icon: Icons.cloud_off_rounded,
                      subtitle: l.caregiverOfflineFirstSubtitle,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 140,
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

                  // One account section. `AccountSection` used to sit here
                  // too, printing a second "Account" heading, a second copy
                  // of the signed-in email that the card at the top already
                  // shows, and a second log out button — and only when an
                  // auth service happened to be configured. The section below
                  // is unconditional, so there is always exactly one way out.
                  FadeInUp(
                    delayMs: 170,
                    child: SectionHeader(
                      title: 'Account',
                      icon: Icons.logout_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 180,
                    child: MmCard(
                      child: Column(
                        children: <Widget>[
                          // Switching role keeps the account: it is for a
                          // caregiver who wants to look at the doctor or
                          // patient side, not for handing the phone over.
                          ListRow(
                            padding: EdgeInsets.zero,
                            leading: const SoftIcon(
                              icon: Icons.swap_horiz_rounded,
                              color: AppColors.inkSoft,
                              size: 44,
                            ),
                            title: l.caregiverSwitchRoleButton,
                            subtitle: 'Stay signed in and look at another side of the app',
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                            onTap: () => _switchRole(context),
                          ),
                          const Divider(color: AppColors.hairline),
                          const SizedBox(height: 4),
                          BigButton(
                            label: 'Log out',
                            icon: Icons.logout_rounded,
                            color: AppColors.danger,
                            height: 54,
                            onPressed: () => _logOut(context),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You will need to sign in again to reach this record.',
                            textAlign: TextAlign.center,
                            style: AppText.caption.tint(AppColors.inkMuted),
                          ),
                        ],
                      ),
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

/// Who the caregiver is — the page's own subject, rather than a stock
/// portrait next to a name the app happened to know.
///
/// Name and relation both come from the onboarding and are both editable
/// here: a profile page that can only display the answer to a question asked
/// once, months ago, is a page nobody can correct a typo on.
class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.state});

  final AppState state;

  String _relationLabel(AppLocalizations l) {
    final HelperRole? helper = state.caregiverRelation;
    if (helper == null) return l.caregiverRelationLabel;
    return helper.reportLabel;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AuthService? auth = AuthScope.maybeOf(context);
    final String? email = auth?.currentUser?.email;

    return MmCard(
      shadow: AppColors.liftShadow(),
      child: Column(
        children: <Widget>[
          Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(_relationLabel(l), style: AppText.bodySmall),
                    if (email != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: AppText.caption.tint(AppColors.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    PillTag(
                      label: l.caregiverCaringForLabel(state.patient.name),
                      color: AppColors.primary,
                      dense: true,
                    ),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.edit_outlined,
                size: 40,
                color: AppColors.primary,
                tooltip: 'Edit your details',
                onPressed: () => _edit(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final TextEditingController name =
        TextEditingController(text: state.caregiverName);
    HelperRole? helper = state.caregiverRelation;

    final bool saved = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: Text('Your details'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Your name',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    DropdownButtonFormField<HelperRole>(
                      value: helper,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Your relation to them',
                        border: const OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<HelperRole>>[
                        for (final HelperRole r in HelperRole.values)
                          DropdownMenuItem<HelperRole>(
                            value: r,
                            child: Text(r.reportLabel),
                          ),
                      ],
                      onChanged: (HelperRole? r) => setDialogState(() => helper = r),
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(l.actionCancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (saved) {
      // Through the onboarding record, so the clinician report and the AI
      // context pick the change up too — they both read the relation from
      // there rather than from anything this screen owns.
      state.saveOnboarding(state.intake.onboarding.copyWith(
        caregiverName: name.text.trim(),
        helper: helper,
      ));
    }
    name.dispose();
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
