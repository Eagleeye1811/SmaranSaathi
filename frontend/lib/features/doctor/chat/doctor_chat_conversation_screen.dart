import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/illustration.dart';
import '../careplan/care_plan_screen.dart';
import '../patients/patient_detail_screen.dart';
import '../reports/medical_reports_screen.dart';
import '../widgets/clinic_widgets.dart';

/// WhatsApp-style 1-on-1 consultation chat between Doctor and Patient/Caregiver.
class DoctorChatConversationScreen extends StatefulWidget {
  const DoctorChatConversationScreen({
    super.key,
    required this.patientId,
  });

  final String patientId;

  @override
  State<DoctorChatConversationScreen> createState() => _DoctorChatConversationScreenState();
}

class _DoctorChatConversationScreenState extends State<DoctorChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  Timer? _replyTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    // Mark as read on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).markDoctorConversationRead(widget.patientId);
      _scrollToBottom();
    });
  }

  void _onTextChanged() {
    final bool has = _textController.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage({String? text, String? attachmentType, String? attachmentTitle, String? attachmentSubtitle}) {
    final String content = text ?? _textController.text.trim();
    if (content.isEmpty) return;

    final AppState state = AppScope.of(context);
    state.sendDoctorChatMessage(
      patientId: widget.patientId,
      text: content,
      attachmentType: attachmentType,
      attachmentTitle: attachmentTitle,
      attachmentSubtitle: attachmentSubtitle,
    );

    _textController.clear();
    setState(() => _hasText = false);

    Future<void>.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    // Simulate caregiver acknowledgment after 2 seconds
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final DoctorConversation conv = state.getOrCreateDoctorConversation(widget.patientId);
      final List<String> simulatedReplies = <String>[
        'Thank you Doctor Baruah, noted! We will follow this closely.',
        'Understood Doctor. I have updated ${conv.patientName.split(' ').first}\'s daily schedule.',
        'Thank you for the prompt guidance Doctor! 🙏',
      ];
      final String reply = simulatedReplies[DateTime.now().second % simulatedReplies.length];

      final ChatMessage caregiverMsg = ChatMessage(
        id: 'msg_reply_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: widget.patientId,
        text: reply,
        timestamp: DateTime.now(),
        isFromDoctor: false,
        status: MessageStatus.read,
      );

      state.addCaregiverChatMessage(widget.patientId, caregiverMsg);
      Future<void>.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Share Clinical Resource', style: CT.h3),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _buildAttachmentOption(
                      icon: Icons.assignment_turned_in_rounded,
                      color: const Color(0xFF00A884),
                      label: 'Care Plan',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendMessage(
                          text: 'Here is the customized clinical care plan for the ongoing cognitive routine.',
                          attachmentType: 'care_plan',
                          attachmentTitle: 'Active Clinical Care Plan',
                          attachmentSubtitle: 'Cognitive stimulation & daily routines',
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.biotech_rounded,
                      color: const Color(0xFF1F6FEB),
                      label: 'Request Report',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendMessage(
                          text: 'Please upload the latest blood work report when available.',
                          attachmentType: 'report_request',
                          attachmentTitle: 'Laboratory Investigation Request',
                          attachmentSubtitle: 'Complete Blood Count (CBC) & Serum Electrolytes',
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.medication_rounded,
                      color: const Color(0xFFE0913A),
                      label: 'Prescription',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendMessage(
                          text: 'Medication note: Continue current morning vitamins and prescribed dosage.',
                          attachmentType: 'prescription',
                          attachmentTitle: 'Routine Medication Note',
                          attachmentSubtitle: 'Dosage confirmation & adherence check',
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF7B2CBF),
                      label: 'Follow-up',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendMessage(
                          text: 'Reminder: Scheduled virtual follow-up appointment is approaching. Please keep the vitals log ready.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: CT.caption.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF3B4A54))),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime dt) {
    final int h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final String ampm = dt.hour >= 12 ? 'pm' : 'am';
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final DoctorConversation conv = state.getOrCreateDoctorConversation(widget.patientId);

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // WhatsApp classic wallpaper neutral tone
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54), // WhatsApp primary green
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PatientDetailScreen(patientId: conv.patientId),
              ),
            );
          },
          child: Row(
            children: <Widget>[
              // Avatar
              Stack(
                children: <Widget>[
                  SceneImage(sceneId: conv.sceneId, size: 38, circle: true),
                  if (conv.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              // Contact Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      conv.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      conv.isOnline
                          ? 'online'
                          : 'last seen ${conv.lastSeen} · ${conv.caregiverName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
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
        actions: <Widget>[
          // Direct shortcut to Patient Record EMR
          IconButton(
            tooltip: 'View Patient Record',
            icon: const Icon(Icons.folder_shared_outlined, color: Colors.white, size: 21),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PatientDetailScreen(patientId: conv.patientId),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Tele-consultation call',
            icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Starting secure video consultation with ${conv.patientName}...'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF075E54),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (String value) {
              if (value == 'record') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PatientDetailScreen(patientId: conv.patientId),
                  ),
                );
              } else if (value == 'careplan') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CarePlanScreen(patientId: conv.patientId),
                  ),
                );
              } else if (value == 'reports') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicalReportsScreen(patientId: conv.patientId),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'record',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.badge_outlined, size: 18, color: Color(0xFF54656F)),
                    SizedBox(width: 10),
                    Text('Patient Record'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'careplan',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF54656F)),
                    SizedBox(width: 10),
                    Text('Care Plan'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reports',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.description_outlined, size: 18, color: Color(0xFF54656F)),
                    SizedBox(width: 10),
                    Text('Medical Reports'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // WhatsApp End-to-End Encryption Banner (Pinned at top)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4), // WhatsApp encryption yellow capsule
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF5F5400)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Messages are end-to-end encrypted and synced with SmaranSaathi Clinic EMR.',
                        textAlign: TextAlign.center,
                        style: CT.caption.copyWith(
                          color: const Color(0xFF5F5400),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Messages list
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: <Widget>[
                  // Date pill
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF54656F),
                        ),
                      ),
                    ),
                  ),
                  // Render all conversation messages
                  for (final ChatMessage msg in conv.messages)
                    _buildMessageBubble(msg, conv),
                ],
              ),
            ),

            // Quick clinical actions bar
            Container(
              height: 40,
              color: Colors.white.withValues(alpha: 0.95),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: <Widget>[
                  _buildQuickActionChip(
                    icon: Icons.assignment_outlined,
                    label: 'Share Care Plan',
                    onTap: () {
                      _sendMessage(
                        text: 'Here is the customized care plan for the ongoing cognitive stimulation routine.',
                        attachmentType: 'care_plan',
                        attachmentTitle: 'Active Clinical Care Plan',
                        attachmentSubtitle: 'Procedural sorting & memory exercises',
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildQuickActionChip(
                    icon: Icons.biotech_outlined,
                    label: 'Request Lab Report',
                    onTap: () {
                      _sendMessage(
                        text: 'Please upload the latest routine lab investigations (CBC & metabolic profile).',
                        attachmentType: 'report_request',
                        attachmentTitle: 'Laboratory Investigation Request',
                        attachmentSubtitle: 'Complete Blood Count (CBC)',
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildQuickActionChip(
                    icon: Icons.medication_outlined,
                    label: 'Check Routine',
                    onTap: () {
                      _sendMessage(
                        text: 'Checking in: Did ${conv.patientName.split(' ').first} complete the morning wellness activity and medication?',
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildQuickActionChip(
                    icon: Icons.schedule_outlined,
                    label: 'Follow-up Check',
                    onTap: () {
                      _sendMessage(
                        text: 'How is ${conv.patientName.split(' ').first}\'s sleep quality and mood today?',
                      );
                    },
                  ),
                ],
              ),
            ),

            // WhatsApp-style Input Composer
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // Text field pill
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF54656F), size: 22),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: CT.body.sized(14.5).copyWith(color: const Color(0xFF111B21)),
                              maxLines: 5,
                              minLines: 1,
                              decoration: const InputDecoration(
                                hintText: 'Message...',
                                hintStyle: TextStyle(color: Color(0xFF8696A0), fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              onSubmitted: (String v) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF54656F), size: 22),
                            onPressed: _showAttachmentSheet,
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF54656F), size: 21),
                            onPressed: () {
                              _sendMessage(
                                text: 'Camera photo / scan attachment shared with patient record.',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // WhatsApp Floating Send FAB
                  GestureDetector(
                    onTap: _hasText ? () => _sendMessage() : _showAttachmentSheet,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A884), // WhatsApp Send Button Green
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _hasText ? Icons.send_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EDEF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: const Color(0xFF075E54)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF075E54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, DoctorConversation conv) {
    final bool isMe = msg.isFromDoctor;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          // WhatsApp classic bubble colors: #E7FFDB for outgoing, pure white for incoming
          color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Sender tag if from caregiver
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  conv.caregiverName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF075E54),
                  ),
                ),
              ),

            // Attachment Card if present
            if (msg.attachmentType != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFD3F8C4) : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isMe ? const Color(0xFFBCE8AA) : const Color(0xFFE9EDEF),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          msg.attachmentType == 'care_plan'
                              ? Icons.assignment_outlined
                              : msg.attachmentType == 'report_request'
                                  ? Icons.biotech_outlined
                                  : Icons.medication_outlined,
                          size: 18,
                          color: const Color(0xFF075E54),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            msg.attachmentTitle ?? 'Clinical Resource',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111B21),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (msg.attachmentSubtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        msg.attachmentSubtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF54656F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Message text & timestamp
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 6,
              children: <Widget>[
                Text(
                  msg.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111B21),
                    height: 1.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _formatMessageTime(msg.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF667781),
                      ),
                    ),
                    if (isMe) ...<Widget>[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 15,
                        color: msg.status == MessageStatus.read
                            ? const Color(0xFF53BDEB) // WhatsApp double blue checkmark
                            : const Color(0xFF8696A0),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
