import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/chat/doctor_patient_chat_service.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/app_state.dart';
import '../doctor/widgets/clinic_widgets.dart';
import '../telehealth/video_consultation_screen.dart';

/// Persistent 1-on-1 Messaging Screen between Doctor and Patient/Caregiver.
/// Unified across DoctorChatsScreen and PatientDetailScreen with zero loading delay.
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

    // Mark as read and scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final AppState state = AppScope.of(context);
        state.markDoctorConversationRead(widget.patientId);
        _scrollToBottom(animate: false);
      }
    });

    _chatService.loadMessages().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(AppState state) {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    state.sendDoctorChatMessage(
      patientId: widget.patientId,
      text: text,
    );

    // Sync in background if backend available
    try {
      _chatService.sendMessage(text);
    } catch (_) {}

    _scrollToBottom();
  }

  String _formatMessageTime(DateTime dt) {
    final int h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final DoctorConversation conv = state.getOrCreateDoctorConversation(widget.patientId);
    final List<ChatMessage> messages = conv.messages;
    final String otherUserName = widget.isDoctor ? widget.patientName : widget.doctorName;
    final String initial = otherUserName.trim().isNotEmpty
        ? otherUserName.trim()[0].toUpperCase()
        : (widget.isDoctor ? 'P' : 'D');

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
          titleSpacing: 0,
          title: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.clinicAccent.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.clinicAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      otherUserName,
                      style: CT.h3.sized(15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                        Text(
                          'Direct Clinical Channel',
                          style: CT.caption.sized(10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
              tooltip: 'Start Video Consultation',
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
            // ── Messages List (Immediate, no loading spinner) ───────────────
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.clinicAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.clinicAccent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Direct Clinical Channel',
                              style: CT.body.wght(700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Messages between you and $otherUserName are private and end-to-end encrypted for clinical continuity.',
                              style: CT.caption.sized(12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ChatMessage msg = messages[index];
                        final bool isMine = widget.isDoctor ? msg.isFromDoctor : !msg.isFromDoctor;

                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
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
                              border: isMine ? null : Border.all(color: AppColors.clinicHairline),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: <Widget>[
                                // Clinical Attachment Preview if any
                                if (msg.attachmentType != null) ...<Widget>[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? Colors.white.withValues(alpha: 0.18)
                                          : AppColors.clinicBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isMine
                                            ? Colors.white.withValues(alpha: 0.3)
                                            : AppColors.clinicHairline,
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          msg.attachmentType == 'care_plan'
                                              ? Icons.assignment_turned_in_rounded
                                              : (msg.attachmentType == 'report_request'
                                                  ? Icons.biotech_rounded
                                                  : Icons.attach_file_rounded),
                                          size: 20,
                                          color: isMine ? Colors.white : AppColors.clinicAccent,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                msg.attachmentTitle ?? 'Clinical Resource',
                                                style: TextStyle(
                                                  color: isMine ? Colors.white : AppColors.clinicInk,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (msg.attachmentSubtitle != null)
                                                Text(
                                                  msg.attachmentSubtitle!,
                                                  style: TextStyle(
                                                    color: isMine ? Colors.white70 : AppColors.clinicInkSoft,
                                                    fontSize: 10.5,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: isMine ? Colors.white : AppColors.clinicInk,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      _formatMessageTime(msg.timestamp),
                                      style: TextStyle(
                                        color: isMine ? Colors.white70 : AppColors.clinicInkSoft,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                    if (isMine) ...<Widget>[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all_rounded,
                                        size: 13,
                                        color: msg.status == MessageStatus.read
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ],
                                  ],
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
                      onSubmitted: (_) => _sendMessage(state),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.clinicAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(state),
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
