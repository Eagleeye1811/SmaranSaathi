import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/clinical.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../widgets/clinic_widgets.dart';
import 'patient_detail_screen.dart';

/// The caseload list — sortable, filterable, and readable at a glance.
class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  String _query = '';
  ClinicalStatus? _filter;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ClinicPatient> all = state.caseload;
    final List<ClinicPatient> filtered = all.where((ClinicPatient c) {
      final bool matchesQuery = _query.isEmpty ||
          c.name.toLowerCase().contains(_query.toLowerCase()) ||
          c.district.toLowerCase().contains(_query.toLowerCase());
      final bool matchesFilter = _filter == null || c.status == _filter;
      return matchesQuery && matchesFilter;
    }).toList()
      ..sort((ClinicPatient a, ClinicPatient b) => a.score.compareTo(b.score));

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          ClinicTopBar(
            title: l.doctorTabPatients,
            subtitle: l.doctorPatientsSubtitle(all.length, state.caseload.length),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 12),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _search,
                  style: CT.body,
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.doctorPatientsSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 19),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filters sit in one row above the list.
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      _FilterChip(
                        label: l.doctorPatientsFilterAll,
                        selected: _filter == null,
                        color: AppColors.clinicAccent,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final ClinicalStatus s in ClinicalStatus.values)
                        _FilterChip(
                          label: s.localizedLabel(l),
                          selected: _filter == s,
                          color: statusColor(s),
                          onTap: () => setState(() => _filter = s),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: l.doctorPatientsEmptyTitle,
                    message: l.doctorPatientsEmptyMessage,
                    icon: Icons.search_off_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, 32),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int i) {
                      if (i == filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: _ColumnKey(),
                        );
                      }
                      return FadeInUp(
                        delayMs: (i % 8) * 35,
                        child: _PatientTile(
                          patient: filtered[i],
                          onTap: () => Nav.push(
                            context,
                            PatientDetailScreen(patientId: filtered[i].id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: Corners.r(Corners.pill),
            border: Border.all(color: selected ? color : AppColors.clinicHairline),
          ),
          child: Text(
            label,
            style: CT.caption
                .sized(12.5)
                .wght(selected ? 800 : 600)
                .tint(selected ? Colors.white : AppColors.clinicInkSoft),
          ),
        ),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, required this.onTap});
  final ClinicPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color tc = trendColor(patient.trend);
    return ClinicCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          SceneImage(sceneId: patient.sceneId, size: 46, circle: true),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(patient.name,
                    style: CT.body.wght(700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${patient.age} · ${patient.district}',
                    style: CT.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(patient.lastSession, style: CT.caption.sized(11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Sparkline(
            values: patient.thirtyDay.sublist(patient.thirtyDay.length - 14),
            color: tc,
            width: 58,
            height: 26,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('${patient.score}', style: CT.stat.sized(21).tint(tc)),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Icon(patient.trend.icon, size: 12, color: tc),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        patient.trend.localizedLabel(l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CT.caption.sized(10.5).tint(tc),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnKey extends StatelessWidget {
  const _ColumnKey();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ClinicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.doctorPatientsColumnKeyTitle, style: CT.overline),
          const SizedBox(height: 8),
          Text(
            l.doctorPatientsColumnKeyBody,
            style: CT.caption,
          ),
          const SizedBox(height: 12),
          ChartLegend(
            entries: <({String label, Color color})>[
              (label: l.doctorPatientsLegendImproving, color: AppColors.success),
              (label: l.doctorPatientsLegendStable, color: AppColors.clinicInkSoft),
              (label: l.doctorPatientsLegendDeclining, color: AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }
}
