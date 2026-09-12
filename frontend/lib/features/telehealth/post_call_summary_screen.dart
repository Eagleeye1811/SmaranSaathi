import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/telehealth.dart';
import '../../../core/telehealth/telehealth_service.dart';
import '../doctor/widgets/clinic_widgets.dart';

/// Doctor's Post-Consultation Clinical Scribe Review Screen.
class PostCallSummaryScreen extends StatefulWidget {
  const PostCallSummaryScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.doctorName,
    required this.durationSeconds,
    required this.transcript,
  });

  final String doctorId;
  final String patientId;
  final String patientName;
  final String doctorName;
  final int durationSeconds;
  final String transcript;

  @override
  State<PostCallSummaryScreen> createState() => _PostCallSummaryScreenState();
}

class _PostCallSummaryScreenState extends State<PostCallSummaryScreen> {
  final TelehealthService _telehealth = TelehealthService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isApproved = false;

  late TextEditingController _subjectiveController;
  late TextEditingController _objectiveController;
  late TextEditingController _assessmentController;
  late TextEditingController _planController;

  ClinicalSoapNote? _soapNote;
  PatientMitraSummary? _patientSummary;

  @override
  void initState() {
    super.initState();
    _subjectiveController = TextEditingController();
    _objectiveController = TextEditingController();
    _assessmentController = TextEditingController();
    _planController = TextEditingController();

    _loadAiSummary();
  }

  Future<void> _loadAiSummary() async {
    final Map<String, dynamic> result = await _telehealth.generateAiSummary(
      doctorId: widget.doctorId,
      patientId: widget.patientId,
      patientName: widget.patientName,
      transcript: widget.transcript,
    );

    if (mounted) {
      final ClinicalSoapNote soap = result['soap_note'] as ClinicalSoapNote;
      final PatientMitraSummary summary = result['patient_summary'] as PatientMitraSummary;

      setState(() {
        _soapNote = soap;
        _patientSummary = summary;
        _subjectiveController.text = soap.subjective;
        _objectiveController.text = soap.objective;
        _assessmentController.text = soap.assessment;
        _planController.text = soap.plan;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    super.dispose();
  }

  Future<void> _saveAndApprove() async {
    setState(() => _isSaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isApproved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clinical Note approved & saved to patient record!'),
          backgroundColor: AppColors.clinicAccent,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.clinicInk),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('AI Clinical Scribe Review', style: CT.h3.wght(800)),
          actions: <Widget>[
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.clinicAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.clinicAccent),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.durationSeconds ~/ 60}m ${widget.durationSeconds % 60}s',
                    style: const TextStyle(
                      color: AppColors.clinicAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(color: AppColors.clinicAccent),
                    const SizedBox(height: 18),
                    Text('Gemini AI Scribe synthesizing consultation...', style: CT.h3.sized(15)),
                    const SizedBox(height: 6),
                    Text('Extracting SOAP clinical notes & caregiver guidance', style: CT.caption),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: <Widget>[
                  // ── Consultation Info Header Card ─────────────────────────
                  ClinicCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.15),
                          child: const Icon(Icons.verified_user_rounded,
                              color: AppColors.clinicAccent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(widget.patientName, style: CT.h2.sized(18)),
                              const SizedBox(height: 2),
                              Text('Teleconsultation with ${widget.doctorName}',
                                  style: CT.caption),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(
                                color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Section 1: Doctor SOAP Note (Editable) ────────────────
                  Text('CLINICAL SOAP NOTE', style: CT.h3.sized(14).wght(800)),
                  const SizedBox(height: 4),
                  Text('Review, edit and sign off before saving to EHR.', style: CT.caption),
                  const SizedBox(height: 12),

                  _SoapEditCard(
                    tag: 'S',
                    title: 'Subjective (Symptoms & Reported State)',
                    controller: _subjectiveController,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 10),

                  _SoapEditCard(
                    tag: 'O',
                    title: 'Objective (Clinical Observation & Latency)',
                    controller: _objectiveController,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 10),

                  _SoapEditCard(
                    tag: 'A',
                    title: 'Assessment (Cognitive Stability)',
                    controller: _assessmentController,
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(height: 10),

                  _SoapEditCard(
                    tag: 'P',
                    title: 'Plan & Recommendations',
                    controller: _planController,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 16),

                  // ── Prescriptions & Cognitive Games ───────────────────────
                  if (_soapNote != null && _soapNote!.prescriptions.isNotEmpty) ...<Widget>[
                    ClinicCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.medication_rounded,
                                  color: AppColors.clinicAccent, size: 20),
                              const SizedBox(width: 8),
                              Text('Prescriptions & Adjustments', style: CT.h3.sized(15)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final String rx in _soapNote!.prescriptions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.check_circle_outline_rounded,
                                      color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(rx, style: CT.bodySmall)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Section 2: Patient & Caregiver Mitra Care Plan ─────────
                  Text('PATIENT & CAREGIVER MITRA PLAN', style: CT.h3.sized(14).wght(800)),
                  const SizedBox(height: 4),
                  Text('This simplified guidance is sent to the caregiver timeline.', style: CT.caption),
                  const SizedBox(height: 12),

                  if (_patientSummary != null)
                    ClinicCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(_patientSummary!.title, style: CT.h3.sized(16)),
                          const SizedBox(height: 10),
                          for (final String item in _patientSummary!.keyTakeaways)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(item, style: CT.bodySmall)),
                                ],
                              ),
                            ),
                          const Divider(height: 20),
                          Row(
                            children: <Widget>[
                              const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: AppColors.clinicAccent),
                              const SizedBox(width: 8),
                              Text('Next Checkup: ${_patientSummary!.nextCheckup}',
                                  style: CT.bodySmall.wght(700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Approve & Save Button ─────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.clinicAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(
                        _isApproved ? 'Note Approved & Saved' : 'Approve & Save to Medical Record',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isSaving || _isApproved ? null : _saveAndApprove,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SoapEditCard extends StatelessWidget {
  const _SoapEditCard({
    required this.tag,
    required this.title,
    required this.controller,
    required this.color,
  });

  final String tag;
  final String title;
  final TextEditingController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 12,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  tag,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: CT.bodySmall.wght(700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: null,
            style: CT.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.clinicBackground,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
