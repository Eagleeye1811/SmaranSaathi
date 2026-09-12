import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

const DoctorProfile _mockDoctor = DoctorProfile(
  id: 'doc_sharma',
  name: 'Neha Sharma',
  specialization: 'Neurologist',
  hospital: 'Jorhat Medical College — Memory Clinic',
  email: 'neha.sharma@jorhatmc.in',
  phone: '+91 94010 00001',
  avatarInitials: 'NS',
  status: InvitationStatus.connected,
  registrationNumber: 'MCI-2891-AS',
);

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
      'Procedure Reconstruction — increase to daily',
      'Melody of the Valleys — maintain current frequency',
      'NER Memory Cards — 3x per week',
    ],
    followUpLabel: '4 weeks — 18 September 2026',
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
  bool _hasDoctor = true;
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
    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.indigoTint.withValues(alpha: 0.7),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  if (!_hasDoctor) ...<Widget>[
                    _NoDoctorState(
                      onConnect: () =>
                          setState(() => _showAddForm = true),
                      onAddExisting: () =>
                          setState(() => _showAddForm = true),
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
                            setState(() {
                              _hasDoctor = true;
                              _showAddForm = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Invitation sent to Dr. ${_nameCtrl.text.isNotEmpty ? _nameCtrl.text : "Doctor"}')),
                            );
                          },
                        ),
                      ),
                    ],
                  ] else ...<Widget>[
                    // ── Connected doctor card ──────────────────────────
                    FadeInUp(
                      child: _ConnectedDoctorCard(
                        doctor: _mockDoctor,
                        onDisconnect: () =>
                            setState(() => _hasDoctor = false),
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
        ],
      ),
    );
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
