import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/doctor.dart';
import '../../../core/services/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';
import 'availability_tab.dart';
import 'appointment_detail_screen.dart';

/// Appointments tab in Doctor module.
/// Allows viewing upcoming/past consultations, setting availability slots,
/// and launching consultation details with AI pre-consult summaries.
class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DoctorAppointment> all = state.doctorAppointments;
    final List<DoctorAppointment> upcoming =
        all.where((DoctorAppointment a) => a.status == AppointmentStatus.upcoming).toList();
    final List<DoctorAppointment> past =
        all.where((DoctorAppointment a) => a.status == AppointmentStatus.completed).toList();

    return Scaffold(
      backgroundColor: AppColors.clinicBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ClinicTopBar(
              title: l.doctorApptTitle,
              subtitle: l.doctorApptSubtitle(upcoming.length),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.clinicHairline.withValues(alpha: 0.3),
                  borderRadius: Corners.r(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.clinicSurface,
                    borderRadius: Corners.r(8),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: AppColors.clinicInk,
                  unselectedLabelColor: AppColors.clinicInkSoft,
                  labelStyle: CT.bodySmall.wght(700),
                  unselectedLabelStyle: CT.bodySmall,
                  tabs: <Widget>[
                    Tab(text: '${l.doctorApptUpcoming} (${upcoming.length})'),
                    Tab(text: '${l.doctorApptPast} (${past.length})'),
                    // When a clinician is free is part of their appointments,
                    // not part of who they are — it used to live on the
                    // profile page, two taps away from the bookings it
                    // governs.
                    const Tab(text: 'Availability'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _AppointmentList(
                    appointments: upcoming,
                    isUpcoming: true,
                    emptyTitle: l.doctorApptEmptyUpcoming,
                    emptyMessage: l.doctorApptEmptyUpcomingMsg,
                  ),
                  _AppointmentList(
                    appointments: past,
                    isUpcoming: false,
                    emptyTitle: l.doctorApptEmptyPast,
                    emptyMessage: '',
                  ),
                  const SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        Insets.gutter, Insets.sm, Insets.gutter, Insets.xl),
                    child: ClinicCard(
                      padding: EdgeInsets.all(Insets.lg),
                      child: DoctorAvailabilityTab(),
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

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.isUpcoming,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<DoctorAppointment> appointments;
  final bool isUpcoming;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.event_available_rounded, size: 48, color: AppColors.clinicInkSoft.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(emptyTitle, style: CT.h3.wght(700)),
              if (emptyMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(emptyMessage, style: CT.bodySmall, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, Insets.gutter * 2),
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final DoctorAppointment appt = appointments[index];
        return _AppointmentCard(appointment: appt, isUpcoming: isUpcoming);
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isUpcoming,
  });

  final DoctorAppointment appointment;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color badgeColor = appointment.isVirtual ? const Color(0xFF2F7FB8) : const Color(0xFF3E9268);

    return ClinicCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppointmentDetailScreen(appointment: appointment),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: Corners.r(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      appointment.isVirtual ? Icons.videocam_rounded : Icons.location_on_rounded,
                      size: 13,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.isVirtual ? l.doctorApptVirtual : l.doctorApptInPerson,
                      style: CT.caption.wght(700).tint(badgeColor),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.clinicInkSoft),
                  const SizedBox(width: 4),
                  Text(
                    '${appointment.dateLabel} · ${appointment.timeLabel}',
                    style: CT.caption.wght(600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.1),
                child: Text(
                  appointment.patientName.isNotEmpty ? appointment.patientName[0] : 'P',
                  style: CT.body.wght(700).tint(AppColors.clinicAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(appointment.patientName, style: CT.body.wght(700)),
                    Text(
                      '${appointment.patientAge} yrs · ID: ${appointment.patientId}',
                      style: CT.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.clinicInkSoft),
            ],
          ),
          if (appointment.doctorNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.clinicHairline.withValues(alpha: 0.3),
                borderRadius: Corners.r(6),
              ),
              child: Text(
                appointment.doctorNotes,
                style: CT.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
