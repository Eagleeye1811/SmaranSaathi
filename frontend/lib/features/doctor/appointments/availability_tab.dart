import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/models/doctor.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../widgets/clinic_widgets.dart';

/// Interactive section allowing the doctor to select their active availability days
/// and configure appointment slots for patients/caregivers to book.
class DoctorAvailabilityTab extends StatefulWidget {
  const DoctorAvailabilityTab({super.key});

  @override
  State<DoctorAvailabilityTab> createState() => DoctorAvailabilityTabState();
}

class DoctorAvailabilityTabState extends State<DoctorAvailabilityTab> {
  static const List<String> _allDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _filterDay = 'All';

  void _showAddSlotDialog(BuildContext context, AppState state) {
    String selectedDay = state.doctorActiveDays.isNotEmpty
        ? state.doctorActiveDays.first
        : 'Monday';
    String startTime = '10:00 AM';
    String endTime = '11:00 AM';

    final List<String> presets = <String>[
      '9:00 AM – 10:00 AM',
      '10:00 AM – 11:00 AM',
      '11:00 AM – 12:00 PM',
      '2:00 PM – 3:00 PM',
      '3:00 PM – 4:00 PM',
      '4:00 PM – 5:00 PM',
    ];
    String selectedPreset = presets.first;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogCtx, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.clinicSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Add Appointment Slot', style: CT.h3.wght(700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Select Day', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _allDays
                          .map((String d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d, style: CT.bodySmall),
                              ))
                          .toList(),
                      onChanged: (String? val) {
                        if (val != null) setModalState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Quick Preset Time', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedPreset,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: presets
                          .map((String p) => DropdownMenuItem<String>(
                                value: p,
                                child: Text(p, style: CT.bodySmall),
                              ))
                          .toList(),
                      onChanged: (String? val) {
                        if (val != null) {
                          setModalState(() {
                            selectedPreset = val;
                            final List<String> parts = val.split(' – ');
                            if (parts.length == 2) {
                              startTime = parts[0];
                              endTime = parts[1];
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Or Custom Time Range', style: CT.caption.wght(600)),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            initialValue: startTime,
                            style: CT.bodySmall,
                            decoration: InputDecoration(
                              labelText: 'Start',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (String v) => startTime = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: endTime,
                            style: CT.bodySmall,
                            decoration: InputDecoration(
                              labelText: 'End',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (String v) => endTime = v,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: CT.bodySmall),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clinicAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final String timeLabel = '$startTime – $endTime';
                    state.addDoctorSlot(
                      DoctorSlot(
                        id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
                        dayLabel: selectedDay,
                        timeLabel: timeLabel,
                      ),
                    );
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Slot added for $selectedDay ($timeLabel). Available to caregivers.'),
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

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Set<String> activeDays = state.doctorActiveDays;
    final List<DoctorSlot> slots = state.doctorSlots;
    final List<DoctorSlot> filteredSlots = _filterDay == 'All'
        ? slots
        : slots.where((DoctorSlot s) => s.dayLabel.toLowerCase() == _filterDay.toLowerCase()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.event_available_rounded, size: 20, color: AppColors.clinicAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Consultation Days', style: CT.h3.wght(700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allDays.map((String day) {
            final bool isSelected = activeDays.contains(day);
            return FilterChip(
              label: Text(day.substring(0, 3)),
              selected: isSelected,
              showCheckmark: isSelected,
              selectedColor: AppColors.clinicAccent.withValues(alpha: 0.18),
              checkmarkColor: AppColors.clinicAccent,
              labelStyle: CT.bodySmall.wght(isSelected ? 700 : 500).tint(
                    isSelected ? AppColors.clinicAccent : AppColors.clinicInkSoft,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.clinicAccent : AppColors.clinicHairline,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              onSelected: (_) => state.toggleDoctorDay(day),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.clinicHairline),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Slots (${slots.length})', style: CT.body.wght(700)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clinicAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showAddSlotDialog(context, state),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Day filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <String>['All', ..._allDays].map((String d) {
              final bool isSel = _filterDay == d;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(d == 'All' ? 'All' : d.substring(0, 3)),
                  selected: isSel,
                  visualDensity: VisualDensity.compact,
                  labelStyle: CT.caption.wght(isSel ? 700 : 500).tint(
                        isSel ? AppColors.clinicAccent : AppColors.clinicInkSoft,
                      ),
                  selectedColor: AppColors.clinicAccent.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: isSel ? AppColors.clinicAccent : AppColors.clinicHairline,
                    ),
                  ),
                  onSelected: (bool sel) {
                    if (sel) setState(() => _filterDay = d);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        if (filteredSlots.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.clinicBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No slots.',
              style: CT.caption,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final DoctorSlot slot in filteredSlots) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: slot.isBooked ? AppColors.clinicHairline : AppColors.clinicAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.clinicAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      slot.dayLabel.substring(0, 3).toUpperCase(),
                      style: CT.caption.wght(800).tint(AppColors.clinicAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(slot.timeLabel, style: CT.bodySmall.wght(700)),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PillTag(
                            label: slot.isBooked ? 'Booked' : 'Available',
                            color: slot.isBooked ? const Color(0xFF2F7FB8) : AppColors.success,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.clinicInkSoft),
                    onPressed: () {
                      state.removeDoctorSlot(slot.id);
                    },
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}
