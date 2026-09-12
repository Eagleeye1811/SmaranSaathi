import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/medical_report.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';
import 'report_viewer_screen.dart';

/// Screen listing patient's medical reports (MRI, EEG, Blood Test, etc.)
/// Original diagnostic reports only with options to request reports from caregiver.
class MedicalReportsScreen extends StatefulWidget {
  const MedicalReportsScreen({
    super.key,
    this.patientName = 'Aama Devi',
    this.patientId = 'p_aama',
  });

  final String patientName;
  final String patientId;

  @override
  State<MedicalReportsScreen> createState() => _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends State<MedicalReportsScreen> {
  late List<MedicalReport> _reports;
  ReportKind? _selectedKind;

  @override
  void initState() {
    super.initState();
    _reports = List<MedicalReport>.from(MockData.patientMedicalReports());
  }

  void _showRequestReportDialog() {
    ReportKind selectedKind = ReportKind.bloodTest;
    final TextEditingController noteCtrl = TextEditingController(
      text: 'Please upload the latest lab reports or diagnostic records from your recent visit.',
    );

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.clinicSurface,
              title: Row(
                children: <Widget>[
                  const Icon(Icons.forward_to_inbox_rounded, color: AppColors.clinicAccent, size: 22),
                  const SizedBox(width: 8),
                  Text('Request Report', style: CT.h3.wght(700)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Report Type Required', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ReportKind>(
                      initialValue: selectedKind,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: ReportKind.values
                          .map((ReportKind k) => DropdownMenuItem<ReportKind>(
                                value: k,
                                child: Text(k.label, style: CT.bodySmall),
                              ))
                          .toList(),
                      onChanged: (ReportKind? val) {
                        if (val != null) setModalState(() => selectedKind = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Instructions for Caregiver', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: noteCtrl,
                      maxLines: 3,
                      style: CT.bodySmall,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'An instant request notification will be sent to caregiver Priya to upload this document.',
                      style: CT.caption.sized(11).tint(AppColors.clinicInkSoft),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clinicAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request for ${selectedKind.label} sent to caregiver Priya'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  label: const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<MedicalReport> filtered = _selectedKind == null
        ? _reports
        : _reports.where((MedicalReport r) => r.kind == _selectedKind).toList();

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.doctorReportsTitle, style: CT.h3.wght(700)),
            Text('${widget.patientName} · ${_reports.length} reports', style: CT.caption),
          ],
        ),
        backgroundColor: AppColors.clinicSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.clinicInk),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clinicAccent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: Text('Request Report', style: CT.caption.wght(700).tint(Colors.white)),
              onPressed: _showRequestReportDialog,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // ── Filter Chips ──────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 8),
            child: Row(
              children: <Widget>[
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedKind == null,
                  onSelected: (bool s) => setState(() => _selectedKind = null),
                ),
                const SizedBox(width: 8),
                for (final ReportKind kind in ReportKind.values) ...<Widget>[
                  FilterChip(
                    label: Text(kind.label),
                    selected: _selectedKind == kind,
                    onSelected: (bool s) => setState(() => _selectedKind = s ? kind : null),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Report Cards List ─────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.gutter),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final MedicalReport report = filtered[index];
                return _ReportCard(
                  report: report,
                  patientName: widget.patientName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.patientName,
  });

  final MedicalReport report;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      accentEdge: report.kind.color,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReportViewerScreen(
              report: report,
              patientName: patientName,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: report.kind.color.withValues(alpha: 0.12),
                  borderRadius: Corners.r(8),
                ),
                child: Icon(report.kind.icon, size: 20, color: report.kind.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(report.kind.label, style: CT.body.wght(700)),
                    const SizedBox(height: 2),
                    Text(
                      '${report.dateLabel} · ${report.doctorName}',
                      style: CT.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.clinicHairline.withValues(alpha: 0.4),
                  borderRadius: Corners.r(6),
                ),
                child: Text(
                  'Original Doc',
                  style: CT.caption.wght(600).tint(AppColors.clinicInkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (report.fileName.isNotEmpty)
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.clinicInkSoft),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.fileName,
                          style: CT.caption.wght(600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.clinicInk,
                  side: const BorderSide(color: AppColors.clinicHairline),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: Text('View Report', style: CT.caption.wght(700)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportViewerScreen(
                        report: report,
                        patientName: patientName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
