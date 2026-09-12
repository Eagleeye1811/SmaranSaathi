import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/chat/doctor_patient_chat_service.dart';
import '../../../core/models/telehealth.dart';
import '../doctor/widgets/clinic_widgets.dart';
import '../telehealth/video_consultation_screen.dart';

/// Persistent 1-on-1 Messaging Screen between Doctor and Patient/Caregiver.
class DoctorPatientChatScreen extends StatefulWidget {
  const DoctorPatientChatScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    this.doctorName = 'Dr. Sharma',
    this.isDoctor = true,
  });

  final String doctorId;
  final String patientId;
  final String patientName;
  final String doctorName;
  final bool isDoctor;

  @override
  State<DoctorPatientChatScreen> createState() => _DoctorPatientChatScreenState();
}

class _DoctorPatientChatScreenState extends State<DoctorPatientChatScreen> {
  late final DoctorPatientChatService _chatService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatService = DoctorPatientChatService(
      doctorId: widget.doctorId,
      patientId: widget.patientId,
      currentUserRole: widget.isDoctor ? 'doctor' : 'patient',
      currentUserName: widget.isDoctor ? widget.doctorName : widget.patientName,
    );

    _chatService.addListener(_onChatUpdate);
    _chatService.loadMessages();
  }

  void _onChatUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final String text = _textController.text;
    if (text.trim().isEmpty) return;
    _chatService.sendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final String otherUserName = widget.isDoctor ? widget.patientName : widget.doctorName;

    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.clinicInk),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.15),
                child: Text(
                  otherUserName.isNotEmpty ? otherUserName[0] : 'U',
                  style: const TextStyle(
                      color: AppColors.clinicAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(otherUserName, style: CT.h3.sized(15)),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('Direct Clinical Channel', style: CT.caption.sized(10.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            // Quick Video Call Shortcut
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: AppColors.clinicAccent, size: 24),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VideoConsultationScreen(
                      doctorId: widget.doctorId,
                      patientId: widget.patientId,
                      patientName: widget.patientName,
                      doctorName: widget.doctorName,
                      isDoctor: widget.isDoctor,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            // ── Messages List ───────────────────────────────────────────────
            Expanded(
              child: _chatService.isLoading && _chatService.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.clinicAccent))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: _chatService.messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ChatMessage msg = _chatService.messages[index];
                        final bool isMine =
                            (widget.isDoctor && msg.senderRole == 'doctor') ||
                            (!widget.isDoctor && msg.senderRole == 'patient');

                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.76,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMine ? AppColors.clinicAccent : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMine ? 16 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 16),
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    color: isMine ? Colors.white : AppColors.clinicInk,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: isMine ? Colors.white70 : AppColors.clinicInkSoft,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Input Bar ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.clinicHairline)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: CT.bodySmall,
                      decoration: InputDecoration(
                        hintText: 'Type message...',
                        hintStyle: CT.caption,
                        filled: true,
                        fillColor: AppColors.clinicBackground,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.clinicAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
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
