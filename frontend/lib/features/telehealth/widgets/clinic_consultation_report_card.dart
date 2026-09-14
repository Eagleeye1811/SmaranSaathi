import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/models/telehealth.dart';
import '../../../core/telehealth/consultation_format.dart';
import '../../doctor/widgets/clinic_widgets.dart';

/// Read-only rendering of a consultation's AI Clinical Scribe report, in the
/// clinic (doctor-portal) visual style.
///
/// This mirrors, section-for-section, what the doctor actually reviewed and
/// approved in `PostCallSummaryScreen` right after the call — same order,
/// same fields, same labels — so a doctor looking at a patient's history
/// sees exactly the report that was signed off, not a re-invented summary.
class ClinicConsultationReportCard extends StatelessWidget {
  const ClinicConsultationReportCard({
    super.key,
    required this.session,
    this.doctorName,
  });

  final ConsultationSession session;
  final String? doctorName;

  @override
  Widget build(BuildContext context) {
    final ClinicalSoapNote? soap = session.soapNote;
    final PatientMitraSummary? summary = session.patientSummary;
    final DateTime when = session.endedAt ?? session.startedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Header ──────────────────────────────────────────────────────
        Row(
          children: <Widget>[
            const Icon(Icons.history_edu_rounded, color: AppColors.clinicAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                doctorName != null ? 'Teleconsultation with Dr. $doctorName' : 'Teleconsultation Report',
                style: CT.h3.sized(16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (session.doctorApproved ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                session.doctorApproved ? 'Approved & Signed' : 'Pending Sign-off',
                style: TextStyle(
                  color: session.doctorApproved ? Colors.green : Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.clinicInkSoft),
            const SizedBox(width: 6),
            Text(formatConsultationDate(when), style: CT.caption.sized(11.5)),
            const SizedBox(width: 12),
            Icon(Icons.timer_outlined, size: 13, color: AppColors.clinicInkSoft),
            const SizedBox(width: 6),
            Text(formatConsultationDuration(session.durationSeconds), style: CT.caption.sized(11.5)),
          ],
        ),
        const SizedBox(height: 14),

        if (soap != null) ...<Widget>[
          _SoapBlock(tag: 'S', title: 'Subjective', body: soap.subjective, color: Colors.blueAccent),
          const SizedBox(height: 8),
          _SoapBlock(tag: 'O', title: 'Objective', body: soap.objective, color: Colors.teal),
          const SizedBox(height: 8),
          _SoapBlock(tag: 'A', title: 'Assessment', body: soap.assessment, color: Colors.purpleAccent),
          const SizedBox(height: 8),
          _SoapBlock(tag: 'P', title: 'Plan & Recommendations', body: soap.plan, color: Colors.orangeAccent),
          if (soap.prescriptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.medication_rounded, color: AppColors.clinicAccent, size: 18),
                const SizedBox(width: 8),
                Text('Prescriptions & Adjustments', style: CT.bodySmall.wght(700)),
              ],
            ),
            const SizedBox(height: 8),
            for (final String rx in soap.prescriptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rx, style: CT.caption.sized(12))),
                  ],
                ),
              ),
          ],
        ],

        if (summary != null) ...<Widget>[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text('Patient & Caregiver Mitra Plan', style: CT.bodySmall.wght(700)),
          const SizedBox(height: 8),
          Text(summary.title, style: CT.caption.sized(12).wght(700)),
          const SizedBox(height: 8),
          for (final String item in summary.keyTakeaways)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(item, style: CT.caption.sized(12))),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.clinicAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Next Checkup: ${summary.nextCheckup}', style: CT.caption.sized(12).wght(700)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SoapBlock extends StatelessWidget {
  const _SoapBlock({
    required this.tag,
    required this.title,
    required this.body,
    required this.color,
  });

  final String tag;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 10,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(tag, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: CT.caption.sized(11).wght(700)),
              const SizedBox(height: 2),
              Text(body, style: CT.caption.sized(12)),
            ],
          ),
        ),
      ],
    );
  }
}
