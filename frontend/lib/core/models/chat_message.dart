import 'package:flutter/material.dart';

/// Delivery status for a chat message.
enum MessageStatus { sending, sent, delivered, read }

/// A single message in a clinical doctor-patient/caregiver chat.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.timestamp,
    required this.isFromDoctor,
    this.status = MessageStatus.read,
    this.attachmentType,
    this.attachmentTitle,
    this.attachmentSubtitle,
  });

  final String id;
  final String conversationId; // Typically the patientId
  final String text;
  final DateTime timestamp;
  final bool isFromDoctor;
  final MessageStatus status;

  /// Optional attachment: 'care_plan', 'report_request', 'prescription', etc.
  final String? attachmentType;
  final String? attachmentTitle;
  final String? attachmentSubtitle;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? text,
    DateTime? timestamp,
    bool? isFromDoctor,
    MessageStatus? status,
    String? attachmentType,
    String? attachmentTitle,
    String? attachmentSubtitle,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFromDoctor: isFromDoctor ?? this.isFromDoctor,
      status: status ?? this.status,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentTitle: attachmentTitle ?? this.attachmentTitle,
      attachmentSubtitle: attachmentSubtitle ?? this.attachmentSubtitle,
    );
  }
}

/// A conversation thread between the doctor and a connected patient/caregiver.
@immutable
class DoctorConversation {
  const DoctorConversation({
    required this.patientId,
    required this.patientName,
    required this.caregiverName,
    required this.patientAge,
    required this.district,
    required this.sceneId,
    required this.messages,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastSeen = 'today at 10:45 AM',
    this.isAttention = false,
  });

  final String patientId;
  final String patientName;
  final String caregiverName;
  final int patientAge;
  final String district;
  final String sceneId;
  final List<ChatMessage> messages;
  final int unreadCount;
  final bool isOnline;
  final String lastSeen;
  final bool isAttention;

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  DoctorConversation copyWith({
    String? patientId,
    String? patientName,
    String? caregiverName,
    int? patientAge,
    String? district,
    String? sceneId,
    List<ChatMessage>? messages,
    int? unreadCount,
    bool? isOnline,
    String? lastSeen,
    bool? isAttention,
  }) {
    return DoctorConversation(
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      caregiverName: caregiverName ?? this.caregiverName,
      patientAge: patientAge ?? this.patientAge,
      district: district ?? this.district,
      sceneId: sceneId ?? this.sceneId,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isAttention: isAttention ?? this.isAttention,
    );
  }
}
