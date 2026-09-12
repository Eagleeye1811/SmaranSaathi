import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wellness.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/ui_kit.dart';

class YogaDetailScreen extends StatelessWidget {
  const YogaDetailScreen({super.key, required this.pose});

  final YogaPose pose;

  void _completePose(BuildContext context) {
    final AppState state = AppScope.read(context);
    state.recordWellnessSession(
      WellnessSession(
        id: 'yoga_${DateTime.now().millisecondsSinceEpoch}',
        type: WellnessType.yoga,
        title: pose.name,
        durationSeconds: pose.durationMinutes * 60,
        timestamp: DateTime.now(),
        caregiverNote: 'Completed ${pose.name} (${pose.sanskritName}) gentle stretch.',
      ),
    );

    // Navigate back to the Gentle Yoga Corner screen immediately
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      backgroundColor: state.highContrast ? Colors.white : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Yoga Corner',
        ),
        title: Text('${pose.name} (${pose.sanskritName})',
            style: AppText.h3.wght(800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Insets.gutter),
                children: <Widget>[
                  if (pose.videoAssetPath != null) ...<Widget>[
                    _YogaVideoPlayer(
                      videoPath: pose.videoAssetPath!,
                      color: AppColors.primary,
                    ),
                  ] else ...<Widget>[
                    // Serene Pose Illustration Canvas
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: Corners.r(Corners.lg),
                        border: Border.all(color: AppColors.hairline, width: 2),
                        boxShadow: AppColors.softShadow(),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: AppColors.softShadow(y: 4, blur: 12, opacity: 0.1),
                              ),
                              child: Icon(pose.icon, size: 54, color: AppColors.primary),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              pose.name,
                              style: AppText.h2.tint(AppColors.primaryDeep).wght(800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pose.durationMinutes} Minutes Gentle Practice',
                              style: AppText.caption.tint(AppColors.inkMuted).wght(600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Pose Key Instructions
                  SectionHeader(
                    title: 'How to Perform',
                    subtitle: pose.keyPointGuide,
                    icon: Icons.format_list_bulleted_rounded,
                  ),
                  const SizedBox(height: Insets.xs),
                  MmCard(
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < pose.steps.length; i++) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryTint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: AppText.caption.wght(800).tint(AppColors.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    pose.steps[i],
                                    style: AppText.bodyLarge.copyWith(height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < pose.steps.length - 1)
                            const Divider(color: AppColors.hairline),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Health Benefits
                  SectionHeader(
                    title: 'Benefits for You',
                    subtitle: 'Why this posture is helpful.',
                    icon: Icons.health_and_safety_rounded,
                  ),
                  const SizedBox(height: Insets.xs),
                  MmCard(
                    child: Column(
                      children: <Widget>[
                        for (final String benefit in pose.benefits)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(benefit, style: AppText.body),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Completed Pose Action Button
            Padding(
              padding: const EdgeInsets.all(Insets.gutter),
              child: BigButton(
                label: 'Completed Pose',
                icon: Icons.check_circle_rounded,
                color: AppColors.primary,
                onPressed: () => _completePose(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YogaVideoPlayer extends StatefulWidget {
  const _YogaVideoPlayer({required this.videoPath, required this.color});

  final String videoPath;
  final Color color;

  @override
  State<_YogaVideoPlayer> createState() => _YogaVideoPlayerState();
}

class _YogaVideoPlayerState extends State<_YogaVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset(widget.videoPath);
    _controller.addListener(_onControllerUpdate);
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controller.play();
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing yoga video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: Corners.r(Corners.lg),
          border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: AppColors.terracotta, size: 40),
              const SizedBox(height: 8),
              Text(
                'Unable to load video guide',
                style: AppText.body.tint(AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _initialized = false;
                  });
                  _initVideo();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.1),
          borderRadius: Corners.r(Corners.lg),
          border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(color: widget.color),
              const SizedBox(height: 12),
              Text(
                'Loading video posture demonstration...',
                style: AppText.caption.tint(AppColors.inkMuted).wght(600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: Corners.r(Corners.lg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: Corners.r(Corners.lg),
        child: Column(
          children: <Widget>[
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio > 0
                    ? _controller.value.aspectRatio
                    : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    VideoPlayer(_controller),
                    if (!_controller.value.isPlaying)
                      Container(
                        color: Colors.black38,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: widget.color,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.grey.shade800,
              ),
            ),
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, color: Colors.white),
                    onPressed: () {
                      _controller.seekTo(Duration.zero);
                      _controller.play();
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Video Posture Guide',
                      style: AppText.caption.tint(Colors.white70).wght(700),
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
