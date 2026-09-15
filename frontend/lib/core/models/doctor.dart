import 'package:flutter/material.dart';

/// Connection status of a doctor invitation.
enum InvitationStatus { notSent, sent, pending, connected }

extension InvitationStatusX on InvitationStatus {
  /// Said plainly, from the caregiver's side of it.
  ///
  /// "Invitation sent" and "Pending" described the same situation in two
  /// different words — the caregiver has written to a doctor and is waiting —
  /// and nobody could tell which was which, least of all when they were two
  /// shades of the same orange. Both now say what is actually happening:
  /// you are waiting to hear back.
  String get label => switch (this) {
        InvitationStatus.notSent => 'Not invited',
        InvitationStatus.sent || InvitationStatus.pending => 'Waiting for reply',
        InvitationStatus.connected => 'Connected',
      };

  Color get color => switch (this) {
        // Deliberately far apart: grey for nothing done, a strong amber for
        // waiting, green for connected. The old amber pair differed by 7 in
        // one channel, which on a tinted pill is no difference at all.
        InvitationStatus.notSent => const Color(0xFF6E675E),
        InvitationStatus.sent || InvitationStatus.pending => const Color(0xFFB4690E),
        InvitationStatus.connected => const Color(0xFF2F7350),
      };

  IconData get icon => switch (this) {
        InvitationStatus.notSent => Icons.person_add_outlined,
        InvitationStatus.sent || InvitationStatus.pending => Icons.hourglass_bottom_rounded,
        InvitationStatus.connected => Icons.verified_rounded,
      };

  /// True while the caregiver is waiting on the doctor.
  bool get isWaiting =>
      this == InvitationStatus.sent || this == InvitationStatus.pending;
}

/// A doctor connected to the patient's care profile.
@immutable
/// A doctor's name with exactly one "Dr." on the front.
///
/// The title used to be prefixed unconditionally, while the name being
/// prefixed had usually been written with the title already — the seeded
/// clinicians all read "Dr. Neha Sharma", and a real doctor typing their own
/// name on the sign-up form naturally writes "Dr." too. Both produced
/// "Dr. Dr. Neha Sharma" in the directory. Prefixing only when the title is
/// absent means neither the data nor the person has to know which half is
/// responsible for it.
String withDoctorTitle(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  final String lower = trimmed.toLowerCase();
  // 'Dr Sharma', 'Dr. Sharma' and 'Doctor Sharma' are already titled;
  // 'Drishti' is not, which is why each check carries its own separator.
  for (final String title in <String>['dr.', 'dr ', 'doctor ', 'prof.', 'prof ']) {
    if (lower.startsWith(title)) return trimmed;
  }
  return 'Dr. $trimmed';
}

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

  String get displayName => withDoctorTitle(name);

  /// Round-trips through `AppState`'s settings so a clinician who signs up
  /// on this device is still in the directory after a restart.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'specialization': specialization,
        'hospital': hospital,
        'email': email,
        'phone': phone,
        'avatarInitials': avatarInitials,
        'status': status.name,
        'registrationNumber': registrationNumber,
      };

  static DoctorProfile? fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? name = json['name'];
    if (id is! String || name is! String || id.isEmpty) return null;
    return DoctorProfile(
      id: id,
      name: name,
      specialization: (json['specialization'] as String?) ?? '',
      hospital: (json['hospital'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      avatarInitials: (json['avatarInitials'] as String?) ?? '',
      status: InvitationStatus.values.firstWhere(
        (InvitationStatus s) => s.name == json['status'],
        orElse: () => InvitationStatus.notSent,
      ),
      registrationNumber: (json['registrationNumber'] as String?) ?? '',
    );
  }

  DoctorProfile copyWith({
    InvitationStatus? status,
    String? name,
    String? specialization,
    String? hospital,
    String? phone,
    String? registrationNumber,
  }) =>
      DoctorProfile(
        id: id,
        name: name ?? this.name,
        specialization: specialization ?? this.specialization,
        hospital: hospital ?? this.hospital,
        email: email,
        phone: phone ?? this.phone,
        avatarInitials: avatarInitials,
        status: status ?? this.status,
        registrationNumber: registrationNumber ?? this.registrationNumber,
      );
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
    this.doctorId = '',
  });

  final String id;
  final String patientName;
  final int patientAge;
  final String district;
  final String requestedByLabel;
  final String timeAgo;

  /// Which doctor was invited. Empty for the sample requests that come with
  /// the demo caseload; set for one a caregiver actually sent, so accepting
  /// it connects the right person rather than a guess.
  final String doctorId;
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
