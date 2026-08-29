import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/game.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../patients/patient_detail_screen.dart';
import '../widgets/clinic_widgets.dart';

/// Alerts raised by the platform, grouped by severity.
class DoctorAlertsScreen extends StatelessWidget {
  const DoctorAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<DoctorAlert> alerts = state.alerts;

    final Map<AlertSeverity, List<DoctorAlert>> grouped =
        <AlertSeverity, List<DoctorAlert>>{
      for (final AlertSeverity s in AlertSeverity.values)
        s: alerts.where((DoctorAlert a) => a.severity == s).toList(),
    };
    final List<AlertSeverity> order = <AlertSeverity>[
      AlertSeverity.urgent,
      AlertSeverity.watch,
      AlertSeverity.info,
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          ClinicTopBar(
            title: 'Alerts',
            subtitle: '${alerts.length} open across the caseload',
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
                        for (final AlertSeverity s in order)
                          Expanded(
                            child: ClinicStat(
                              label: s == AlertSeverity.urgent
                                  ? 'Assessment'
                                  : s == AlertSeverity.watch
                                      ? 'Attention'
                                      : 'Informational',
                              value: '${grouped[s]!.length}',
                              color: severityColor(s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                for (final AlertSeverity s in order) ...<Widget>[
                  if (grouped[s]!.isNotEmpty) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: severityColor(s),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(s.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CT.h3.sized(17)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < grouped[s]!.length; i++)
                      FadeInUp(
                        delayMs: i * 40,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertCard(
                            alert: grouped[s]![i],
                            onOpen: () {
                              final ClinicPatient? match = state.caseload
                                  .where((ClinicPatient c) =>
                                      c.name == grouped[s]![i].patientName)
                                  .firstOrNull;
                              if (match != null) {
                                Nav.push(context, PatientDetailScreen(patientId: match.id));
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: Insets.md),
                  ],
                ],
              ],
            ),
          ),
        ],
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
    final Color c = severityColor(alert.severity);
    return ClinicCard(
      padding: const EdgeInsets.all(Insets.md),
      accentEdge: c,
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
          const SizedBox(height: 5),
          Text(alert.title, style: CT.body.wght(600)),
          const SizedBox(height: 7),
          Text(alert.detail, style: CT.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    if (alert.domain != null)
                      PillTag(
                        label: alert.domain!.label,
                        icon: alert.domain!.icon,
                        color: AppColors.clinicInkSoft,
                        dense: true,
                      ),
                    PillTag(label: alert.severity.label, color: c, dense: true),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('Open record', style: CT.caption.wght(700).tint(AppColors.clinicAccent)),
              const Icon(Icons.chevron_right_rounded,
                  size: 17, color: AppColors.clinicAccent),
            ],
          ),
        ],
      ),
    );
  }
}
