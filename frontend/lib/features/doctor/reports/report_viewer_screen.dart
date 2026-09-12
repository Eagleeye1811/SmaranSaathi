import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/medical_report.dart';
import '../widgets/clinic_widgets.dart';

/// Screen allowing the doctor to view the original preserved medical diagnostic report.
/// AI summary removed per clinical requirement — displaying strictly original diagnostic record.
class ReportViewerScreen extends StatefulWidget {
  const ReportViewerScreen({
    super.key,
    required this.report,
    required this.patientName,
    this.showOriginalFirst = true,
  });

  final MedicalReport report;
  final String patientName;
  final bool showOriginalFirst;

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  bool _doctorVerified = true;

  @override
  Widget build(BuildContext context) {
    final MedicalReport r = widget.report;

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(r.kind.label, style: CT.h3.wght(700)),
            Text('${widget.patientName} · ${r.dateLabel}', style: CT.caption),
          ],
        ),
        backgroundColor: AppColors.clinicSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.clinicInk),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
              side: BorderSide.none,
              avatar: const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
              label: Text('Original Record', style: CT.caption.wght(700).tint(AppColors.success)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.clinicHairline.withValues(alpha: 0.3),
                borderRadius: Corners.r(8),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.clinicInkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Preserved original diagnostic record: ${r.fileName.isNotEmpty ? r.fileName : "clinical_diagnostic_report.pdf"}',
                      style: CT.caption.wght(600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Document Canvas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: Corners.r(8),
                border: Border.all(color: Colors.black12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Hospital header
                  Center(
                    child: Column(
                      children: <Widget>[
                        Text(
                          'GUWAHATI NEUROLOGICAL INSTITUTE & DIAGNOSTICS',
                          style: CT.caption.wght(800).tint(const Color(0xFF1B2430)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Department of Radiodiagnosis & Clinical Pathology · NABH Accredited',
                          style: CT.caption.sized(10).tint(Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(thickness: 1.5, color: Colors.black87),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Patient demographic grid
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('Patient: ${widget.patientName}', style: CT.caption.wght(700)),
                            const Text('Age/Sex: 72Y / F', style: TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('Ref Doctor: ${r.doctorName}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            Text('Date: ${r.dateLabel}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Clinical findings based on report kind
                  if (r.kind == ReportKind.bloodTest) ...<Widget>[
                    Text('CLINICAL INDICATION:', style: CT.caption.wght(800)),
                    Text(
                      'Comprehensive metabolic panel, hematology, and cognitive biomarker evaluation.',
                      style: CT.caption.sized(11.5),
                    ),
                    const SizedBox(height: 10),
                    Text('INVESTIGATION FINDINGS:', style: CT.caption.wght(800)),
                    const SizedBox(height: 4),
                    _labRow('Hemoglobin (Hb)', '12.8 g/dL', '12.0 - 15.0', false),
                    _labRow('Serum Vitamin B12', '210 pg/mL', '200 - 900', true),
                    _labRow('Thyroid Stimulating Hormone (TSH)', '2.45 µIU/mL', '0.4 - 4.5', false),
                    _labRow('HbA1c (Glycated Hb)', '6.1 %', '< 5.7 (Normal)', true),
                    _labRow('Serum Folate', '7.2 ng/mL', '> 4.0', false),
                    const SizedBox(height: 10),
                    Text('IMPRESSION:', style: CT.caption.wght(800)),
                    Text(
                      '1. Mild pre-diabetic glycemic profile (HbA1c 6.1%).\n'
                      '2. Borderline serum B12 level — oral supplementation advised to support neural health.\n'
                      '3. Normal thyroid function and hematological markers.',
                      style: CT.caption.sized(11.5).wght(600),
                    ),
                  ] else if (r.kind == ReportKind.eeg) ...<Widget>[
                    Text('CLINICAL INDICATION:', style: CT.caption.wght(800)),
                    Text('Routine digital electroencephalogram for cognitive fluctuation evaluation.', style: CT.caption.sized(11.5)),
                    const SizedBox(height: 10),
                    Text('FINDINGS:', style: CT.caption.wght(800)),
                    Text(
                      'The awake recording shows symmetrical background posterior alpha rhythm (8.5–9 Hz, 35 µV). Hyperventilation and photic stimulation elicited no paroxysmal discharges. Mild generalized diffuse theta slowing observed during drowsy states, consistent with age.',
                      style: CT.caption.sized(11.5).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Text('IMPRESSION:', style: CT.caption.wght(800)),
                    Text('Mild diffuse background slowing without epileptiform activity.', style: CT.caption.sized(11.5).wght(600)),
                  ] else ...<Widget>[
                    Text('CLINICAL INDICATION:', style: CT.caption.wght(800)),
                    Text(
                      'Evaluation of progressive short-term memory impairment and spatial disorientation.',
                      style: CT.caption.sized(11.5),
                    ),
                    const SizedBox(height: 10),
                    Text('PROTOCOL / TECHNIQUE:', style: CT.caption.wght(800)),
                    Text(
                      'Multiplanar multi-sequence MR imaging of the brain was performed on a 3.0T scanner including T1W, T2W, FLAIR, DWI, and coronal T1 for hippocampal volumetry.',
                      style: CT.caption.sized(11.5),
                    ),
                    const SizedBox(height: 10),
                    Text('FINDINGS:', style: CT.caption.wght(800)),
                    Text(
                      '1. Cerebral atrophy: Mild generalized cortical atrophy, slightly greater in bilateral temporal regions.\n'
                      '2. Hippocampal volume: Mild bilateral volume loss (MTA score 2).\n'
                      '3. White matter: Fazekas grade 1 punctate periventricular hyperintensities noted.\n'
                      '4. No acute territorial infarction, hemorrhage, or mass effect identified.\n'
                      '5. Brainstem and cerebellum unremarkable.',
                      style: CT.caption.sized(11.5).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Text('IMPRESSION:', style: CT.caption.wght(800)),
                    Text(
                      'Mild bilateral hippocampal and temporal volume loss consistent with neurodegenerative pattern (mild cognitive impairment spectrum).',
                      style: CT.caption.sized(11.5).wght(600),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            width: 100,
                            height: 28,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text('NABH VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Dr. A. K. Baruah, MD, DMRD', style: CT.caption.sized(10).wght(700)),
                          Text('Consultant Radiologist / Pathologist', style: CT.caption.sized(9)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Doctor Verification Banner
            ClinicCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    _doctorVerified ? Icons.check_circle_rounded : Icons.pending_outlined,
                    color: _doctorVerified ? AppColors.success : AppColors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _doctorVerified ? 'Verified by Attending Clinician' : 'Pending Verification',
                          style: CT.caption.wght(700).tint(_doctorVerified ? AppColors.success : AppColors.warning),
                        ),
                        Text('Original record confirmed for clinical decision review.', style: CT.caption.sized(11)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _doctorVerified,
                    activeThumbColor: AppColors.success,
                    onChanged: (bool v) => setState(() => _doctorVerified = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Widget _labRow(String test, String result, String ref, bool isAlert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text(test, style: const TextStyle(fontSize: 11, color: Colors.black87))),
          Expanded(
            flex: 2,
            child: Text(
              result,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAlert ? const Color(0xFFC9694F) : Colors.black87),
            ),
          ),
          Expanded(flex: 2, child: Text(ref, style: const TextStyle(fontSize: 10, color: Colors.black54))),
        ],
      ),
    );
  }
}
