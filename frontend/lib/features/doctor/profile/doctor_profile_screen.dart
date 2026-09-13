import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../intake/welcome_screens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/mock_translator.dart';
import '../../patient/settings/language_picker_button.dart';
import '../widgets/clinic_widgets.dart';

/// Clinician account and platform information.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  /// Back to the role picker with the account intact — a clinician looking at
  /// another side of the app, not leaving it.
  static Future<void> _switchRole(BuildContext context) async {
    AppScope.read(context).setRole(AppRole.none);
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  /// Leaves the account properly, local state first.
  ///
  /// Local first because the app must end up signed out even with no network;
  /// a failed Firebase call must not leave a clinician still signed in on the
  /// device in front of them. Nothing is deleted — the account's records stay
  /// under its own uid and come back at the next sign-in.
  ///
  /// This used to be the *same* button as "switch role", which meant a
  /// clinician who only wanted to look at the caregiver side was signed out of
  /// their account to do it.
  static Future<void> _logOutDoctor(BuildContext context) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text(
                'You will need to sign in again to reach your caseload.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(dialogContext).actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Log out'),
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
        debugPrint('DoctorProfileScreen: sign out failed ($error)');
      }
    }
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  /// Fills in the details a family actually chooses on.
  static Future<void> _editListing(
      BuildContext context, AppState state, DoctorProfile mine) async {
    final TextEditingController name = TextEditingController(text: mine.name);
    final TextEditingController spec =
        TextEditingController(text: mine.specialization);
    final TextEditingController clinic = TextEditingController(text: mine.hospital);
    final TextEditingController reg =
        TextEditingController(text: mine.registrationNumber);

    final bool saved = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Your listing'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: Insets.sm),
                  TextField(
                    controller: spec,
                    decoration: const InputDecoration(
                        labelText: 'Specialisation',
                        hintText: 'Neurologist, Geriatrician…',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: Insets.sm),
                  TextField(
                    controller: clinic,
                    decoration: const InputDecoration(
                        labelText: 'Clinic or hospital',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: Insets.sm),
                  TextField(
                    controller: reg,
                    decoration: const InputDecoration(
                        labelText: 'Registration number',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(dialogContext).actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (saved) {
      state.updateMyDoctorProfile(
        name: name.text.trim(),
        specialization: spec.text.trim(),
        hospital: clinic.text.trim(),
        registrationNumber: reg.text.trim(),
      );
    }
    name.dispose();
    spec.dispose();
    clinic.dispose();
    reg.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final DoctorProfile? mine = state.myDoctorProfile;

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ClinicTopBar(
              title: l.doctorTabProfile,
              showBack: true,
              showProfile: false,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
              children: <Widget>[
                FadeInUp(
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: AppColors.clinicAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 32, color: AppColors.clinicAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Their own name once they have an account,
                              // not the demo clinician's. A doctor who signs
                              // up and is shown somebody else's name has no
                              // reason to believe the listing families see is
                              // theirs either.
                              Text(mine?.displayName ?? MockData.doctorName,
                                  style: CT.h2.sized(21),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(
                                mine == null || mine.specialization.isEmpty
                                    ? l.doctorProfileRoleLine
                                    : mine.specialization,
                                style: CT.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              PillTag(
                                label: l.doctorProfilePatientCount(24),
                                color: AppColors.clinicAccent,
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
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorProfilePracticeHeading, style: CT.h3),
                        const SizedBox(height: 12),
                        _Row(
                            label: l.doctorProfileClinicLabel,
                            value: MockTranslator.translateClinicName(MockData.clinicName, l)),
                        _Row(label: l.doctorProfileRegionLabel, value: l.doctorProfileRegionValue),
                        _Row(
                            label: l.doctorProfileLanguagesLabel,
                            value: l.doctorProfileLanguagesValue),
                        _Row(
                            label: l.doctorProfileClinicDaysLabel,
                            value: l.doctorProfileClinicDaysValue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // ── The listing families see ──────────────────────────
                //
                // Signing up puts a clinician in the caregiver's directory
                // straight away, which is the point — but an entry with no
                // specialisation or clinic is one nobody will choose. This is
                // where it gets filled in.
                if (mine != null) ...<Widget>[
                  FadeInUp(
                    delayMs: 110,
                    child: ClinicCard(
                      padding: const EdgeInsets.all(Insets.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text('Your public listing', style: CT.h3.wght(700)),
                              ),
                              TextButton.icon(
                                onPressed: () => _editListing(context, state, mine),
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.sm),
                          _Row(
                            label: 'Specialisation',
                            value: mine.specialization.isEmpty
                                ? 'Not set. Families search by this'
                                : mine.specialization,
                          ),
                          _Row(
                            label: 'Clinic',
                            value: mine.hospital.isEmpty ? 'Not set' : mine.hospital,
                          ),
                          _Row(
                            label: 'Registration',
                            value: mine.registrationNumber.isEmpty
                                ? 'Not set'
                                : mine.registrationNumber,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                ],

                // ── Language ──────────────────────────────────────────
                FadeInUp(
                  delayMs: 120,
                  child: Row(
                    children: <Widget>[
                      Text(l.settingsLanguage, style: CT.h3.wght(700)),
                      const Spacer(),
                      const LanguagePickerButton(color: AppColors.clinicInkSoft),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),

                // Shows the signed-in email, and only when an auth service is
                // configured — so the two actions below it are separate and
                // unconditional, and there is always a way out of the account.
                const _DoctorAccountSection(),

                FadeInUp(
                  delayMs: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _switchRole(context),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(l.doctorProfileSwitchRole),
                      ),
                      const SizedBox(height: Insets.sm),
                      OutlinedButton.icon(
                        onPressed: () => _logOutDoctor(context),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Log out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                      ),
                    ],
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

/// Clinic-themed equivalent of `core/widgets/account_section.dart`'s
/// `AccountSection` — same real sign-out/`fetchMe` round trip, styled with
/// `ClinicCard`/`CT`/`clinicAccent` instead of the warm patient/caregiver
/// palette, since a doctor's surface deliberately never looks like theirs.
/// Renders nothing when there's no `AuthGate` above it (every existing test,
/// any build without Firebase configured).
class _DoctorAccountSection extends StatefulWidget {
  const _DoctorAccountSection();

  @override
  State<_DoctorAccountSection> createState() => _DoctorAccountSectionState();
}

class _DoctorAccountSectionState extends State<_DoctorAccountSection> {
  Future<Map<String, dynamic>?>? _me;
  AuthService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthService? service = AuthScope.maybeOf(context);
    if (service != _service) {
      _service = service;
      _me = service?.fetchMe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService? service = _service;
    final String email = service?.currentUser?.email ?? 'Doctor Account';
    if (service == null) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: FadeInUp(
        delayMs: 130,
        child: ClinicCard(
          padding: const EdgeInsets.all(Insets.lg),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _me,
            builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
              final Map<String, dynamic>? me = snapshot.data;
              final String displayEmail = (me?['email'] as String?) ?? email;
              final String role = (me?['role'] as String?) ?? 'Doctor';
              return Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.clinicAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.badge_outlined, color: AppColors.clinicAccent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorProfileSignedInAs, style: CT.caption),
                        Text(displayEmail, style: CT.body.wght(700)),
                        Text(l.doctorProfileRoleValue(role), style: CT.caption),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => DoctorProfileScreen._logOutDoctor(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(l.doctorProfileLogOut),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 130, child: Text(label, style: CT.caption)),
          Expanded(child: Text(value, style: CT.bodySmall.tint(AppColors.clinicInk))),
        ],
      ),
    );
  }
}

