import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';
import '../../chat/doctor_patient_chat_screen.dart';

/// Conversation list screen for clinicians to connect with patients and caregivers.
/// Fully aligned with SmaranSaathi clinic design system and aesthetic standards.
class DoctorChatsScreen extends StatefulWidget {
  const DoctorChatsScreen({super.key});

  @override
  State<DoctorChatsScreen> createState() => _DoctorChatsScreenState();
}

class _DoctorChatsScreenState extends State<DoctorChatsScreen> {
  String _query = '';
  int _filterIndex = 0; // 0: All, 1: Unread, 2: Needs Attention
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      if (diff.inMinutes <= 1) return 'Just now';
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24 && dt.day == now.day) {
      final int h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final String m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m $ampm';
    }
    if (diff.inDays < 2) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }

  void _openChat(BuildContext context, DoctorConversation conv) {
    final AppState state = AppScope.of(context);
    state.markDoctorConversationRead(conv.patientId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorPatientChatScreen(
          doctorId: 'doc_001',
          patientId: conv.patientId,
          patientName: conv.patientName,
          doctorName: 'Dr. Sharma',
          isDoctor: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DoctorConversation> all = state.doctorConversations;

    // Filter conversations
    final List<DoctorConversation> filtered = all.where((DoctorConversation c) {
      final bool matchesQuery = _query.isEmpty ||
          c.patientName.toLowerCase().contains(_query.toLowerCase()) ||
          c.caregiverName.toLowerCase().contains(_query.toLowerCase()) ||
          (c.lastMessage?.text.toLowerCase().contains(_query.toLowerCase()) ?? false);

      if (!matchesQuery) return false;
      if (_filterIndex == 1) return c.unreadCount > 0;
      if (_filterIndex == 2) return c.isAttention;
      return true;
    }).toList();

    final int unreadTotal = state.totalDoctorUnreadChats;
    final int attentionTotal = all.where((DoctorConversation c) => c.isAttention).length;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          // Consistent Clinic Top Bar
          ClinicTopBar(
            title: l.doctorTabChats,
            subtitle: '${all.length} active consultation threads',
          ),

          // Search and Filters Area
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 12),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  style: CT.body,
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by patient, caregiver or message...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 19),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                // Clinic Design System Filter Chips
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      _FilterTabChip(
                        label: 'All (${all.length})',
                        selected: _filterIndex == 0,
                        color: AppColors.clinicAccent,
                        onTap: () => setState(() => _filterIndex = 0),
                      ),
                      _FilterTabChip(
                        label: 'Unread ($unreadTotal)',
                        selected: _filterIndex == 1,
                        color: AppColors.clinicAccent,
                        onTap: () => setState(() => _filterIndex = 1),
                      ),
                      _FilterTabChip(
                        label: 'Needs Attention ($attentionTotal)',
                        selected: _filterIndex == 2,
                        color: AppColors.danger,
                        onTap: () => setState(() => _filterIndex = 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conversation List (WhatsApp-style single list with thin divider between patients)
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: 'No conversations found',
                    message: 'Try a different search query or filter to find patient messages.',
                    icon: Icons.chat_bubble_outline_rounded,
                  )
                : Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.clinicHairline, width: 1),
                      ),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        thickness: 0.8,
                        indent: 78,
                        endIndent: Insets.gutter,
                        color: AppColors.clinicHairline,
                      ),
                      itemBuilder: (BuildContext context, int i) {
                        final DoctorConversation conv = filtered[i];
                        final ChatMessage? last = conv.lastMessage;
                        final bool hasUnread = conv.unreadCount > 0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openChat(context, conv),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.gutter,
                                vertical: 12,
                              ),
                              child: Row(
                                children: <Widget>[
                                  // Profile Avatar: Clean circular portrait with NO status outline ring
                                  Stack(
                                    children: <Widget>[
                                      SceneImage(
                                        sceneId: conv.sceneId,
                                        size: 48,
                                        circle: true,
                                      ),
                                      if (conv.isOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: AppColors.success,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),

                                  // Conversation Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        // Patient name & timestamp
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: Text(
                                                conv.patientName,
                                                style: CT.body.wght(700),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (last != null) ...<Widget>[
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatTime(last.timestamp),
                                                style: CT.caption.sized(11.5).copyWith(
                                                  color: hasUnread
                                                      ? AppColors.clinicAccent
                                                      : AppColors.clinicInkSoft,
                                                  fontWeight: hasUnread
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),

                                        // Caregiver & demographics
                                        Text.rich(
                                          TextSpan(
                                            children: <InlineSpan>[
                                              TextSpan(
                                                text: conv.caregiverName,
                                                style: CT.caption.sized(12).copyWith(
                                                  color: AppColors.clinicAccent,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(
                                                text: ' · ${conv.patientAge}y · ${conv.district}',
                                                style: CT.caption.sized(11.5),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),

                                        // Message preview & badges
                                        Row(
                                          children: <Widget>[
                                            if (last != null && last.isFromDoctor) ...<Widget>[
                                              Icon(
                                                Icons.done_all_rounded,
                                                size: 15,
                                                color: last.status == MessageStatus.read
                                                    ? AppColors.secondary
                                                    : AppColors.inkMuted,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                last != null
                                                    ? (last.attachmentType != null
                                                        ? '📎 ${last.attachmentTitle ?? 'Clinical Resource'}'
                                                        : last.text)
                                                    : 'No messages yet · Tap to start',
                                                style: CT.caption.sized(12.5).copyWith(
                                                  color: hasUnread
                                                      ? AppColors.clinicInk
                                                      : AppColors.clinicInkSoft,
                                                  fontWeight: hasUnread
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (hasUnread) ...<Widget>[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.clinicAccent,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${conv.unreadCount}',
                                                  style: CT.caption.sized(11).copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (conv.isAttention && !hasUnread) ...<Widget>[
                                              const SizedBox(width: 8),
                                              PillTag(
                                                label: 'Attention',
                                                color: AppColors.danger,
                                                dense: true,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabChip extends StatelessWidget {
  const _FilterTabChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.clinicSurface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? color : AppColors.clinicHairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: CT.caption.copyWith(
              color: selected ? color : AppColors.clinicInkSoft,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
