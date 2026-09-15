import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/telehealth/telehealth_service.dart';
import '../../../core/telehealth/webrtc_service.dart';
import 'post_call_summary_screen.dart';

/// Full-screen Doctor ↔ Patient Video Consultation Room with In-Call Chat Drawer.
class VideoConsultationScreen extends StatefulWidget {
  const VideoConsultationScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    this.doctorName = 'Dr. Sharma',
    this.isDoctor = true,
    this.isSelfTestMode = false,
  });

  final String doctorId;
  final String patientId;
  final String patientName;
  final String doctorName;
  final bool isDoctor;
  final bool isSelfTestMode;

  @override
  State<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  late final WebRtcService _webrtc;
  final TelehealthService _telehealth = TelehealthService();
  final TextEditingController _chatController = TextEditingController();

  bool _isChatOpen = false;
  int _callSeconds = 0;
  Timer? _callTimer;
  Offset _pipPosition = const Offset(16, 80);

  @override
  void initState() {
    super.initState();
    _webrtc = WebRtcService(
      baseUrl: _telehealth.baseUrl,
      roomName: 'room_${widget.doctorId}_${widget.patientId}',
      isInitiator: widget.isDoctor,
      userName: widget.isDoctor ? widget.doctorName : widget.patientName,
      isSelfTestMode: widget.isSelfTestMode,
    );

    _webrtc.initialize();
    _webrtc.addListener(_onWebRtcUpdate);

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callSeconds++);
      }
    });
  }

  void _onWebRtcUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _chatController.dispose();
    _webrtc.removeListener(_onWebRtcUpdate);
    _webrtc.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _endConsultation() async {
    final String transcript = _webrtc.getCompiledTranscript(widget.patientName);

    // Navigate to AI Post-Call Review Screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PostCallSummaryScreen(
            doctorId: widget.doctorId,
            patientId: widget.patientId,
            patientName: widget.patientName,
            doctorName: widget.doctorName,
            durationSeconds: _callSeconds,
            transcript: transcript,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            // ── Main Remote Video View ──────────────────────────────────────
            Positioned.fill(
              child: _webrtc.isInitialized
                  ? RTCVideoView(
                      _webrtc.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: AppColors.clinicAccent),
                    ),
            ),

            // Subtle vignette overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const <double>[0.0, 0.2, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top Bar with Status & Timer ─────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: <Widget>[
                  // Back / Leave button
                  GestureDetector(
                    onTap: _endConsultation,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Participant details & Timer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.isDoctor ? widget.patientName : widget.doctorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDuration(_callSeconds),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // AI Scribe Live Pulse Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.clinicAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.clinicAccent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.auto_awesome, color: AppColors.clinicAccent, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'AI Scribe Active',
                          style: TextStyle(
                            color: AppColors.clinicAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Draggable Picture-in-Picture Local Camera View ──────────────
            Positioned(
              top: _pipPosition.dy,
              right: _pipPosition.dx,
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    _pipPosition = Offset(
                      (_pipPosition.dx - details.delta.dx).clamp(16.0, 200.0),
                      (_pipPosition.dy + details.delta.dy).clamp(60.0, 450.0),
                    );
                  });
                },
                child: Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.clinicAccent, width: 2),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _webrtc.isInitialized
                      ? RTCVideoView(
                          _webrtc.localRenderer,
                          mirror: _webrtc.isFrontCamera,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : const Center(
                          child: Icon(Icons.videocam_off, color: Colors.white54),
                        ),
                ),
              ),
            ),

            // ── Bottom Floating Control Bar ─────────────────────────────────
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  // Mute / Unmute
                  _ControlButton(
                    icon: _webrtc.isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    isActive: !_webrtc.isAudioMuted,
                    onTap: _webrtc.toggleAudio,
                  ),
                  // Camera On / Off
                  _ControlButton(
                    icon: _webrtc.isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    isActive: !_webrtc.isVideoOff,
                    onTap: _webrtc.toggleVideo,
                  ),
                  // Flip Camera
                  _ControlButton(
                    icon: Icons.flip_camera_ios_rounded,
                    isActive: true,
                    onTap: _webrtc.switchCamera,
                  ),
                  // In-Call Chat Drawer Toggle
                  _ControlButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    badgeCount: _webrtc.inCallMessages.length,
                    isActive: _isChatOpen,
                    onTap: () => setState(() => _isChatOpen = !_isChatOpen),
                  ),
                  // End Call Button
                  _ControlButton(
                    icon: Icons.call_end_rounded,
                    color: Colors.redAccent,
                    onTap: _endConsultation,
                  ),
                ],
              ),
            ),

            // ── Slide-over In-Call Chat Drawer ──────────────────────────────
            if (_isChatOpen)
              Positioned(
                bottom: 90,
                left: 16,
                right: 16,
                height: 320,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      // Drawer Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'In-Call Messages',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                              onPressed: () => setState(() => _isChatOpen = false),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      // Messages List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _webrtc.inCallMessages.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Map<String, String> msg = _webrtc.inCallMessages[index];
                            final bool isMe = msg['sender'] == 'You';
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? AppColors.clinicAccent : Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      msg['text'] ?? '',
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      msg['time'] ?? '',
                                      style: TextStyle(
                                        color: isMe ? Colors.white70 : Colors.white38,
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
                      // Input Bar
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Type consultation note or message...',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.black38,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (String text) {
                                  _webrtc.sendInCallMessage(text);
                                  _chatController.clear();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.clinicAccent,
                              child: IconButton(
                                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                                onPressed: () {
                                  _webrtc.sendInCallMessage(_chatController.text);
                                  _chatController.clear();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    this.isActive = true,
    this.color,
    this.badgeCount = 0,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final Color? color;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color ?? (isActive ? Colors.white.withValues(alpha: 0.2) : Colors.white10),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.white30 : Colors.white10,
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: AppColors.clinicAccent,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
