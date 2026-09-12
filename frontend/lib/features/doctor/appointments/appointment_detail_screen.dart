import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../l10n/app_localizations.dart';
import '../careplan/care_plan_screen.dart';
import '../consultation/ai_preconsult_screen.dart';
import '../reports/medical_reports_screen.dart';
import '../widgets/clinic_widgets.dart';

/// Full detail view for a specific appointment.
/// Includes AI pre-consult brief, video consultation launcher, doctor notes editor,
/// and quick links to patient care plan and medical reports.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.autoLaunchVideo = false,
  });

  final DoctorAppointment appointment;
  final bool autoLaunchVideo;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late final TextEditingController _notesController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.appointment.doctorNotes);
    if (widget.autoLaunchVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _launchVideoConsultation();
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _launchVideoConsultation() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B2430),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return _VideoConsultationModal(
          patientName: widget.appointment.patientName,
          onSaveNotes: (String notes) {
            setState(() {
              _notesController.text = notes;
              _saved = true;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DoctorAppointment appt = widget.appointment;

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      appBar: AppBar(
        title: Text(l.doctorApptDetailTitle, style: CT.h3.wght(700)),
        backgroundColor: AppColors.clinicSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.clinicInk),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Patient Info Card ───────────────────────────
            ClinicCard(
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.15),
                    child: Text(
                      appt.patientName.isNotEmpty ? appt.patientName[0] : 'P',
                      style: CT.h2.wght(800).tint(AppColors.clinicAccent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(appt.patientName, style: CT.h3.wght(700)),
                        const SizedBox(height: 2),
                        Text(
                          '${appt.patientAge} years · Patient ID: ${appt.patientId}',
                          style: CT.caption,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.clinicInkSoft),
                            const SizedBox(width: 4),
                            Text('${appt.dateLabel}, ${appt.timeLabel}', style: CT.caption.wght(600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Video Consult Action ────────────────────────
            if (appt.isVirtual) ...<Widget>[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clinicAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: Text(l.doctorApptDetailJoinVideo, style: CT.body.wght(700).tint(Colors.white)),
                onPressed: _launchVideoConsultation,
              ),
              const SizedBox(height: 14),
            ],

            // ── AI Pre-Consult Brief Card ───────────────────
            ClinicCard(
              accentEdge: AppColors.clinicAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.clinicAccent.withValues(alpha: 0.12),
                          borderRadius: Corners.r(8),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.clinicAccent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(l.doctorApptDetailAI, style: CT.body.wght(700)),
                            Text(
                              'Activity steady · Sleep disrupted · Adherence 95%',
                              style: CT.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI pre-consultation summary highlights 7-day cognitive performance, reported mood trends, and caregiver notes.',
                    style: CT.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.clinicAccent,
                        side: const BorderSide(color: AppColors.clinicAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: Text(l.doctorApptDetailAIView, style: CT.caption.wght(700).tint(AppColors.clinicAccent)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AIPreconsultScreen(
                              patientName: appt.patientName,
                              patientAge: appt.patientAge,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Quick Links (Care Plan & Reports) ───────────
            Row(
              children: <Widget>[
                Expanded(
                  child: ClinicCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CarePlanScreen(
                            patientName: appt.patientName,
                            patientId: appt.patientId,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.assignment_outlined, size: 20, color: AppColors.clinicAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.doctorApptDetailCareplanTitle, style: CT.bodySmall.wght(700)),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.clinicInkSoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClinicCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MedicalReportsScreen(
                            patientName: appt.patientName,
                            patientId: appt.patientId,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.folder_shared_outlined, size: 20, color: Color(0xFF2F7FB8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.doctorDetailMedicalReports, style: CT.bodySmall.wght(700)),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.clinicInkSoft),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Doctor Notes Section ────────────────────────
            Text(l.doctorApptDetailNotesTitle, style: CT.h3.wght(700)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.clinicSurface,
                borderRadius: Corners.r(10),
                border: Border.all(color: AppColors.clinicHairline),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _notesController,
                    maxLines: 5,
                    style: CT.body,
                    decoration: InputDecoration(
                      hintText: l.doctorApptDetailNotesHint,
                      hintStyle: CT.bodySmall,
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      if (_saved)
                        Row(
                          children: <Widget>[
                            const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(l.doctorApptDetailNotesSaved, style: CT.caption.wght(600).tint(AppColors.success)),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.clinicAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _saved = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.doctorApptDetailNotesSaved),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.clinicInk,
                            ),
                          );
                        },
                        child: Text(l.doctorApptDetailSaveNotes, style: CT.caption.wght(700).tint(Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Simulated video consultation session with interactive doctor notes scratchpad.
class _VideoConsultationModal extends StatefulWidget {
  const _VideoConsultationModal({
    required this.patientName,
    required this.onSaveNotes,
  });

  final String patientName;
  final ValueChanged<String> onSaveNotes;

  @override
  State<_VideoConsultationModal> createState() => _VideoConsultationModalState();
}

class _VideoConsultationModalState extends State<_VideoConsultationModal> {
  bool _micMuted = false;
  bool _camOff = false;
  final TextEditingController _liveNotes = TextEditingController();

  @override
  void dispose() {
    _liveNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(Insets.gutter),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(Icons.fiber_manual_record_rounded, size: 14, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                'Live Consultation · ${widget.patientName}',
                style: AppText.body.wght(700).tint(Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Video viewport
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF101720),
                borderRadius: Corners.r(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                children: <Widget>[
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.3),
                          child: Text(
                            widget.patientName.isNotEmpty ? widget.patientName[0] : 'P',
                            style: AppText.h1.wght(700).tint(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(widget.patientName, style: AppText.body.wght(700).tint(Colors.white)),
                        const SizedBox(height: 4),
                        Text('Connected (Encrypted call)', style: AppText.caption.tint(Colors.white70)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('04:18', style: AppText.caption.wght(600).tint(Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Doctor live consultation notes scratchpad
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF242F3D),
                borderRadius: Corners.r(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text('Consultation Notes', style: AppText.caption.wght(700).tint(Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: TextField(
                      controller: _liveNotes,
                      style: AppText.bodySmall.tint(Colors.white),
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        hintText: 'Type consultation observations & diagnosis here…',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _micMuted ? Colors.redAccent : Colors.white12,
                ),
                icon: Icon(_micMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white),
                onPressed: () => setState(() => _micMuted = !_micMuted),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _camOff ? Colors.redAccent : Colors.white12,
                ),
                icon: Icon(_camOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, color: Colors.white),
                onPressed: () => setState(() => _camOff = !_camOff),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.call_end_rounded, color: Colors.white),
                onPressed: () {
                  if (_liveNotes.text.isNotEmpty) {
                    widget.onSaveNotes(_liveNotes.text);
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
