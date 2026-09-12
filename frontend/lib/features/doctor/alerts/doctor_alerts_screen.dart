import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/doctor.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../patients/patient_detail_screen.dart';
import '../widgets/clinic_widgets.dart';

/// Alerts raised by the platform and pending connection requests.
/// Clean, concise, and focused on urgent clinical items requiring triage.
class DoctorAlertsScreen extends StatefulWidget {
  const DoctorAlertsScreen({super.key});

  @override
  State<DoctorAlertsScreen> createState() => _DoctorAlertsScreenState();
}

class _DoctorAlertsScreenState extends State<DoctorAlertsScreen> {

  @override
  void initState() {
    super.initState();
  }

  /// Accepting here is what connects the doctor on the caregiver's screen —
  /// the two used to be separate lists that never heard about each other, so
  /// a request could be accepted here and the caregiver would go on seeing an
  /// invitation nobody had answered.
  void _acceptConnection(String id) {
    AppScope.read(context).acceptConnectionRequest(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection accepted. Patient added to caseload.'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _declineConnection(String id) {
    AppScope.read(context).declineConnectionRequest(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection request declined.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DoctorAlert> urgentAlerts = state.alerts
        .where((DoctorAlert a) => a.severity == AlertSeverity.urgent)
        .toList();

    final bool hasItems = state.myConnectionRequests.isNotEmpty || urgentAlerts.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ClinicTopBar(
              title: l.doctorDetailAlertsTitle,
              showBack: true,
              showAlerts: false,
              showProfile: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 32),
                children: <Widget>[
                  // ── Pending Connection Requests ──────────────────────
                  if (state.myConnectionRequests.isNotEmpty) ...<Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.person_add_outlined, size: 18, color: Color(0xFFD9962B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.doctorAlertsSectionConnection,
                            style: CT.h3.sized(17),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9962B).withValues(alpha: 0.15),
                            borderRadius: Corners.r(10),
                          ),
                          child: Text(
                            '${state.myConnectionRequests.length}',
                            style: CT.caption.wght(700).tint(const Color(0xFFD9962B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final ConnectionRequest req in state.myConnectionRequests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ClinicCard(
                          accentEdge: const Color(0xFFD9962B),
                          padding: const EdgeInsets.all(Insets.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFD9962B).withValues(alpha: 0.15),
                                    child: Text(
                                      req.patientName[0],
                                      style: CT.bodySmall.wght(700).tint(const Color(0xFFD9962B)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(req.patientName, style: CT.body.wght(800)),
                                        Text('${req.patientAge} yrs · ${req.district}', style: CT.caption),
                                      ],
                                    ),
                                  ),
                                  Text(req.timeAgo, style: CT.caption.sized(11)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(req.requestedByLabel, style: CT.caption.wght(600)),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 6,
                                children: <Widget>[
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.clinicInkSoft,
                                    ),
                                    onPressed: () => _declineConnection(req.id),
                                    child: Text(l.doctorAlertsDecline, style: CT.caption),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.clinicAccent,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      elevation: 0,
                                    ),
                                    onPressed: () => _acceptConnection(req.id),
                                    child: Text(l.doctorAlertsAccept, style: CT.caption.wght(700).tint(Colors.white)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: Insets.lg),
                  ],

                  // ── Clinical Assessment Required (Urgent Only) ────────
                  if (urgentAlerts.isNotEmpty) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            l.doctorAlertsSeverityAssessment,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CT.h3.sized(17),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: Corners.r(10),
                          ),
                          child: Text(
                            '${urgentAlerts.length}',
                            style: CT.caption.wght(700).tint(AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < urgentAlerts.length; i++)
                      FadeInUp(
                        delayMs: i * 40,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertCard(
                            alert: urgentAlerts[i],
                            onOpen: () {
                              final ClinicPatient? match = state.caseload
                                  .where((ClinicPatient c) =>
                                      c.name == urgentAlerts[i].patientName)
                                  .firstOrNull;
                              if (match != null) {
                                Nav.push(context, PatientDetailScreen(patientId: match.id));
                              }
                            },
                          ),
                        ),
                      ),
                  ],

                  // ── Clean Empty State if nothing pending ─────────────
                  if (!hasItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded,
                                  size: 36, color: AppColors.success),
                            ),
                            const SizedBox(height: 16),
                            Text('All clear', style: CT.h3.wght(700)),
                            const SizedBox(height: 6),
                            Text(
                              'No urgent alerts or pending connection requests.',
                              style: CT.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onOpen});
  final DoctorAlert alert;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ClinicCard(
      padding: const EdgeInsets.all(Insets.md),
      accentEdge: AppColors.danger,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(alert.patientName, style: CT.body.wght(800))),
              Text(alert.age, style: CT.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(alert.title, style: CT.body.wght(600)),
          const SizedBox(height: 6),
          Text(alert.detail, style: CT.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (alert.domain != null)
                PillTag(
                  label: alert.domain!.localizedLabel(l),
                  color: AppColors.clinicInkSoft,
                  dense: true,
                ),
              const Spacer(),
              Text(l.doctorAlertsOpenRecord,
                  style: CT.caption.wght(700).tint(AppColors.clinicAccent)),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.clinicAccent),
            ],
          ),
        ],
      ),
    );
  }
}
