import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../auth/auth_role_screen.dart';
import '../../auth/sign_in_screen.dart';
import '../../intake/welcome_screens.dart';
import '../settings/language_selector.dart';
import '../widgets/patient_widgets.dart';

/// Patient profile and accessibility settings screen.
///
/// Fully consistent with the SmaranSaathi patient module design system:
/// - Warm off-white Scaffold background (AppColors.background)
/// - Clean section headers without duplicate card headers
/// - Consistent MmCard styling with soft shadows and hairline borders
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final Patient p = state.patient;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.035,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.8),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const PatientTopBar(showActions: false),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 36),
                  children: <Widget>[
                    // ── Hero Patient Identity Card ──────────────────────────
                    FadeInUp(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: Corners.r(Corners.lg),
                          border: Border.all(color: AppColors.hairline),
                          boxShadow: AppColors.softShadow(y: 4, blur: 16, opacity: 0.06),
                        ),
                        child: Column(
                          children: <Widget>[
                            // Top Soft Ambient Banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 20, bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint.withValues(alpha: 0.4),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(Corners.lg),
                                  topRight: Radius.circular(Corners.lg),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: <Widget>[
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            width: 3,
                                          ),
                                          boxShadow: AppColors.softShadow(y: 4, blur: 12),
                                        ),
                                        child: SceneImage(
                                          sceneId: p.portraitScene,
                                          size: 100,
                                          circle: true,
                                          borderColor: Colors.white,
                                          borderWidth: 3,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    p.name,
                                    style: AppText.h1.sized(24).wght(800),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  PillTag(
                                    label: 'Stage 2 Cognitive Profile • Active Member',
                                    icon: Icons.verified_rounded,
                                    color: AppColors.primary,
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Profile Fact Chips
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  PillTag(
                                    label: l.reportAgeYears(p.age),
                                    icon: Icons.cake_rounded,
                                    color: AppColors.primary,
                                    dense: true,
                                  ),
                                  if (p.location.isNotEmpty)
                                    PillTag(
                                      label: p.location,
                                      icon: Icons.place_rounded,
                                      color: AppColors.terracotta,
                                      dense: true,
                                    ),
                                  PillTag(
                                    label: p.language,
                                    icon: Icons.translate_rounded,
                                    color: AppColors.secondary,
                                    dense: true,
                                  ),
                                  PillTag(
                                    label: l.profileFamilyCount(p.family.length),
                                    icon: Icons.people_rounded,
                                    color: AppColors.plum,
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: WovenStrip(height: 8, opacity: 0.5),
                            ),
                            const SizedBox(height: 14),

                            // Detailed Facts Grid
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                              child: Row(
                                children: <Widget>[
                                  if (p.occupation.isNotEmpty)
                                    Expanded(
                                      child: _FactTile(
                                        icon: Icons.work_outline_rounded,
                                        label: l.walletHerWork,
                                        value: p.occupation,
                                        color: AppColors.indigo,
                                      ),
                                    ),
                                  if (p.occupation.isNotEmpty && p.favouriteFood.isNotEmpty)
                                    const SizedBox(width: 10),
                                  if (p.favouriteFood.isNotEmpty)
                                    Expanded(
                                      child: _FactTile(
                                        icon: Icons.restaurant_rounded,
                                        label: l.profileSheLoves,
                                        value: p.favouriteFood,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 1: Emergency & SMS Alerts ──────────────────
                    FadeInUp(
                      delayMs: 25,
                      child: SectionHeader(
                        title: l.profileSmsAlertsMobileNumber,
                        icon: Icons.sms_rounded,
                        subtitle: l.profileSmsAlertsSubtitle,
                      ),
                    ),
                    FadeInUp(
                      delayMs: 35,
                      child: _SmsPhoneNumberCard(patient: p),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 2: Language & Voice Guidance ───────────────
                    FadeInUp(
                      delayMs: 45,
                      child: SectionHeader(
                        title: l.settingsLanguage,
                        icon: Icons.translate_rounded,
                      ),
                    ),
                    const FadeInUp(
                      delayMs: 55,
                      child: LanguageSelector(),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 3: Accessibility & Display Settings ───────
                    FadeInUp(
                      delayMs: 65,
                      child: SectionHeader(
                        title: l.settingsEasier,
                        icon: Icons.accessibility_new_rounded,
                        subtitle: l.profileChangesApplyRightAway,
                      ),
                    ),
                    FadeInUp(
                      delayMs: 75,
                      child: MmCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.format_size_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(l.settingsTextSize.toUpperCase(), style: AppText.overline),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (final TextSizePreference t in TextSizePreference.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: _RadioRow(
                                  label: t.localizedLabel(l),
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
                              label: l.settingsVoicePromptsLabel,
                              detail: l.settingsVoicePrompts(p.language),
                              value: state.voicePrompts,
                              onChanged: (bool v) => state.voicePrompts = v,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 4: Cloud Sync & Connectivity ──────────────
                    FadeInUp(
                      delayMs: 85,
                      child: SectionHeader(
                        title: l.settingsConnection,
                        icon: Icons.cloud_rounded,
                        subtitle: l.settingsOfflineNote,
                      ),
                    ),
                    FadeInUp(
                      delayMs: 95,
                      child: MmCard(
                        child: Column(
                          children: <Widget>[
                            _SwitchRow(
                              icon: state.offline
                                  ? Icons.cloud_off_rounded
                                  : Icons.cloud_done_rounded,
                              label: l.settingsOfflineMode,
                              detail: state.offline
                                  ? l.profileActivitiesSavedOnDevice(state.pendingSync)
                                  : l.settingsConnected,
                              value: state.offline,
                              onChanged: (bool v) {
                                state.setOffline(v);
                                if (!v) state.syncNow();
                              },
                            ),
                            if (!state.offline && state.pendingSync > 0) ...<Widget>[
                              const SizedBox(height: 10),
                              BigButton(
                                label: state.syncing
                                    ? l.profileSyncing
                                    : l.profileSyncActivities(state.pendingSync),
                                icon: Icons.cloud_upload_rounded,
                                color: AppColors.secondary,
                                height: 56,
                                onPressed: state.syncing ? null : state.syncNow,
                              ),
                            ],
                            if (!state.offline && state.pendingSync == 0) ...<Widget>[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.successTint,
                                  borderRadius: Corners.r(Corners.md),
                                  border: Border.all(
                                    color: AppColors.success.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.success, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l.settingsAllSynced,
                                        style: AppText.body.wght(700).tint(AppColors.success),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 5: Care Team & Medical Support ────────────
                    FadeInUp(
                      delayMs: 105,
                      child: SectionHeader(
                        title: l.profileCareTeam,
                        icon: Icons.groups_rounded,
                      ),
                    ),
                    FadeInUp(
                      delayMs: 115,
                      child: MmCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (p.family.isNotEmpty) ...<Widget>[
                              ListRow(
                                leading: const SceneImage(
                                  sceneId: 'portrait_priya',
                                  size: 48,
                                  circle: true,
                                ),
                                title: p.family.first.name,
                                subtitle: l.profileCaregiverCallsEvening,
                              ),
                              const Divider(color: AppColors.hairline),
                            ],
                            ListRow(
                              leading: const SoftIcon(
                                icon: Icons.medical_information_rounded,
                                color: AppColors.secondary,
                                size: 48,
                              ),
                              title: MockData.doctorName,
                              subtitle: l.profileMemoryClinicSchedule,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 6: Account & Security ─────────────────────
                    FadeInUp(
                      delayMs: 125,
                      child: SectionHeader(
                        title: l.profileAccount,
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const FadeInUp(
                      delayMs: 135,
                      child: _AccountCard(),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Section 7: Role Switch / Preview Exit ─────────────
                    FadeInUp(
                      delayMs: 145,
                      child: BigButton(
                        label: state.viewingAsPatient
                            ? l.caregiverBackToCaregiver
                            : l.actionSwitchRole,
                        icon: state.viewingAsPatient
                            ? Icons.arrow_back_rounded
                            : Icons.swap_horiz_rounded,
                        color: AppColors.primary,
                        outlined: true,
                        height: 60,
                        onPressed: () {
                          if (state.viewingAsPatient) {
                            Navigator.of(context, rootNavigator: true).pop();
                            return;
                          }
                          AppScope.read(context).setRole(AppRole.none);
                          Nav.rootTo(context, const AuthRoleScreen());
                        },
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

/// Fact Tile Widget for Hero Card
class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: AppText.overline.sized(9).tint(AppColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppText.bodySmall.wght(700).tint(AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Account Card Component
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _logOut(BuildContext context) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: Corners.r(20)),
            title: Text(l.profileLogOutQuestion, style: AppText.h2),
            content: Text(l.profileLogOutBody, style: AppText.body),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l.profileStaySignedIn, style: AppText.body.wght(600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.md)),
                ),
                child: Text(l.profileLogOut, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final AppState state = AppScope.read(context);
    final AuthService? service = AuthScope.maybeOf(context);
    await state.signOutAccount();
    try {
      await service?.signOut();
    } catch (error) {
      debugPrint('PatientProfileScreen: signing out of Firebase failed ($error)');
    }
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final AuthService? service = AuthScope.maybeOf(context);
    final String? email = service?.currentUser?.email;
    final bool signedIn = state.accountId != null || email != null;

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListRow(
            leading: SoftIcon(
              icon: signedIn
                  ? Icons.person_outline_rounded
                  : Icons.person_off_outlined,
              color: signedIn ? AppColors.primary : AppColors.inkMuted,
              size: 48,
            ),
            title: signedIn ? (email ?? l.profileSignedIn) : l.profileNoAccount,
            subtitle: signedIn
                ? l.profileSignedIn
                : l.profileSignInToKeepRecord,
          ),
          const SizedBox(height: Insets.md),
          if (signedIn && !state.viewingAsPatient)
            BigButton(
              label: l.profileLogOut,
              icon: Icons.logout_rounded,
              color: AppColors.danger,
              outlined: true,
              height: 56,
              onPressed: () => _logOut(context),
            )
          else if (service != null && !state.viewingAsPatient)
            BigButton(
              label: l.profileSignIn,
              icon: Icons.login_rounded,
              color: AppColors.primary,
              outlined: true,
              height: 56,
              onPressed: () => Nav.push(
                context,
                SignInScreen(
                  authService: service,
                  onSignedIn: (AuthResult result) async {
                    await state.signInAccount(result.user!.uid);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Radio Selection Row Widget
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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.hairline,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppText.bodyLarge.wght(selected ? 800 : 600))),
            Text(
              'Aa',
              style: AppText.body.sized(15 * sampleScale).wght(700).tint(
                    selected ? AppColors.primary : AppColors.inkMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switch Row Widget
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
            scale: 1.1,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Emergency SMS Phone Number Component (Clean without duplicate header)
class _SmsPhoneNumberCard extends StatefulWidget {
  const _SmsPhoneNumberCard({required this.patient});

  final Patient patient;

  @override
  State<_SmsPhoneNumberCard> createState() => _SmsPhoneNumberCardState();
}

class _SmsPhoneNumberCardState extends State<_SmsPhoneNumberCard> {
  late final TextEditingController _phoneController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.patient.phoneNumber);
  }

  @override
  void didUpdateWidget(_SmsPhoneNumberCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.patient.phoneNumber != oldWidget.patient.phoneNumber && !_isEditing) {
      _phoneController.text = widget.patient.phoneNumber;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _save(AppState state) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String newPhone = _phoneController.text.trim();
    state.updatePatientPhoneNumber(newPhone);
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newPhone.isEmpty
              ? l.profilePhoneNumberRemoved
              : l.profilePhoneNumberUpdated,
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final String currentPhone = widget.patient.phoneNumber;

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_isEditing) ...<Widget>[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.profilePhoneHint,
                labelText: l.profilePhoneLabel,
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    setState(() {
                      _phoneController.text = currentPhone;
                      _isEditing = false;
                    });
                  },
                  child: Text(l.actionCancel, style: AppText.body.tint(AppColors.inkMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _save(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.md)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l.profileSaveNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: currentPhone.isNotEmpty
                    ? AppColors.primaryTint.withValues(alpha: 0.5)
                    : AppColors.hairline.withValues(alpha: 0.3),
                borderRadius: Corners.r(Corners.md),
                border: Border.all(
                  color: currentPhone.isNotEmpty
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    currentPhone.isNotEmpty
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: currentPhone.isNotEmpty ? AppColors.primary : AppColors.inkMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currentPhone.isNotEmpty ? currentPhone : l.profileNoMobileNumberYet,
                        style: AppText.bodyLarge.wght(700).tint(
                              currentPhone.isNotEmpty ? AppColors.primaryDeep : AppColors.inkMuted,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _phoneController.text = currentPhone;
                        _isEditing = true;
                      });
                    },
                    child: Text(
                      currentPhone.isNotEmpty ? l.profileChangeNumber : l.profileAddNumber,
                      style: AppText.body.wght(800).tint(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
