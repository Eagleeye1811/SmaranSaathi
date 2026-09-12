import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';

/// Care Plan screen where the doctor can view, edit, and share care plans with caregivers.
/// Streamlined UI focused on essential clinical recommendations, activities, instructions, and follow-up.
class CarePlanScreen extends StatefulWidget {
  const CarePlanScreen({
    super.key,
    this.patientName = 'Aama Devi',
    this.patientId = 'p_aama',
  });

  final String patientName;
  final String patientId;

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  late CarePlanEntry _plan;
  late final TextEditingController _instructionsController;
  late final TextEditingController _followUpController;
  late List<String> _recommendations;
  late List<String> _activities;
  bool _isEditing = false;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    _plan = MockData.careplan();
    _recommendations = <String>[
      '15-min morning sunlight walk daily',
      'Limit evening screen time to under 30 minutes',
      'Maintain 7–8 hours regular sleep schedule',
      'Consistent meal timings to support circadian rhythm',
      'Daily family social conversation in the evening',
    ];
    _activities = <String>[
      'SmaranSaathi cognitive games 2x daily (morning & afternoon)',
      'Crossword or word recall puzzle daily',
      'Guided breathing or chair yoga 3x weekly',
      'Mood canvas drawing for emotional expression',
    ];
    _instructionsController = TextEditingController(
      text: _plan.instructions.isNotEmpty
          ? _plan.instructions
          : 'Provide gentle verbal prompts without rushing. Keep medication schedule strictly on time with meals.',
    );
    _followUpController = TextEditingController(text: _plan.followUpLabel);
    _shared = _plan.sharedWithCaregiver;
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  void _saveCarePlan() {
    setState(() {
      _plan = CarePlanEntry(
        patientId: widget.patientId,
        updatedLabel: 'Today',
        recommendations: _recommendations,
        activities: _activities,
        instructions: _instructionsController.text,
        followUpLabel: _followUpController.text,
        sharedWithCaregiver: _shared,
      );
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Care plan updated successfully'), duration: Duration(seconds: 2)),
    );
  }

  void _shareWithCaregiver() {
    setState(() => _shared = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Care plan shared with caregiver (Priya)'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _addItemDialog(String title, ValueChanged<String> onAdd) {
    final TextEditingController textCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.clinicSurface,
          title: Text(title, style: CT.h3.wght(700)),
          content: TextField(
            controller: textCtrl,
            style: CT.bodySmall,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter item…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clinicAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (textCtrl.text.trim().isNotEmpty) {
                  onAdd(textCtrl.text.trim());
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.doctorCarePlanTitle, style: CT.h3.wght(700)),
            Text('${widget.patientName} · Updated ${_plan.updatedLabel}', style: CT.caption),
          ],
        ),
        backgroundColor: AppColors.clinicSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.clinicInk),
        actions: <Widget>[
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.clinicAccent),
              tooltip: l.doctorCarePlanEdit,
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.success),
              tooltip: l.doctorCarePlanSave,
              onPressed: _saveCarePlan,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Clean Share Status Strip ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _shared
                    ? AppColors.success.withValues(alpha: 0.08)
                    : const Color(0xFFE0913A).withValues(alpha: 0.08),
                borderRadius: Corners.r(10),
                border: Border.all(
                  color: _shared
                      ? AppColors.success.withValues(alpha: 0.25)
                      : const Color(0xFFE0913A).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _shared ? Icons.check_circle_rounded : Icons.pending_outlined,
                    size: 18,
                    color: _shared ? AppColors.success : const Color(0xFFE0913A),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _shared ? 'Shared with Caregiver Priya' : 'Draft · Not yet shared with caregiver',
                      style: CT.caption.wght(700).tint(_shared ? AppColors.success : const Color(0xFFE0913A)),
                    ),
                  ),
                  if (!_shared)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.clinicAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        elevation: 0,
                      ),
                      onPressed: _shareWithCaregiver,
                      child: Text('Share Now', style: CT.caption.wght(700).tint(Colors.white)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Section 1: Clinical Recommendations ──────────────
            _CareSectionCard(
              title: l.doctorCarePlanRecommendations,
              icon: Icons.lightbulb_outline_rounded,
              iconColor: const Color(0xFF2F7FB8),
              isEditing: _isEditing,
              onAdd: () => _addItemDialog('Add Recommendation', (String v) {
                setState(() => _recommendations.add(v));
              }),
              items: _recommendations,
              onRemove: (int idx) => setState(() => _recommendations.removeAt(idx)),
            ),
            const SizedBox(height: 12),

            // ── Section 2: Prescribed Activities ─────────────────
            _CareSectionCard(
              title: l.doctorCarePlanActivities,
              icon: Icons.fitness_center_rounded,
              iconColor: const Color(0xFF3E9268),
              isEditing: _isEditing,
              onAdd: () => _addItemDialog('Add Prescribed Activity', (String v) {
                setState(() => _activities.add(v));
              }),
              items: _activities,
              onRemove: (int idx) => setState(() => _activities.removeAt(idx)),
            ),
            const SizedBox(height: 12),

            // ── Section 3: Caregiver Guidance ────────────────────
            ClinicCard(
              accentEdge: const Color(0xFF7A5680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.record_voice_over_outlined, size: 18, color: Color(0xFF7A5680)),
                      const SizedBox(width: 8),
                      Text(l.doctorCarePlanInstructions, style: CT.body.wght(700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      controller: _instructionsController,
                      maxLines: 3,
                      style: CT.bodySmall,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.clinicHairline.withValues(alpha: 0.25),
                        borderRadius: Corners.r(8),
                      ),
                      child: Text(
                        _instructionsController.text,
                        style: CT.bodySmall.copyWith(height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Section 4: Follow-up Date ────────────────────────
            ClinicCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.clinicAccent.withValues(alpha: 0.1),
                      borderRadius: Corners.r(8),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.clinicAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.doctorCarePlanFollowUp, style: CT.caption.wght(600)),
                        const SizedBox(height: 2),
                        if (_isEditing)
                          TextField(
                            controller: _followUpController,
                            style: CT.body.wght(700),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: UnderlineInputBorder(),
                            ),
                          )
                        else
                          Text(_followUpController.text, style: CT.body.wght(800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Save / Share CTAs
            if (_isEditing)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clinicAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(l.doctorCarePlanSave, style: CT.body.wght(700).tint(Colors.white)),
                onPressed: _saveCarePlan,
              )
            else if (!_shared)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.clinicAccent,
                  side: const BorderSide(color: AppColors.clinicAccent),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text('Share with Caregiver', style: CT.body.wght(700).tint(AppColors.clinicAccent)),
                onPressed: _shareWithCaregiver,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CareSectionCard extends StatelessWidget {
  const _CareSectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.isEditing,
    required this.onAdd,
    required this.items,
    required this.onRemove,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final bool isEditing;
  final VoidCallback onAdd;
  final List<String> items;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      accentEdge: iconColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: CT.body.wght(700))),
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.clinicAccent),
                  onPressed: onAdd,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 14, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(items[i], style: CT.bodySmall)),
                  if (isEditing)
                    GestureDetector(
                      onTap: () => onRemove(i),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
