import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/mock_translator.dart';
import '../widgets/clinic_widgets.dart';

/// Clinician account and platform information.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          ClinicTopBar(title: l.doctorTabProfile),
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
                              Text(MockData.doctorName, style: CT.h2.sized(21)),
                              const SizedBox(height: 3),
                              Text(l.doctorProfileRoleLine, style: CT.caption),
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

                FadeInUp(
                  delayMs: 80,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorProfileFiguresHeading, style: CT.h3),
                        const SizedBox(height: 10),
                        for (final String s in <String>[
                          l.doctorProfileFiguresBulletActivity,
                          l.doctorProfileFiguresBulletDomains,
                          l.doctorProfileFiguresBulletAdaptive,
                          l.doctorProfileFiguresBulletOffline,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.circle,
                                    size: 6, color: AppColors.clinicInkSoft),
                                const SizedBox(width: 10),
                                Expanded(child: Text(s, style: CT.bodySmall)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                FadeInUp(
                  delayMs: 110,
                  child: ClinicCard(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              state.offline
                                  ? Icons.cloud_off_rounded
                                  : Icons.cloud_done_rounded,
                              color: state.offline ? AppColors.warning : AppColors.success,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    state.offline ? l.settingsOfflineMode : l.doctorProfileConnected,
                                    style: CT.body.wght(700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    state.offline
                                        ? l.doctorProfileRecordsWaitingSync(state.pendingSync)
                                        : l.doctorProfileRecordsUpToDate,
                                    style: CT.caption,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: state.offline,
                              onChanged: (bool v) {
                                state.setOffline(v);
                                if (!v) state.syncNow();
                              },
                              activeColor: Colors.white,
                              activeTrackColor: AppColors.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),

                const _DoctorAccountSection(),

                FadeInUp(
                  delayMs: 140,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(l.doctorProfileSwitchRole),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              final String email = (me?['email'] as String?) ?? service.currentUser?.email ?? '—';
              final String? role = me?['role'] as String?;
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
                        Text(email, style: CT.body.wght(700)),
                        if (role != null) Text(l.doctorProfileRoleValue(role), style: CT.caption),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => service.signOut(),
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
