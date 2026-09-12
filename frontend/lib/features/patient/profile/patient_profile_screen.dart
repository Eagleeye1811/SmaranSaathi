import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/auth_role_screen.dart';
import '../../auth/sign_in_screen.dart';
import '../../intake/welcome_screens.dart';
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
            const PatientTopBar(showActions: false),
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
                          Text(p.name, style: AppText.h1.sized(27)),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              PillTag(
                                  label: l.reportAgeYears(p.age),
                                  color: AppColors.primary,
                                  dense: true),
                              if (p.location.isNotEmpty)
                                PillTag(
                                    label: p.location,
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
                              if (p.occupation.isNotEmpty)
                                _Fact(label: l.walletHerWork, value: p.occupation),
                              if (p.favouriteFood.isNotEmpty)
                                _Fact(label: l.profileSheLoves, value: p.favouriteFood),
                              _Fact(
                                  label: l.profileFamily,
                                  value: l.profileFamilyCount(p.family.length)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── SMS Alert Phone Number ───────────────────────────
                  FadeInUp(
                    delayMs: 30,
                    child: _SmsPhoneNumberCard(patient: p),
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
                      subtitle: l.profileChangesApplyRightAway,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 80,
                    child: MmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l.settingsTextSize.toUpperCase(), style: AppText.overline),
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
                                ? l.profileActivitiesSavedOnDevice(state.pendingSync)
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
                                  ? l.profileSyncing
                                  : l.profileSyncActivities(state.pendingSync),
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
                                // Wrapped because this line is translated and
                                // rendered at the patient's own text size:
                                // "All activities synced" fits in English at
                                // 100%, and overflows in Marathi at 130%.
                                Expanded(
                                  child: Text(l.settingsAllSynced,
                                      style: AppText.body.wght(600).tint(AppColors.success)),
                                ),
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
                          Text(l.profileCareTeam, style: AppText.h3),
                          const SizedBox(height: 12),
                          if (p.family.isNotEmpty) ...<Widget>[
                            ListRow(
                              leading: const SceneImage(
                                  sceneId: 'portrait_priya', size: 48, circle: true),
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

                  // ── Account ───────────────────────────────────────────
                  const FadeInUp(delayMs: 175, child: _AccountCard()),
                  const SizedBox(height: Insets.lg),

                  FadeInUp(
                    delayMs: 190,
                    child: BigButton(
                      // A caregiver previewing this screen is not the patient
                      // and must not be able to change the patient's role from
                      // inside it — the only thing that button can honestly do
                      // for them is go back to their own app.
                      label: state.viewingAsPatient
                          ? l.caregiverBackToCaregiver
                          : l.actionSwitchRole,
                      icon: state.viewingAsPatient
                          ? Icons.arrow_back_rounded
                          : Icons.swap_horiz_rounded,
                      color: AppColors.inkSoft,
                      outlined: true,
                      height: 62,
                      // Was `maybePop`, which did nothing whenever the
                      // patient app was the root route — which it is for
                      // anyone who signed in, since `sessionHome` arrives
                      // here through `Nav.rootTo`. Clearing the role and
                      // going to the picker works from either entry.
                      onPressed: () {
                        if (state.viewingAsPatient) {
                          Navigator.of(context).maybePop();
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
    );
  }
}


/// Who is signed in, and the way out.
///
/// Logging out is deliberately two taps: on a shared phone it is the one
/// action here that hides a person's own answers from them, and a stray tap
/// on a large-target patient screen should not be able to do that. Signing
/// out never deletes anything — the record stays on the device under the
/// account and comes back at the next sign-in.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _logOut(BuildContext context) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l.profileLogOutQuestion),
            content: Text(l.profileLogOutBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l.profileStaySignedIn),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(l.profileLogOut),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final AppState state = AppScope.read(context);
    final AuthService? service = AuthScope.maybeOf(context);
    // Local first: the app must end up signed out even if Firebase is
    // unreachable, which on a rural connection it often is.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.profileAccount,
          icon: Icons.badge_outlined,
          subtitle: signedIn
              ? l.profileAnswersFiledUnderAccount
              : l.profileNotSignedIn,
        ),
        MmCard(
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
              // Hidden entirely during a caregiver's preview. The account
              // signed in here is the *caregiver's*, so this button would sign
              // them out of their own app from inside somebody else's screen.
              if (signedIn && !state.viewingAsPatient)
                BigButton(
                  label: l.profileLogOut,
                  icon: Icons.logout_rounded,
                  color: AppColors.danger,
                  outlined: true,
                  height: 62,
                  onPressed: () => _logOut(context),
                )
              else if (service != null && !state.viewingAsPatient)
                BigButton(
                  label: l.profileSignIn,
                  icon: Icons.login_rounded,
                  color: AppColors.primary,
                  outlined: true,
                  height: 62,
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
        ),
      ],
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
              activeColor: Colors.white,
              activeTrackColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

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
      shadow: AppColors.liftShadow(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.profileSmsAlertsMobileNumber,
                      style: AppText.bodyLarge.wght(800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.profileSmsAlertsSubtitle,
                      style: AppText.caption.sized(12).tint(AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (!_isEditing)
                IconButton(
                  icon: Icon(
                    currentPhone.isEmpty ? Icons.add_call : Icons.edit_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _phoneController.text = currentPhone;
                      _isEditing = true;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
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
                  label: Text(l.profileSaveNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    currentPhone.isNotEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded,
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
                        style: AppText.bodyLarge
                            .wght(700)
                            .tint(currentPhone.isNotEmpty ? AppColors.primaryDeep : AppColors.inkMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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


