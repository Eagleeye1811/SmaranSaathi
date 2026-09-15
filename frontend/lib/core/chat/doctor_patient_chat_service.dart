import 'dart:convert';
import '../backend_base_url.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/telehealth.dart';

/// Persistent 1-on-1 Chat Service between Doctor and Patient/Caregiver.
class DoctorPatientChatService extends ChangeNotifier {
  DoctorPatientChatService({
    http.Client? client,
    String? baseUrl,
    required this.doctorId,
    required this.patientId,
    required this.currentUserRole,
    required this.currentUserName,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? backendBaseUrl;

  final http.Client _client;
  final String baseUrl;
  final String doctorId;
  final String patientId;
  final String currentUserRole; // 'doctor' | 'patient'
  final String currentUserName;

  List<ChatMessage> messages = <ChatMessage>[];
  bool isLoading = false;

  /// Load persistent chat history.
  Future<void> loadMessages() async {
    isLoading = true;
    notifyListeners();

    try {
      final Uri uri = Uri.parse('$baseUrl/api/v1/chat/$doctorId/$patientId/messages');
      final http.Response res = await _client.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
        messages = list
            .map((dynamic m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ChatService] loadMessages notice: $e');
      if (messages.isEmpty) {
        // Mock fallback messages for preview
        messages = <ChatMessage>[
          ChatMessage(
            id: 'msg_1',
            doctorId: doctorId,
            patientId: patientId,
            senderId: doctorId,
            senderRole: 'doctor',
            senderName: 'Dr. Sharma',
            content: 'Namaste! How has the patient been feeling since the last consultation?',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: true,
          ),
          ChatMessage(
            id: 'msg_2',
            doctorId: doctorId,
            patientId: patientId,
            senderId: patientId,
            senderRole: 'patient',
            senderName: 'Caregiver',
            content: 'Namaste Doctor. Father completed his morning memory games on Mitra with 85% accuracy.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
            isRead: true,
          ),
        ];
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Send a persistent message.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final ChatMessage optimistic = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      patientId: patientId,
      senderId: currentUserRole == 'doctor' ? doctorId : patientId,
      senderRole: currentUserRole,
      senderName: currentUserName,
      content: text.trim(),
      timestamp: DateTime.now(),
      isRead: true,
    );

    messages.add(optimistic);
    notifyListeners();

    try {
      final Uri uri = Uri.parse('$baseUrl/api/v1/chat/messages');
      await _client.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'doctor_id': doctorId,
          'patient_id': patientId,
          'sender_id': currentUserRole == 'doctor' ? doctorId : patientId,
          'sender_role': currentUserRole,
          'sender_name': currentUserName,
          'content': text.trim(),
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[ChatService] sendMessage notice: $e');
    }
  }
}
