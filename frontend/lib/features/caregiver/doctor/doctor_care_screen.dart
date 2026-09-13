import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

const Appointment _upcoming = Appointment(
  id: 'apt_001',
  doctorId: 'doc_sharma',
  doctorName: 'Neha Sharma',
  specialization: 'Neurologist',
  dateLabel: 'Thursday, 18 September 2026',
  timeLabel: '4:00 PM',
  status: AppointmentStatus.upcoming,
  isVirtual: true,
);

const Appointment _past = Appointment(
  id: 'apt_000',
  doctorId: 'doc_sharma',
  doctorName: 'Neha Sharma',
  specialization: 'Neurologist',
  dateLabel: 'Thursday, 21 August 2026',
  timeLabel: '4:00 PM',
  status: AppointmentStatus.completed,
  isVirtual: true,
  summary: ConsultationSummary(
    appointmentId: 'apt_000',
    dateLabel: '21 August 2026',
    observations: <String>[
      'Stable mood and engagement since last visit.',
      'Sequencing activities show slightly more hints required.',
      'Family connection and memory recall remain strong.',
    ],
    careplan: 'Continue current cognitive activity schedule with focus on '
        'sequencing activities. Maintain 5 sessions/week. Ensure afternoon '
        'rest is not disrupted.',
    recommendedActivities: <String>[
      'Procedure Reconstruction: increase to daily',
      'Melody of the Valleys: maintain current frequency',
      'NER Memory Cards: 3x per week',
    ],
    followUpLabel: '4 weeks, 18 September 2026',
    doctorNotes: 'Patient appeared relaxed and engaged. Caregiver reported '
        'positive mood on most days. Continue monitoring sequencing domain.',
  ),
);

/// Doctor & Care screen — connection, appointments, and consultation summaries.
class DoctorCareScreen extends StatefulWidget {
  const DoctorCareScreen({super.key});

  @override
  State<DoctorCareScreen> createState() => _DoctorCareScreenState();
}

class _DoctorCareScreenState extends State<DoctorCareScreen> {
  /// For demo: toggle between connected and no-doctor views.

  bool _showAddForm = false;

  // Add-doctor form controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _specCtrl = TextEditingController();
  final TextEditingController _hospitalCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _hospitalCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final DoctorProfile? doctor = state.connectedDoctor;
    final List<DoctorAppointment> bookedAppointments = state.doctorAppointments
        .where((DoctorAppointment a) => a.id.startsWith('apt_'))
        .toList();

    return MotifBackground(
      opacity: 0.04,
      showTopWash: false,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  if (doctor == null) ...<Widget>[
                    _NoDoctorState(
                      onConnect: () =>
                          setState(() => _showAddForm = true),
                      onAddExisting: () =>
                          setState(() => _showAddForm = true),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── The directory ─────────────────────────────────
                    //
                    // Before this there was one doctor, hardcoded, and the
                    // only way to "connect" was to type their details in
                    // from memory. A family that has been given a clinic's
                    // name should be able to find the person in it.
                    FadeInUp(
                      delayMs: 30,
                      child: SectionHeader(
                        title: 'Doctors near you',
                        icon: Icons.medical_services_outlined,
                        subtitle: 'Memory clinics and specialists in the region',
                      ),
                    ),
                    for (final DoctorProfile d in state.doctorDirectory)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DirectoryDoctorCard(
                          doctor: d,
                          onInvite: () {
                            state.inviteDoctor(d.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invitation sent to ${d.displayName}')),
                            );
                          },
                        ),
                      ),
                    if (_showAddForm) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      FadeInUp(
                        child: _AddDoctorForm(
                          nameCtrl: _nameCtrl,
                          specCtrl: _specCtrl,
                          hospitalCtrl: _hospitalCtrl,
                          emailCtrl: _emailCtrl,
                          phoneCtrl: _phoneCtrl,
                          onSend: () {
                            final String name = _nameCtrl.text.trim().isEmpty
                                ? 'Doctor'
                                : _nameCtrl.text.trim();
                            state.addDoctor(DoctorProfile(
                              id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              specialization: _specCtrl.text.trim(),
                              hospital: _hospitalCtrl.text.trim(),
                              email: _emailCtrl.text.trim(),
                              phone: _phoneCtrl.text.trim(),
                              avatarInitials: name.isEmpty ? '' : name[0].toUpperCase(),
                              status: InvitationStatus.sent,
                            ));
                            setState(() => _showAddForm = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invitation sent to Dr. $name')),
                            );
                          },
                        ),
                      ),
                    ],
                  ] else ...<Widget>[
                    // ── Connected doctor card ──────────────────────────
                    FadeInUp(
                      child: _ConnectedDoctorCard(
                        doctor: doctor,
                        onDisconnect: () => state.disconnectDoctor(doctor.id),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Book Consultation from Doctor Slots ─────────────
                    FadeInUp(
                      delayMs: 40,
                      child: _BookAppointmentSection(
                        doctor: doctor,
                        slots: state.doctorSlots,
                        activeDays: state.doctorActiveDays,
                        onBookSlot: (DoctorSlot slot, bool isVirtual) {
                          state.bookAppointmentFromSlot(
                            slot: slot,
                            patientName: 'Aama Devi',
                            patientId: 'p_aama',
                            isVirtual: isVirtual,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.primary,
                              content: Text('Appointment booked for ${slot.dayLabel} at ${slot.timeLabel} with ${doctor.displayName}'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Upcoming appointment ───────────────────────────
                    FadeInUp(
                      delayMs: 60,
                      child: SectionHeader(
                        title: 'Upcoming Appointment',
                        icon: Icons.event_available_rounded,
                      ),
                    ),
                    for (final DoctorAppointment appt in bookedAppointments) ...<Widget>[
                      FadeInUp(
                        delayMs: 70,
                        child: _AppointmentCard(
                          appointment: Appointment(
                            id: appt.id,
                            doctorId: 'doc_sharma',
                            doctorName: 'Neha Sharma',
                            specialization: 'Neurologist',
                            dateLabel: appt.dateLabel,
                            timeLabel: appt.timeLabel,
                            status: AppointmentStatus.upcoming,
                            isVirtual: appt.isVirtual,
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                    FadeInUp(
                      delayMs: 80,
                      child: _AppointmentCard(appointment: _upcoming),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Past consultation summary ──────────────────────
                    FadeInUp(
                      delayMs: 110,
                      child: SectionHeader(
                        title: 'Last Consultation',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    if (_past.summary != null)
                      FadeInUp(
                        delayMs: 130,
                        child: _ConsultationSummaryCard(
                            summary: _past.summary!),
                      ),
                    const SizedBox(height: Insets.lg),

                    // ── Doctor care plan insight ───────────────────────
                    FadeInUp(
                      delayMs: 160,
                      child: AiInsightBanner(
                        insight:
                            "Dr. Sharma's current care plan recommends focusing on "
                            "sequencing activities. The recommended frequency is 5 "
                            "sessions per week. Next follow-up is in 6 days.",
                        color: AppColors.indigo,
                        disclaimer:
                            'Based on the doctor\'s notes from the last consultation. Always follow your doctor\'s direct guidance.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No-doctor empty state ─────────────────────────────────────────────────────

class _NoDoctorState extends StatelessWidget {
  const _NoDoctorState({required this.onConnect, required this.onAddExisting});
  final VoidCallback onConnect;
  final VoidCallback onAddExisting;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        FadeInUp(
          child: MmCard(
            child: Column(
              children: <Widget>[
                const SoftIcon(
                    icon: Icons.local_hospital_outlined,
                    color: AppColors.indigo,
                    size: 64),
                const SizedBox(height: 16),
                Text('No doctor connected yet',
                    style: AppText.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Connecting your doctor lets them view progress, '
                  'share a care plan, and coordinate care directly through SmaranSaathi.',
                  style: AppText.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.lg),
                SoftButton(
                  label: 'Add Your Existing Doctor',
                  icon: Icons.person_add_outlined,
                  color: AppColors.indigo,
                  filled: true,
                  onPressed: onAddExisting,
                ),
                const SizedBox(height: 10),
                SoftButton(
                  label: 'Find a Doctor on SmaranSaathi',
                  icon: Icons.search_rounded,
                  color: AppColors.secondary,
                  onPressed: onConnect,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Add doctor form ───────────────────────────────────────────────────────────

class _AddDoctorForm extends StatelessWidget {
  const _AddDoctorForm({
    required this.nameCtrl,
    required this.specCtrl,
    required this.hospitalCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.onSend,
  });
  final TextEditingController nameCtrl;
  final TextEditingController specCtrl;
  final TextEditingController hospitalCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Add Your Doctor', style: AppText.h3),
          const SizedBox(height: 4),
          Text(
            'We will send them an invitation to join your care profile on SmaranSaathi.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          _Field(ctrl: nameCtrl, label: 'Doctor name', hint: 'Dr. Neha Sharma'),
          const SizedBox(height: 12),
          _Field(
              ctrl: specCtrl,
              label: 'Specialization',
              hint: 'Neurologist'),
          const SizedBox(height: 12),
          _Field(
              ctrl: hospitalCtrl,
              label: 'Hospital / Clinic',
              hint: 'Jorhat Medical College'),
          const SizedBox(height: 12),
          _Field(
              ctrl: emailCtrl,
              label: 'Email',
              hint: 'doctor@hospital.com',
              type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _Field(
              ctrl: phoneCtrl,
              label: 'Phone (optional)',
              hint: '+91 98000 00000',
              type: TextInputType.phone),
          const SizedBox(height: Insets.lg),
          SoftButton(
            label: 'Send Invitation',
            icon: Icons.send_rounded,
            color: AppColors.primary,
            filled: true,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.type = TextInputType.text,
  });
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body.tint(AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: Corners.r(Corners.md),
              borderSide:
                  const BorderSide(color: AppColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Corners.r(Corners.md),
              borderSide:
                  const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: Corners.r(Corners.md),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Connected doctor card ─────────────────────────────────────────────────────

/// One doctor in the directory, with whatever action their status allows.
///
/// The status is the whole point of the card: "invitation sent" and "not sent"
/// look identical until you can see which is which, and a caregiver who has
/// already written to a clinic should not be invited to write again.
class _DirectoryDoctorCard extends StatelessWidget {
  const _DirectoryDoctorCard({required this.doctor, required this.onInvite});

  final DoctorProfile doctor;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.indigoTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  doctor.avatarInitials,
                  style: AppText.body.wght(800).tint(AppColors.indigo),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(doctor.displayName,
                        style: AppText.body.wght(800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(doctor.specialization,
                        style: AppText.caption.wght(700).tint(AppColors.indigo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(doctor.hospital,
                        style: AppText.caption, maxLines: 2),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PillTag(
                label: doctor.status.label,
                color: doctor.status.color,
                icon: doctor.status.icon,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          switch (doctor.status) {
            // Nothing sent yet, so the only thing to offer is sending it —
            // and it is the same button, in the same green, as the one on the
            // form for a doctor the family already has.
            InvitationStatus.notSent => SoftButton(
                label: 'Send Invitation',
                icon: Icons.send_rounded,
                color: AppColors.primary,
                filled: true,
                onPressed: onInvite,
              ),
            // Waiting on them, and that is all the caregiver can do.
            //
            // There was a "Connect now" button here. It was a demo shortcut
            // standing in for the doctor's own device — but on the caregiver's
            // screen it meant a family could add a clinician to their record
            // without that clinician ever agreeing, which is the wrong way
            // round for a consent this side does not own. The invitation now
            // goes to the doctor's own app, and they accept it there.
            InvitationStatus.sent || InvitationStatus.pending => Row(
                children: <Widget>[
                  const Icon(Icons.hourglass_bottom_rounded,
                      size: 16, color: AppColors.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Invitation sent. They will appear here once they accept.',
                      style: AppText.caption.tint(AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            InvitationStatus.connected => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

class _ConnectedDoctorCard extends StatelessWidget {
  const _ConnectedDoctorCard(
      {required this.doctor, required this.onDisconnect});
  final DoctorProfile doctor;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              // Avatar circle with initials
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(doctor.avatarInitials,
                      style:
                          AppText.h3.tint(AppColors.indigo)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(doctor.displayName, style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(doctor.specialization,
                        style: AppText.bodySmall),
                    const SizedBox(height: 2),
                    Text(doctor.hospital,
                        style: AppText.caption,
                        maxLines: 2),
                  ],
                ),
              ),
              PillTag(
                label: '✓ Connected',
                color: AppColors.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _InfoChip(
                    icon: Icons.email_outlined, text: doctor.email),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _InfoChip(
                    icon: Icons.phone_outlined, text: doctor.phone),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          // The way out. `onDisconnect` was declared and passed in but never
          // wired to anything, so a caregiver could connect to a doctor and
          // then had no way to change their mind — and no way to reach the
          // directory again, since it only shows when nobody is connected.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _confirmDisconnect(context),
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Disconnect'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  /// Asked first: disconnecting stops the person treating this patient from
  /// seeing anything the app records, which is not a thing to do by mistap.
  Future<void> _confirmDisconnect(BuildContext context) async {
    final bool yes = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Disconnect ${doctor.displayName}?'),
            content: const Text(
                'They will stop seeing this record. You can invite them again '
                'at any time.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep connected'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ) ??
        false;
    if (yes) onDisconnect();
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: AppColors.inkMuted),
        const SizedBox(width: 8),
        Flexible(
            child: Text(text,
                style: AppText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ── Upcoming appointment card ─────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SoftIcon(
                  icon: Icons.event_available_rounded,
                  color: AppColors.secondary,
                  size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Dr. ${appointment.doctorName}',
                        style: AppText.body.wght(700)),
                    const SizedBox(height: 2),
                    Text(appointment.specialization,
                        style: AppText.caption),
                  ],
                ),
              ),
              PillTag(
                label: appointment.isVirtual ? '📹 Virtual' : '🏥 In-person',
                color: AppColors.secondary,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          _DateRow(
              icon: Icons.calendar_month_rounded,
              text: appointment.dateLabel),
          const SizedBox(height: 6),
          _DateRow(
              icon: Icons.access_time_rounded,
              text: appointment.timeLabel),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftButton(
                  label: 'Join Consultation',
                  icon: Icons.video_call_rounded,
                  color: AppColors.primary,
                  filled: true,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftButton(
                  label: 'Reschedule',
                  color: AppColors.secondary,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.body.wght(600))),
      ],
    );
  }
}

// ── Consultation summary card ─────────────────────────────────────────────────

class _ConsultationSummaryCard extends StatelessWidget {
  const _ConsultationSummaryCard({required this.summary});
  final ConsultationSummary summary;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SoftIcon(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.success,
                  size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Consultation Summary',
                        style: AppText.body.wght(700)),
                    Text(summary.dateLabel, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text('Observations', style: AppText.label),
          const SizedBox(height: 8),
          for (final String obs in summary.observations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.circle,
                        size: 6, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(obs, style: AppText.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: Insets.md),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: Insets.md),
          Text("Doctor's Care Plan", style: AppText.label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: Corners.r(Corners.md),
            ),
            child: Text(summary.careplan, style: AppText.bodySmall),
          ),
          const SizedBox(height: Insets.md),
          Text('Recommended Activities', style: AppText.label),
          const SizedBox(height: 8),
          for (final String act in summary.recommendedActivities)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.arrow_right_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                      child:
                          Text(act, style: AppText.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: Insets.md),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              const Icon(Icons.event_repeat_rounded,
                  size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 8),
              Text('Follow-up: ', style: AppText.label),
              Expanded(
                child: Text(summary.followUpLabel,
                    style: AppText.bodySmall.wght(600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Caregiver booking section exposing the doctor's active availability days
/// and available consultation slots.
class _BookAppointmentSection extends StatefulWidget {
  const _BookAppointmentSection({
    required this.doctor,
    required this.slots,
    required this.activeDays,
    required this.onBookSlot,
  });

  final DoctorProfile doctor;
  final List<DoctorSlot> slots;
  final Set<String> activeDays;
  final void Function(DoctorSlot slot, bool isVirtual) onBookSlot;

  @override
  State<_BookAppointmentSection> createState() => _BookAppointmentSectionState();
}

class _BookAppointmentSectionState extends State<_BookAppointmentSection> {
  String? _selectedDay;

  void _openBookingModal(BuildContext context, DoctorSlot slot) {
    bool isVirtual = true;
    String reason = 'Routine Cognitive Review';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext bctx, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                MediaQuery.of(bctx).viewInsets.bottom + Insets.xl,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Confirm Appointment', style: AppText.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Booking with Dr. ${widget.doctor.name} (${widget.doctor.specialization})',
                    style: AppText.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: Corners.r(Corners.md),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      children: <Widget>[
                        const SoftIcon(
                          icon: Icons.event_available_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('${slot.dayLabel} · ${slot.timeLabel}', style: AppText.body.wght(700)),
                              const SizedBox(height: 2),
                              Text('Slot set by Dr. ${widget.doctor.name}', style: AppText.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Consultation Type', style: AppText.label),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.videocam_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Virtual (Video)'),
                            ],
                          ),
                          selected: isVirtual,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          onSelected: (bool sel) {
                            if (sel) setModalState(() => isVirtual = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.local_hospital_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('In-Person'),
                            ],
                          ),
                          selected: !isVirtual,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          onSelected: (bool sel) {
                            if (sel) setModalState(() => isVirtual = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Reason for Consultation', style: AppText.label),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: Corners.r(Corners.md)),
                    ),
                    items: const <String>[
                      'Routine Cognitive Review',
                      'Memory Score Follow-Up',
                      'Care Plan & Medication Consultation',
                      'Observation Discussion',
                    ].map((String r) => DropdownMenuItem<String>(value: r, child: Text(r, style: AppText.bodySmall))).toList(),
                    onChanged: (String? v) {
                      if (v != null) setModalState(() => reason = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  SoftButton(
                    label: 'Confirm Booking',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.primary,
                    filled: true,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.onBookSlot(slot, isVirtual);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DoctorSlot> availableSlots =
        widget.slots.where((DoctorSlot s) => !s.isBooked).toList();

    // Group available slots by day
    final Set<String> daysWithSlots = availableSlots.map((DoctorSlot s) => s.dayLabel).toSet();
    final String currentDay = (_selectedDay != null && daysWithSlots.contains(_selectedDay))
        ? _selectedDay!
        : (daysWithSlots.isNotEmpty ? daysWithSlots.first : '');

    final List<DoctorSlot> daySlots = availableSlots
        .where((DoctorSlot s) => s.dayLabel == currentDay)
        .toList();

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SoftIcon(
                icon: Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Book Consultation', style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(
                      'Select from slots set by Dr. ${widget.doctor.name}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              PillTag(
                label: '${availableSlots.length} Available',
                color: AppColors.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: Insets.sm),
          Text("Doctor's Available Days", style: AppText.label),
          const SizedBox(height: 8),
          if (daysWithSlots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Dr. ${widget.doctor.name} has no open slots at the moment. Please check back later.',
                style: AppText.bodySmall.tint(AppColors.inkMuted),
              ),
            )
          else ...<Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: daysWithSlots.map((String day) {
                  final bool isSel = day == currentDay;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(day),
                      selected: isSel,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: AppText.caption.wght(isSel ? 700 : 500).tint(
                            isSel ? AppColors.primary : AppColors.inkMuted,
                          ),
                      onSelected: (bool sel) {
                        if (sel) setState(() => _selectedDay = day);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: Insets.md),
            Text('Available Slots for $currentDay', style: AppText.label),
            const SizedBox(height: 8),
            for (final DoctorSlot slot in daySlots) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: Corners.r(Corners.md),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(slot.timeLabel, style: AppText.body.wght(600)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.sm)),
                        elevation: 0,
                      ),
                      onPressed: () => _openBookingModal(context, slot),
                      child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
