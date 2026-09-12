/// Models for Telehealth Video Consultations, AI Clinical Notes, and Chat.

enum CallState {
  idle,
  initiating,
  ringing,
  connected,
  ended,
}

class ClinicalSoapNote {
  const ClinicalSoapNote({
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    this.prescriptions = const <String>[],
    this.suggestedExercises = const <String>[],
  });

  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final List<String> prescriptions;
  final List<String> suggestedExercises;

  factory ClinicalSoapNote.fromJson(Map<String, dynamic> json) {
    return ClinicalSoapNote(
      subjective: json['subjective'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      assessment: json['assessment'] as String? ?? '',
      plan: json['plan'] as String? ?? '',
      prescriptions: (json['prescriptions'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      suggestedExercises: (json['suggested_exercises'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'subjective': subjective,
        'objective': objective,
        'assessment': assessment,
        'plan': plan,
        'prescriptions': prescriptions,
        'suggested_exercises': suggestedExercises,
      };
}

class PatientMitraSummary {
  const PatientMitraSummary({
    required this.title,
    this.keyTakeaways = const <String>[],
    this.medicationReminders = const <String>[],
    this.dailyRoutineAdvice = '',
    this.nextCheckup = 'In 2 weeks',
  });

  final String title;
  final List<String> keyTakeaways;
  final List<String> medicationReminders;
  final String dailyRoutineAdvice;
  final String nextCheckup;

  factory PatientMitraSummary.fromJson(Map<String, dynamic> json) {
    return PatientMitraSummary(
      title: json['title'] as String? ?? 'Doctor Consultation Summary',
      keyTakeaways: (json['key_takeaways'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      medicationReminders: (json['medication_reminders'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      dailyRoutineAdvice: json['daily_routine_advice'] as String? ?? '',
      nextCheckup: json['next_checkup'] as String? ?? 'In 2 weeks',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'key_takeaways': keyTakeaways,
        'medication_reminders': medicationReminders,
        'daily_routine_advice': dailyRoutineAdvice,
        'next_checkup': nextCheckup,
      };
}

class ConsultationSession {
  const ConsultationSession({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.roomName,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.transcript,
    this.soapNote,
    this.patientSummary,
    this.doctorApproved = false,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String roomName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String? transcript;
  final ClinicalSoapNote? soapNote;
  final PatientMitraSummary? patientSummary;
  final bool doctorApproved;

  factory ConsultationSession.fromJson(Map<String, dynamic> json) {
    return ConsultationSession(
      id: json['id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      roomName: json['room_name'] as String? ?? '',
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'] as String) : null,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      transcript: json['transcript'] as String?,
      soapNote: json['soap_note'] != null
          ? ClinicalSoapNote.fromJson(json['soap_note'] as Map<String, dynamic>)
          : null,
      patientSummary: json['patient_summary'] != null
          ? PatientMitraSummary.fromJson(json['patient_summary'] as Map<String, dynamic>)
          : null,
      doctorApproved: json['doctor_approved'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String senderId;
  final String senderRole; // "doctor" | "patient"
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderRole: json['sender_role'] as String? ?? 'doctor',
      senderName: json['sender_name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'doctor_id': doctorId,
        'patient_id': patientId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'sender_name': senderName,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'is_read': isRead,
      };
}
