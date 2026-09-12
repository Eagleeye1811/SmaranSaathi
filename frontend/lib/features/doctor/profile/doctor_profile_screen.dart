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
import '../widgets/clinic_widgets.dart';

/// Clinician account and platform information.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  static Future<void> _logOutDoctor(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);

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
                        _Row(label: l.doctorProfileClinicLabel, value: MockData.clinicName),
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
                  child: const ClinicCard(
                    padding: EdgeInsets.all(Insets.lg),
                    child: _DoctorAvailabilitySection(),
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
                              activeThumbColor: Colors.white,
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
                    onPressed: () => _logOutDoctor(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l.doctorProfileSwitchRole),
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

/// Interactive section allowing the doctor to select their active availability days
/// and configure appointment slots for patients/caregivers to book.
class _DoctorAvailabilitySection extends StatefulWidget {
  const _DoctorAvailabilitySection();

  @override
  State<_DoctorAvailabilitySection> createState() => _DoctorAvailabilitySectionState();
}

class _DoctorAvailabilitySectionState extends State<_DoctorAvailabilitySection> {
  static const List<String> _allDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _filterDay = 'All';

  void _showAddSlotDialog(BuildContext context, AppState state) {
    String selectedDay = state.doctorActiveDays.isNotEmpty
        ? state.doctorActiveDays.first
        : 'Monday';
    String startTime = '10:00 AM';
    String endTime = '11:00 AM';

    final List<String> presets = <String>[
      '9:00 AM – 10:00 AM',
      '10:00 AM – 11:00 AM',
      '11:00 AM – 12:00 PM',
      '2:00 PM – 3:00 PM',
      '3:00 PM – 4:00 PM',
      '4:00 PM – 5:00 PM',
    ];
    String selectedPreset = presets.first;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogCtx, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.clinicSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Add Appointment Slot', style: CT.h3.wght(700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Select Day', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDay,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _allDays
                          .map((String d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d, style: CT.bodySmall),
                              ))
                          .toList(),
                      onChanged: (String? val) {
                        if (val != null) setModalState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Quick Preset Time', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPreset,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: presets
                          .map((String p) => DropdownMenuItem<String>(
                                value: p,
                                child: Text(p, style: CT.bodySmall),
                              ))
                          .toList(),
                      onChanged: (String? val) {
                        if (val != null) {
                          setModalState(() {
                            selectedPreset = val;
                            final List<String> parts = val.split(' – ');
                            if (parts.length == 2) {
                              startTime = parts[0];
                              endTime = parts[1];
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Or Custom Time Range', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            initialValue: startTime,
                            style: CT.bodySmall,
                            decoration: InputDecoration(
                              labelText: 'Start',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (String v) => startTime = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: endTime,
                            style: CT.bodySmall,
                            decoration: InputDecoration(
                              labelText: 'End',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (String v) => endTime = v,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: CT.bodySmall),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clinicAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final String timeLabel = '$startTime – $endTime';
                    state.addDoctorSlot(
                      DoctorSlot(
                        id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
                        dayLabel: selectedDay,
                        timeLabel: timeLabel,
                      ),
                    );
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Slot added for $selectedDay ($timeLabel). Available to caregivers.'),
                      ),
                    );
                  },
                  child: const Text('Add Slot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Set<String> activeDays = state.doctorActiveDays;
    final List<DoctorSlot> slots = state.doctorSlots;
    final List<DoctorSlot> filteredSlots = _filterDay == 'All'
        ? slots
        : slots.where((DoctorSlot s) => s.dayLabel.toLowerCase() == _filterDay.toLowerCase()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.event_available_rounded, size: 20, color: AppColors.clinicAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Availability & Appointment Slots', style: CT.h3.wght(700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select your available consultation days and set slots for caregiver bookings.',
          style: CT.caption,
        ),
        const SizedBox(height: 16),
        Text('Available Consultation Days', style: CT.body.wght(700)),
        const SizedBox(height: 2),
        Text('Tap days to toggle your availability on/off', style: CT.caption),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allDays.map((String day) {
            final bool isSelected = activeDays.contains(day);
            return FilterChip(
              label: Text(day.substring(0, 3)),
              selected: isSelected,
              showCheckmark: isSelected,
              selectedColor: AppColors.clinicAccent.withValues(alpha: 0.18),
              checkmarkColor: AppColors.clinicAccent,
              labelStyle: CT.bodySmall.wght(isSelected ? 700 : 500).tint(
                    isSelected ? AppColors.clinicAccent : AppColors.clinicInkSoft,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.clinicAccent : AppColors.clinicHairline,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              onSelected: (_) => state.toggleDoctorDay(day),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.clinicHairline),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Configured Slots (${slots.length})', style: CT.body.wght(700)),
                  Text('Live and bookable by caregivers', style: CT.caption),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clinicAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showAddSlotDialog(context, state),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Day filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <String>['All', ..._allDays].map((String d) {
              final bool isSel = _filterDay == d;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(d == 'All' ? 'All Days' : d.substring(0, 3)),
                  selected: isSel,
                  visualDensity: VisualDensity.compact,
                  labelStyle: CT.caption.wght(isSel ? 700 : 500).tint(
                        isSel ? AppColors.clinicAccent : AppColors.clinicInkSoft,
                      ),
                  selectedColor: AppColors.clinicAccent.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: isSel ? AppColors.clinicAccent : AppColors.clinicHairline,
                    ),
                  ),
                  onSelected: (bool sel) {
                    if (sel) setState(() => _filterDay = d);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        if (filteredSlots.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.clinicBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No consultation slots for ${_filterDay == "All" ? "any day" : _filterDay}. Tap "+ Add Slot" above to set slots.',
              style: CT.caption,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final DoctorSlot slot in filteredSlots) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: slot.isBooked ? AppColors.clinicHairline : AppColors.clinicAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.clinicAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      slot.dayLabel.substring(0, 3).toUpperCase(),
                      style: CT.caption.wght(800).tint(AppColors.clinicAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(slot.timeLabel, style: CT.bodySmall.wght(700)),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            PillTag(
                              label: slot.isBooked
                                  ? 'Booked by ${slot.bookedByPatient}'
                                  : 'Available for Booking',
                              color: slot.isBooked ? const Color(0xFF2F7FB8) : AppColors.success,
                              dense: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete Slot',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.clinicInkSoft),
                    onPressed: () {
                      state.removeDoctorSlot(slot.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed slot: ${slot.dayLabel} ${slot.timeLabel}'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}
