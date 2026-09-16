import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/models/mood_drawing.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/models/telehealth.dart';
import '../../../core/models/weekly_report.dart';
import '../../../core/services/weekly_report_service.dart';
import '../../../core/telehealth/telehealth_service.dart';
import '../../chat/doctor_patient_chat_screen.dart';
import '../../patient/health/report_screen.dart';
import '../../telehealth/video_consultation_screen.dart';
import '../../telehealth/widgets/clinic_consultation_report_card.dart';
import 'weekly_report_card.dart';
import '../../../l10n/content_labels.dart';
import '../careplan/care_plan_screen.dart';
import '../consultation/ai_preconsult_screen.dart';
import '../reports/medical_reports_screen.dart';
import '../widgets/clinic_widgets.dart';
import 'mood_drawing_detail_screen.dart';

/// One patient's longitudinal picture. Framed throughout as *cognitive
/// activity performance*, never as a diagnosis.
class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    // A real caseload can be empty or still loading — the old fixed
    // 8-patient mock never was, so `.first` as a fallback used to be safe.
    // It no longer is: an empty real caseload would crash here instead of
    // just showing a loading state.
    if (state.caseload.isEmpty) unawaited(state.loadCaseload());
    ClinicPatient? matched;
    for (final ClinicPatient c in state.caseload) {
      if (c.id == patientId) {
        matched = c;
        break;
      }
    }
    if (matched == null) {
      return Theme(
        data: AppTheme.clinic(),
        child: const Scaffold(
          backgroundColor: AppColors.clinicBackground,
          body: Center(child: CircularProgressIndicator(color: AppColors.clinicAccent)),
        ),
      );
    }
    final ClinicPatient patient = matched;
    final bool isDemoPatient = patient.id == state.patient.id;

    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 10),
                child: Row(
                  children: <Widget>[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      color: AppColors.clinicInk,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.doctorDetailTitle, style: CT.h3.wght(800))),
                    StatusChip(status: patient.status),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                  children: <Widget>[
                    // ── Patient Identity & Session Details Hero Card ─────
                    FadeInUp(
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                SceneImage(
                                  sceneId: patient.sceneId,
                                  size: 64,
                                  circle: true,
                                  borderColor: AppColors.clinicAccent.withValues(alpha: 0.25),
                                  borderWidth: 2.5,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        patient.name,
                                        style: CT.h2.sized(20).wght(800),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        l.doctorDetailAgeDistrict(patient.age, patient.district),
                                        style: CT.caption.wght(600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l.doctorDetailLanguageLine(patient.language),
                                        style: CT.caption.sized(11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: trendColor(patient.trend).withValues(alpha: 0.1),
                                    borderRadius: Corners.r(8),
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text('${patient.score}', style: CT.h3.wght(800).tint(trendColor(patient.trend))),
                                          const SizedBox(width: 2),
                                          Icon(patient.trend.icon, size: 14, color: trendColor(patient.trend)),
                                        ],
                                      ),
                                      Text(l.doctorDetailOverallLabel, style: CT.caption.sized(10).wght(600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Insets.md),
                            const Divider(color: AppColors.clinicHairline, height: 1),
                            const SizedBox(height: Insets.md),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _HeroStatTile(
                                    icon: Icons.bolt_rounded,
                                    iconColor: AppColors.seriesTeal,
                                    label: l.doctorDetailEngagementLabel,
                                    value: '${patient.engagement}%',
                                  ),
                                ),
                                Container(width: 1, height: 28, color: AppColors.clinicHairline),
                                Expanded(
                                  child: _HeroStatTile(
                                    icon: Icons.check_circle_outline_rounded,
                                    iconColor: AppColors.seriesBlue,
                                    label: l.doctorDetailAdherenceLabel,
                                    value: '${patient.adherence}%',
                                  ),
                                ),
                                Container(width: 1, height: 28, color: AppColors.clinicHairline),
                                Expanded(
                                  child: _HeroStatTile(
                                    icon: Icons.history_rounded,
                                    iconColor: AppColors.clinicInkSoft,
                                    label: l.doctorDetailLastSessionLabel,
                                    value: patient.lastSession.split(',').first,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    // ── Weekly Cognitive Report (doctor-only) ────────────
                    //
                    // Placed right after the identity card, not buried near
                    // the bottom of a long scroll — this is the one thing on
                    // the screen that answers "did they actually do their
                    // activities this week", and it used to take a dozen
                    // cards of scrolling to find. The accent edge marks it as
                    // the thing to check first, the way the alert-style cards
                    // elsewhere in the clinic theme do.
                    FadeInUp(
                      delayMs: 10,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        accentEdge: AppColors.clinicAccent,
                        child: _WeeklyReportHistoryCard(patientId: patient.id),
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    // ── The patient's own summary ───────────────────────
                    if (patient.id == state.patient.id && state.intakeComplete) ...<Widget>[
                      FadeInUp(
                        child: ClinicCard(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.description_outlined,
                                  color: AppColors.clinicAccent),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(l.doctorDetailReportCardTitle,
                                        style: CT.h2.sized(17)),
                                    const SizedBox(height: 2),
                                    Text(
                                      l.doctorDetailReportCardSubtitle,
                                      style: CT.caption,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SoftButton(
                                label: l.doctorDetailOpenReport,
                                icon: Icons.open_in_new_rounded,
                                color: AppColors.clinicAccent,
                                onPressed: () => Nav.push(context, const ReportScreen()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                    ],

                    // ── 3 Full-Width Action Cards ────────────────────────
                    // Card 1: Pre-Consultation Summary
                    FadeInUp(
                      delayMs: 20,
                      child: ClinicCard(
                        accentEdge: AppColors.clinicAccent,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AIPreconsultScreen(
                                patientName: patient.name,
                                patientAge: patient.age,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.clinicAccent.withValues(alpha: 0.12),
                                borderRadius: Corners.r(10),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, size: 22, color: AppColors.clinicAccent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          l.doctorDetailAIPreconsult,
                                          style: CT.body.wght(700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.clinicAccent.withValues(alpha: 0.1),
                                          borderRadius: Corners.r(4),
                                        ),
                                        child: Text('AI Digest', style: CT.caption.sized(9.5).wght(700).tint(AppColors.clinicAccent)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '7-day cognitive trends, medication & mood insights',
                                    style: CT.caption.sized(11.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.clinicInkSoft),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Card 2: Medical Reports
                    FadeInUp(
                      delayMs: 30,
                      child: ClinicCard(
                        accentEdge: const Color(0xFF2F7FB8),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MedicalReportsScreen(
                                patientName: patient.name,
                                patientId: patient.id,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F7FB8).withValues(alpha: 0.12),
                                borderRadius: Corners.r(10),
                              ),
                              child: const Icon(Icons.folder_shared_outlined, size: 22, color: Color(0xFF2F7FB8)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(l.doctorDetailMedicalReports, style: CT.body.wght(700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Original MRI, EEG & blood panels · Request from caregiver',
                                    style: CT.caption.sized(11.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.clinicInkSoft),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Card 3: Care Plan
                    FadeInUp(
                      delayMs: 40,
                      child: ClinicCard(
                        accentEdge: const Color(0xFF7A5680),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CarePlanScreen(
                                patientName: patient.name,
                                patientId: patient.id,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7A5680).withValues(alpha: 0.12),
                                borderRadius: Corners.r(10),
                              ),
                              child: const Icon(Icons.assignment_outlined, size: 22, color: Color(0xFF7A5680)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(l.doctorDetailCarePlan, style: CT.body.wght(700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Clinical recommendations, activities & caregiver instructions',
                                    style: CT.caption.sized(11.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.clinicInkSoft),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Medication & Routine (Visual schedule, not text walls) ───
                    FadeInUp(
                      delayMs: 50,
                      child: ClinicCard(
                        accentEdge: const Color(0xFFD9962B),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.medication_outlined, size: 18, color: Color(0xFFD9962B)),
                                const SizedBox(width: 8),
                                // Adherence is already a headline figure at
                                // the top of this screen; repeating it here
                                // invites a reader to wonder which of the two
                                // is the real one. This card is about what
                                // they take.
                                Expanded(
                                  child: Text(l.doctorDetailMedicationInfo, style: CT.h3.wght(700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0913A).withValues(alpha: 0.08),
                                      borderRadius: Corners.r(8),
                                      border: Border.all(color: const Color(0xFFE0913A).withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            const Icon(Icons.wb_sunny_rounded, size: 14, color: Color(0xFFE0913A)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                l.doctorDetailMorning,
                                                style: CT.caption.wght(700).tint(const Color(0xFFE0913A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text('08:00 AM', style: CT.caption.sized(10).wght(600)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Donepezil · 5mg', style: CT.bodySmall.wght(700)),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: Corners.r(4),
                                          ),
                                          child: Text('1 tab · With breakfast', style: CT.caption.sized(10.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7A5680).withValues(alpha: 0.08),
                                      borderRadius: Corners.r(8),
                                      border: Border.all(color: const Color(0xFF7A5680).withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            const Icon(Icons.nightlight_round, size: 14, color: Color(0xFF7A5680)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                l.doctorDetailEvening,
                                                style: CT.caption.wght(700).tint(const Color(0xFF7A5680)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text('08:30 PM', style: CT.caption.sized(10).wght(600)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Memantine · 10mg', style: CT.bodySmall.wght(700)),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: Corners.r(4),
                                          ),
                                          child: Text('1 tab · After dinner', style: CT.caption.sized(10.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: const <Widget>[
                                _RoutinePill(icon: Icons.directions_walk_rounded, label: 'Morning walk 15m'),
                                _RoutinePill(icon: Icons.psychology_outlined, label: 'Game practice 2x'),
                                _RoutinePill(icon: Icons.bedtime_outlined, label: 'Sleep schedule 10 PM'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Caregiver Observations ──────────────────────────
                    FadeInUp(
                      delayMs: 60,
                      child: ClinicCard(
                        accentEdge: const Color(0xFF7A5680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.record_voice_over_outlined, size: 18, color: Color(0xFF7A5680)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(l.doctorDetailCaregiverObs, style: CT.h3.wght(700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _CaregiverNoteBubble(
                              author: 'Priya (Daughter)',
                              note: l.doctorDetailCaregiverNote1,
                            ),
                            const SizedBox(height: 8),
                            _CaregiverNoteBubble(
                              author: 'Bhaskar (Son-in-law)',
                              note: l.doctorDetailCaregiverNote2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    // ── Teleconsultation & Direct Communication Banner ───
                    FadeInUp(
                      delayMs: 30,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.clinicAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.video_camera_front_rounded,
                                      color: AppColors.clinicAccent, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('Telehealth Consultation', style: CT.h3.sized(16)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Encrypted WebRTC call with live AI Clinical Scribing',
                                        style: CT.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Insets.md),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.clinicAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                                    label: const Text(
                                      'Start Video Call',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => VideoConsultationScreen(
                                            doctorId: state.myDoctorProfile?.id ?? '',
                                            patientId: patient.id,
                                            patientName: patient.name,
                                            doctorName: state.myDoctorProfile?.displayName ?? 'Doctor',
                                            isDoctor: true,
                                            isSelfTestMode: false,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.clinicAccent),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                                        color: AppColors.clinicAccent, size: 16),
                                    label: const Text(
                                      'Message',
                                      style: TextStyle(
                                          color: AppColors.clinicAccent, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => DoctorPatientChatScreen(
                                            doctorId: state.myDoctorProfile?.id ?? '',
                                            patientId: patient.id,
                                            patientName: patient.name,
                                            doctorName: state.myDoctorProfile?.displayName ?? 'Doctor',
                                            isDoctor: true,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Quick Self-Test Mirror Option
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => VideoConsultationScreen(
                                      doctorId: 'doc_001',
                                      patientId: patient.id,
                                      patientName: patient.name,
                                      doctorName: 'Dr. Sharma',
                                      isDoctor: true,
                                      isSelfTestMode: true,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const Icon(Icons.stream_rounded, size: 14, color: AppColors.clinicInkSoft),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Test Camera, Audio & AI Scribe (Single Device Mirror)',
                                        style: CT.caption.sized(11).tint(AppColors.clinicAccent),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Cognitive profile ───────────────────────────────
                    FadeInUp(
                      delayMs: 50,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(l.doctorDetailCognitiveProfileTitle, style: CT.h3),
                            const SizedBox(height: 3),
                            Text(patient.profile.updated, style: CT.caption),
                            const SizedBox(height: Insets.md),
                            // The radar chart that used to sit above these
                            // bars plotted the same six numbers, in a form
                            // that cannot be read off precisely — a clinician
                            // comparing 68 against 74 needs the figure, not a
                            // polygon. One reading of the profile, not two.
                            for (final CognitiveDomain d in CognitiveDomain.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 11),
                                child: Row(
                                  children: <Widget>[
                                    Icon(d.icon, size: 16, color: AppColors.clinicInkSoft),
                                    const SizedBox(width: 9),
                                    SizedBox(
                                      width: 84,
                                      child: Text(d.localizedLabel(l), style: CT.bodySmall),
                                    ),
                                    Expanded(
                                      child: MeterBar(
                                        value: patient.profile.score(d) / 100,
                                        color: _domainColor(patient.profile.score(d)),
                                        height: 8,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${patient.profile.score(d)}',
                                        textAlign: TextAlign.right,
                                        style: CT.body.wght(800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── 30-day trend ────────────────────────────────────
                    FadeInUp(
                      delayMs: 90,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(l.doctorDetailTrendTitle, style: CT.h3),
                                ),
                                Row(
                                  children: <Widget>[
                                    Icon(patient.trend.icon,
                                        size: 15, color: trendColor(patient.trend)),
                                    const SizedBox(width: 5),
                                    Text(patient.trend.localizedLabel(l),
                                        style: CT.caption
                                            .wght(700)
                                            .tint(trendColor(patient.trend))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(l.doctorDetailTrendCaption, style: CT.caption),
                            const SizedBox(height: Insets.md),
                            TrendLineChart(
                              points: <SeriesPoint>[
                                for (int i = 0; i < patient.thirtyDay.length; i++)
                                  SeriesPoint(
                                    i == 0
                                        ? l.doctorDetailTrendAgo
                                        : i == patient.thirtyDay.length - 1
                                            ? l.doctorDetailToday
                                            : '${patient.thirtyDay.length - i}',
                                    patient.thirtyDay[i],
                                  ),
                              ],
                              color: trendColor(patient.trend),
                              minValue: 25,
                              labelEvery: 7,
                              showDots: false,
                              height: 190,
                              band: (
                                low: patient.score - 8.0,
                                high: patient.score + 8.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // ── Activity breakdown ──────────────────────────────
                    if (isDemoPatient) ...<Widget>[
                      FadeInUp(
                        delayMs: 120,
                        child: ClinicCard(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(l.doctorDetailActivityBreakdownTitle, style: CT.h3),
                              const SizedBox(height: 3),
                              Text(l.doctorDetailActivityBreakdownCaption, style: CT.caption),
                              const SizedBox(height: Insets.md),
                              BarSeriesChart(
                                points: <SeriesPoint>[
                                  // Only activities with a real score — Mood
                                  // Canvas has none to plot honestly here.
                                  for (final GameDefinition g
                                      in MockData.games.where((GameDefinition g) => g.hasLevels))
                                    SeriesPoint(doctorChartLabel(l, g.id), _avg(state, g.id)),
                                ],
                                color: AppColors.seriesBlue,
                                showValues: true,
                                height: 175,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      FadeInUp(
                        delayMs: 150,
                        child: ClinicCard(
                          padding: const EdgeInsets.all(Insets.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(l.doctorDetailSessionLogTitle, style: CT.h3),
                              const SizedBox(height: Insets.md),
                              for (int i = 0; i < state.sessions.take(8).length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: <Widget>[
                                      SizedBox(
                                        width: 66,
                                        child: Text(
                                          state.sessions[i].dayOffset == 0
                                              ? l.doctorDetailToday
                                              : state.sessions[i].dayOffset == 1
                                                  ? l.doctorDetailYesterday
                                                  : l.doctorDetailDaysAgo(
                                                      state.sessions[i].dayOffset),
                                          style: CT.caption.wght(700),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          MockData.game(state.sessions[i].gameId).localizedName(l),
                                          style: CT.bodySmall.tint(AppColors.clinicInk),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('L${state.sessions[i].level}',
                                          style: CT.caption),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 34,
                                        child: Text(
                                          '${state.sessions[i].performance.overall}',
                                          textAlign: TextAlign.right,
                                          style: CT.body.wght(800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      if (state.moodDrawings.isNotEmpty) ...<Widget>[
                        FadeInUp(
                          delayMs: 165,
                          child: ClinicCard(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(l.doctorDetailMoodCanvasTitle, style: CT.h3),
                                const SizedBox(height: 3),
                                Text(l.doctorDetailMoodCanvasCaption, style: CT.caption),
                                const SizedBox(height: Insets.md),
                                SizedBox(
                                  height: 96,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: state.moodDrawings.length,
                                    separatorBuilder: (BuildContext context, int i) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (BuildContext context, int i) {
                                      final MoodDrawing drawing = state.moodDrawings[i];
                                      return GestureDetector(
                                        onTap: () => Nav.push(
                                          context,
                                          MoodDrawingDetailScreen(drawingId: drawing.id),
                                        ),
                                        child: Stack(
                                          children: <Widget>[
                                            ClipRRect(
                                              borderRadius: Corners.r(Corners.md),
                                              child: Image.memory(
                                                drawing.pngBytes,
                                                width: 96,
                                                height: 96,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            if (drawing.hasNote)
                                              Positioned(
                                                right: 4,
                                                top: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.clinicAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.description_rounded,
                                                      size: 12, color: Colors.white),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Insets.lg),
                      ],
                    ],

                    // ── Suggested next steps ────────────────────────────
                    FadeInUp(
                      delayMs: 190,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(l.doctorDetailConsiderationsTitle, style: CT.h3),
                            const SizedBox(height: 10),
                            for (final String s in _considerations(l, patient))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Icon(Icons.circle, size: 6,
                                        color: AppColors.clinicInkSoft),
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

                    // ── AI Clinical Scribe Consultation History ─────────
                    FadeInUp(
                      delayMs: 140,
                      child: ClinicCard(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: _ConsultationHistoryCard(patientId: patient.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _domainColor(int score) {
    if (score >= 75) return AppColors.success;
    if (score >= 60) return AppColors.seriesBlue;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  static double _avg(AppState state, GameId id) {
    final List<GameSession> list = state.sessionsFor(id);
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (double a, GameSession s) => a + s.performance.overall) /
        list.length;
  }

  static List<String> _considerations(AppLocalizations l, ClinicPatient p) {
    return <String>[
      if (p.trend == TrendDirection.down)
        l.doctorDetailConsiderationDecreased,
      if (p.adherence < 80)
        l.doctorDetailConsiderationLowAdherence(p.adherence),
      if (p.engagement < 55)
        l.doctorDetailConsiderationLowEngagement,
      if (p.trend == TrendDirection.up)
        l.doctorDetailConsiderationImproving,
      if (p.status == ClinicalStatus.followUp)
        l.doctorDetailConsiderationReviewDue,
      l.doctorDetailConsiderationFooter,
    ];
  }
}

/// The doctor's view of the patient's current-cycle weekly report — the only
/// place in the app this data is ever rendered (see `WeeklyReportCard`'s doc
/// comment). Automatic: there is no caregiver "send" action to wait on, just
/// whatever the caregiver's device last posted.
class _WeeklyReportHistoryCard extends StatefulWidget {
  const _WeeklyReportHistoryCard({required this.patientId});

  final String patientId;

  @override
  State<_WeeklyReportHistoryCard> createState() => _WeeklyReportHistoryCardState();
}

class _WeeklyReportHistoryCardState extends State<_WeeklyReportHistoryCard> {
  final WeeklyReportService _service = WeeklyReportService();
  bool _loading = true;
  WeeklyClinicalReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final WeeklyClinicalReport? report = await _service.getReport(widget.patientId);
    if (mounted) {
      setState(() {
        _report = report;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.clinicAccent)),
      );
    }
    if (_report == null) {
      return Row(
        children: <Widget>[
          const Icon(Icons.fact_check_outlined, color: AppColors.clinicAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No weekly report yet — one builds automatically as the patient plays and the caregiver adds notes.',
                style: CT.caption),
          ),
        ],
      );
    }
    return WeeklyReportCard(report: _report!);
  }
}

/// The doctor's own view of a patient's AI Clinical Scribe history — backed
/// by the same [ConsultationSession] records the patient/caregiver app
/// reads, so both sides show the same report.
class _ConsultationHistoryCard extends StatefulWidget {
  const _ConsultationHistoryCard({required this.patientId});

  final String patientId;

  @override
  State<_ConsultationHistoryCard> createState() => _ConsultationHistoryCardState();
}

class _ConsultationHistoryCardState extends State<_ConsultationHistoryCard> {
  final TelehealthService _telehealth = TelehealthService();
  bool _loading = true;
  List<ConsultationSession> _sessions = <ConsultationSession>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<ConsultationSession> sessions =
        await _telehealth.getPatientConsultations(widget.patientId);
    if (mounted) {
      setState(() {
        _sessions = sessions.where((ConsultationSession s) => s.soapNote != null).toList()
          ..sort((ConsultationSession a, ConsultationSession b) =>
              (b.endedAt ?? b.startedAt).compareTo(a.endedAt ?? a.startedAt));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.clinicAccent)),
      );
    }

    if (_sessions.isEmpty) {
      return Row(
        children: <Widget>[
          const Icon(Icons.history_edu_rounded, color: AppColors.clinicAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No AI Scribe consultation records yet.', style: CT.caption),
          ),
        ],
      );
    }

    final ConsultationSession latest = _sessions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.history_edu_rounded, color: AppColors.clinicAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('AI Scribe Consultation Records', style: CT.h3.sized(16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_sessions.length} Completed',
                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.clinicBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.clinicHairline),
          ),
          child: ClinicConsultationReportCard(session: latest),
        ),
      ],
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: CT.body.wght(800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: CT.caption.sized(10.5).tint(AppColors.clinicInkSoft),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RoutinePill extends StatelessWidget {
  const _RoutinePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.clinicHairline.withValues(alpha: 0.35),
        borderRadius: Corners.r(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: AppColors.clinicInkSoft),
          const SizedBox(width: 5),
          Text(label, style: CT.caption.sized(11).wght(600)),
        ],
      ),
    );
  }
}

class _CaregiverNoteBubble extends StatelessWidget {
  const _CaregiverNoteBubble({required this.author, required this.note});

  final String author;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.clinicHairline.withValues(alpha: 0.25),
        borderRadius: Corners.r(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF7A5680)),
              const SizedBox(width: 4),
              Text(author, style: CT.caption.wght(700).tint(const Color(0xFF7A5680))),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: CT.bodySmall.copyWith(height: 1.35)),
        ],
      ),
    );
  }
}
