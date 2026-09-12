import 'package:flutter/material.dart';

/// Connection status of a doctor invitation.
enum InvitationStatus { notSent, sent, pending, connected }

extension InvitationStatusX on InvitationStatus {
  String get label => switch (this) {
        InvitationStatus.notSent => 'Not sent',
        InvitationStatus.sent => 'Invitation sent',
        InvitationStatus.pending => 'Pending',
        InvitationStatus.connected => 'Connected',
      };

  Color get color => switch (this) {
        InvitationStatus.notSent => const Color(0xFF8C8377),
        InvitationStatus.sent => const Color(0xFFE0913A),
        InvitationStatus.pending => const Color(0xFFD9962B),
        InvitationStatus.connected => const Color(0xFF3E9268),
      };

  IconData get icon => switch (this) {
        InvitationStatus.notSent => Icons.person_add_outlined,
        InvitationStatus.sent => Icons.send_outlined,
        InvitationStatus.pending => Icons.hourglass_empty_rounded,
        InvitationStatus.connected => Icons.verified_rounded,
      };
}

/// A doctor connected to the patient's care profile.
@immutable
class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.name,
    required this.specialization,
    required this.hospital,
    required this.email,
    this.phone = '',
    this.avatarInitials = '',
    this.status = InvitationStatus.connected,
    this.registrationNumber = '',
  });

  final String id;
  final String name;
  final String specialization;
  final String hospital;
  final String email;
  final String phone;
  final String avatarInitials;
  final InvitationStatus status;
  final String registrationNumber;

  String get displayName => 'Dr. $name';
}

/// Status of a booked appointment.
enum AppointmentStatus { upcoming, completed, cancelled, rescheduled }

extension AppointmentStatusX on AppointmentStatus {
  String get label => switch (this) {
        AppointmentStatus.upcoming => 'Upcoming',
        AppointmentStatus.completed => 'Completed',
        AppointmentStatus.cancelled => 'Cancelled',
        AppointmentStatus.rescheduled => 'Rescheduled',
      };

  Color get color => switch (this) {
        AppointmentStatus.upcoming => const Color(0xFF2F7FB8),
        AppointmentStatus.completed => const Color(0xFF3E9268),
        AppointmentStatus.cancelled => const Color(0xFF8C8377),
        AppointmentStatus.rescheduled => const Color(0xFFE0913A),
      };
}

/// A single doctor appointment.
@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.dateLabel,
    required this.timeLabel,
    required this.status,
    this.isVirtual = false,
    this.joinLink = '',
    this.summary,
  });

  final String id;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final String dateLabel;
  final String timeLabel;
  final AppointmentStatus status;
  final bool isVirtual;
  final String joinLink;
  final ConsultationSummary? summary;
}

/// Notes and care plan from the doctor after a completed consultation.
@immutable
class ConsultationSummary {
  const ConsultationSummary({
    required this.appointmentId,
    required this.dateLabel,
    required this.observations,
    required this.careplan,
    required this.recommendedActivities,
    required this.followUpLabel,
    this.doctorNotes = '',
  });

  final String appointmentId;
  final String dateLabel;
  final List<String> observations;
  final String careplan;
  final List<String> recommendedActivities;
  final String followUpLabel;
  final String doctorNotes;
}

// ── Doctor-side appointment (from doctor perspective) ─────────────────────

/// An appointment on the doctor's schedule.
@immutable
class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.dateLabel,
    required this.timeLabel,
    required this.status,
    this.isVirtual = false,
    this.doctorNotes = '',
  });

  final String id;
  final String patientId;
  final String patientName;
  final int patientAge;
  final String dateLabel;
  final String timeLabel;
  final AppointmentStatus status;
  final bool isVirtual;
  final String doctorNotes;
}

/// A time slot the doctor has made available for booking.
@immutable
class DoctorSlot {
  const DoctorSlot({
    required this.id,
    required this.dayLabel,
    required this.timeLabel,
    this.isBooked = false,
    this.bookedByPatient = '',
  });

  final String id;
  final String dayLabel;
  final String timeLabel;
  final bool isBooked;
  final String bookedByPatient;
}

/// An incoming connection request from a patient/caregiver.
@immutable
class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.patientName,
    required this.patientAge,
    required this.district,
    required this.requestedByLabel,
    required this.timeAgo,
  });

  final String id;
  final String patientName;
  final int patientAge;
  final String district;
  final String requestedByLabel;
  final String timeAgo;
}

/// Doctor-authored care plan for a patient.
@immutable
class CarePlanEntry {
  const CarePlanEntry({
    required this.patientId,
    required this.updatedLabel,
    required this.recommendations,
    required this.activities,
    required this.instructions,
    required this.followUpLabel,
    this.sharedWithCaregiver = false,
  });

  final String patientId;
  final String updatedLabel;
  final List<String> recommendations;
  final List<String> activities;
  final String instructions;
  final String followUpLabel;
  final bool sharedWithCaregiver;
}
