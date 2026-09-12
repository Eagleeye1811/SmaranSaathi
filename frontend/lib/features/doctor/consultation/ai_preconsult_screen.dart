import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';

/// AI Pre-Consultation Summary Screen.
/// Synthesizes 7-day data (activity, cognitive performance, mood, medication, caregiver notes)
/// into a scannable visual dashboard without walls of text.
/// Strictly framed as clinical decision support — never diagnostic.
class AIPreconsultScreen extends StatelessWidget {
  const AIPreconsultScreen({
    super.key,
    required this.patientName,
    required this.patientAge,
  });

  final String patientName;
  final int patientAge;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      appBar: AppBar(
        title: Text(l.doctorAIPreconsultTitle, style: CT.h3.wght(700)),
        backgroundColor: AppColors.clinicSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.clinicInk),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Compact AI Disclaimer ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.clinicAccent.withValues(alpha: 0.08),
                borderRadius: Corners.r(8),
                border: Border.all(color: AppColors.clinicAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.clinicAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Decision Support · Non-diagnostic 7-day synthesis for clinician review',
                      style: CT.caption.sized(11).wght(600).tint(AppColors.clinicAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Patient Quick Header ─────────────────────────────
            ClinicCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.12),
                    child: Text(
                      patientName.isNotEmpty ? patientName[0] : 'P',
                      style: CT.body.wght(700).tint(AppColors.clinicAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(patientName, style: CT.body.wght(800)),
                        Text('$patientAge years · Caseload ID: p_aama', style: CT.caption.sized(11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.clinicHairline.withValues(alpha: 0.4),
                      borderRadius: Corners.r(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.date_range_rounded, size: 12, color: AppColors.clinicInkSoft),
                        const SizedBox(width: 4),
                        Text('Past 7 Days', style: CT.caption.sized(11).wght(700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Section 1: Cognitive & Activity Trends ───────────
            ClinicCard(
              accentEdge: const Color(0xFF2F7FB8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionHeader(
                    icon: Icons.psychology_outlined,
                    iconColor: const Color(0xFF2F7FB8),
                    title: l.doctorAIPreconsultCognitive,
                    badge: 'Stable (78/100)',
                    badgeColor: AppColors.success,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const <Widget>[
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.seriesBlue,
                          value: '18 Sessions',
                          label: 'Target: 2/day met',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.memory_rounded,
                          color: AppColors.seriesTeal,
                          value: '84% Accuracy',
                          label: 'Working memory',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const <Widget>[
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.trending_up_rounded,
                          color: AppColors.success,
                          value: '+6% Recall',
                          label: 'Sequence tasks',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.schedule_rounded,
                          color: Color(0xFFD9962B),
                          value: 'Afternoon lag',
                          label: '>1800ms vs 1200ms',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Section 2: Medication Adherence ──────────────────
            ClinicCard(
              accentEdge: const Color(0xFFD9962B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionHeader(
                    icon: Icons.medication_outlined,
                    iconColor: const Color(0xFFD9962B),
                    title: l.doctorAIPreconsultMedication,
                    badge: '95% Adherence',
                    badgeColor: AppColors.success,
                  ),
                  const SizedBox(height: 10),
                  _MedicationStatusRow(
                    timeTag: 'Morning',
                    timeIcon: Icons.wb_sunny_rounded,
                    tagColor: const Color(0xFFE0913A),
                    medName: 'Donepezil 5mg',
                    status: '7/7 doses on-time',
                    isComplete: true,
                  ),
                  const SizedBox(height: 6),
                  _MedicationStatusRow(
                    timeTag: 'Evening',
                    timeIcon: Icons.nightlight_round,
                    tagColor: const Color(0xFF7A5680),
                    medName: 'Memantine 10mg',
                    status: '6/7 on-time (1 delayed 2h)',
                    isComplete: true,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: Corners.r(6),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.verified_outlined, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text('No adverse side-effects or missed critical doses', style: CT.caption.sized(11).wght(600).tint(AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Section 3: Mood & Wellbeing Trends ───────────────
            ClinicCard(
              accentEdge: const Color(0xFF3E9268),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionHeader(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    iconColor: const Color(0xFF3E9268),
                    title: l.doctorAIPreconsultMood,
                    badge: 'Mostly Cheerful',
                    badgeColor: AppColors.success,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const <Widget>[
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.emoji_emotions_outlined,
                          color: Color(0xFF3E9268),
                          value: '5 / 7 Days',
                          label: 'Calm & cheerful',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.bedtime_outlined,
                          color: Color(0xFF2F7FB8),
                          value: '6.8h Sleep',
                          label: 'Mild mid-wake',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const <Widget>[
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.self_improvement_rounded,
                          color: Color(0xFF7A5680),
                          value: '5 Routines',
                          label: '3 breath + 2 yoga',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.brush_outlined,
                          color: Color(0xFFD9962B),
                          value: 'Positive',
                          label: 'Mood canvas tone',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Section 4: Caregiver Observations ────────────────
            ClinicCard(
              accentEdge: const Color(0xFF7A5680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionHeader(
                    icon: Icons.record_voice_over_outlined,
                    iconColor: const Color(0xFF7A5680),
                    title: l.doctorAIPreconsultCaregiver,
                    badge: '2 Notes',
                    badgeColor: const Color(0xFF7A5680),
                  ),
                  const SizedBox(height: 10),
                  _CaregiverQuoteTile(
                    author: 'Priya (Daughter)',
                    quote: 'Joyful conversation reminiscing about village festivals. Brief glasses confusion.',
                  ),
                  const SizedBox(height: 6),
                  _CaregiverQuoteTile(
                    author: 'Bhaskar (Son-in-law)',
                    quote: 'Consistent appetite. Evening walks reduced bedtime restlessness.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Consultation Action Button ───────────────────────
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clinicAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.video_call_rounded, size: 22),
              label: Text(l.doctorAIPreconsultStartConsult, style: CT.body.wght(700).tint(Colors.white)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badge,
    required this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: CT.body.wght(700))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: Corners.r(6),
          ),
          child: Text(badge, style: CT.caption.wght(700).tint(badgeColor)),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: Corners.r(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: CT.bodySmall.wght(700)),
                Text(label, style: CT.caption.sized(10.5).tint(AppColors.clinicInkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationStatusRow extends StatelessWidget {
  const _MedicationStatusRow({
    required this.timeTag,
    required this.timeIcon,
    required this.tagColor,
    required this.medName,
    required this.status,
    required this.isComplete,
  });

  final String timeTag;
  final IconData timeIcon;
  final Color tagColor;
  final String medName;
  final String status;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.clinicHairline.withValues(alpha: 0.25),
        borderRadius: Corners.r(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(timeIcon, size: 14, color: tagColor),
          const SizedBox(width: 6),
          Text(medName, style: CT.bodySmall.wght(700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: Corners.r(4),
            ),
            child: Text(status, style: CT.caption.sized(10.5).wght(600).tint(AppColors.success)),
          ),
        ],
      ),
    );
  }
}

class _CaregiverQuoteTile extends StatelessWidget {
  const _CaregiverQuoteTile({
    required this.author,
    required this.quote,
  });

  final String author;
  final String quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.clinicHairline.withValues(alpha: 0.25),
        borderRadius: Corners.r(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(author, style: CT.caption.wght(700).tint(const Color(0xFF7A5680))),
          const SizedBox(height: 2),
          Text(quote, style: CT.caption.sized(11.5)),
        ],
      ),
    );
  }
}
