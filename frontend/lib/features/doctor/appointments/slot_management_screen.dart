import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../core/services/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';

/// Screen allowing the doctor to set and manage their weekly consultation availability slots.
class SlotManagementScreen extends StatefulWidget {
  const SlotManagementScreen({super.key});

  @override
  State<SlotManagementScreen> createState() => _SlotManagementScreenState();
}

class _SlotManagementScreenState extends State<SlotManagementScreen> {
  void _addSlotDialog(AppState state) {
    String selectedDay = state.doctorActiveDays.isNotEmpty ? state.doctorActiveDays.first : 'Monday';
    String startTime = '10:00 AM';
    String endTime = '11:00 AM';
    final List<String> days = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.clinicSurface,
              title: Text('Add Availability Slot', style: CT.h3.wght(700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Day of week', style: CT.caption.wght(600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: days
                        .map((String d) => DropdownMenuItem<String>(value: d, child: Text(d, style: CT.bodySmall)))
                        .toList(),
                    onChanged: (String? val) {
                      if (val != null) setModalState(() => selectedDay = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Start time', style: CT.caption.wght(600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: startTime,
                              style: CT.bodySmall,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (String v) => startTime = v,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('End time', style: CT.caption.wght(600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: endTime,
                              style: CT.bodySmall,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (String v) => endTime = v,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: CT.bodySmall),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clinicAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    state.addDoctorSlot(
                      DoctorSlot(
                        id: 'sl_${DateTime.now().millisecondsSinceEpoch}',
                        dayLabel: selectedDay,
                        timeLabel: '$startTime – $endTime',
                      ),
                    );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Availability slot added and synced with caregivers'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Add Slot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeSlot(AppState state, String id) {
    state.removeDoctorSlot(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Slot removed'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DoctorSlot> slots = state.doctorSlots;

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      appBar: AppBar(
        title: Text(l.doctorSlotsTitle, style: CT.h3.wght(700)),
        backgroundColor: AppColors.clinicSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.clinicInk),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.clinicAccent),
            tooltip: l.doctorSlotsAddSlot,
            onPressed: () => _addSlotDialog(state),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.gutter),
        children: <Widget>[
          ClinicCard(
            accentEdge: AppColors.clinicAccent,
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.clinicAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Slots set here are immediately visible to connected caregivers for booking consultations.',
                    style: CT.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(l.doctorSlotsSubtitle, style: CT.h3.wght(700)),
              Text('${slots.length} slots', style: CT.caption.wght(600)),
            ],
          ),
          const SizedBox(height: 10),
          for (final DoctorSlot slot in slots) ...<Widget>[
            ClinicCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: slot.isBooked
                          ? const Color(0xFFE0913A).withValues(alpha: 0.12)
                          : AppColors.success.withValues(alpha: 0.12),
                      borderRadius: Corners.r(8),
                    ),
                    child: Icon(
                      slot.isBooked ? Icons.event_busy_rounded : Icons.event_available_rounded,
                      size: 18,
                      color: slot.isBooked ? const Color(0xFFE0913A) : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${slot.dayLabel} · ${slot.timeLabel}',
                          style: CT.body.wght(700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slot.isBooked
                              ? l.doctorSlotsBooked(slot.bookedByPatient)
                              : l.doctorSlotsAvailable,
                          style: CT.caption.tint(
                            slot.isBooked ? const Color(0xFFE0913A) : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!slot.isBooked)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.clinicInkSoft),
                      tooltip: l.doctorSlotsRemove,
                      onPressed: () => _removeSlot(state, slot.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.clinicAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.doctorSlotsAddSlot, style: AppText.bodySmall.wght(700).tint(Colors.white)),
        onPressed: () => _addSlotDialog(state),
      ),
    );
  }
}
