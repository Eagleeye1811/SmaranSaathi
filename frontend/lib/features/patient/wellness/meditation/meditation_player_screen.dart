import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wellness.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/ui_kit.dart';

class MeditationPlayerScreen extends StatefulWidget {
  const MeditationPlayerScreen({
    super.key,
    this.meditation,
    this.sound,
  }) : assert(meditation != null || sound != null, 'Provide either meditation or sound');

  final GuidedMeditation? meditation;
  final CalmingSound? sound;

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _timer;
  AudioPlayer? _audioPlayer;

  bool _isPlaying = false;
  bool _isFinished = false;
  int _currentStepIndex = 0;
  int _elapsedSeconds = 0;
  int _targetDurationSeconds = 300; // 5 minutes default

  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerDurationSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    if (widget.meditation != null) {
      _targetDurationSeconds = widget.meditation!.durationMinutes * 60;
    }

    _initAudio();
    _startPlayback();
  }

  Future<void> _initAudio() async {
    final String? path = widget.meditation?.audioAssetPath;
    if (path != null && path.isNotEmpty) {
      try {
        _audioPlayer = AudioPlayer();
        _playerCompleteSub = _audioPlayer?.onPlayerComplete.listen((_) {
          if (mounted && !_isFinished) {
            _finishSession();
          }
        });

        _playerDurationSub = _audioPlayer?.onDurationChanged.listen((Duration d) {
          if (mounted && d.inSeconds > 0) {
            setState(() {
              _targetDurationSeconds = d.inSeconds;
            });
          }
        });

        final String relativePath = path.startsWith('assets/')
            ? path.substring('assets/'.length)
            : path;
        await _audioPlayer?.play(AssetSource(relativePath));
      } catch (e) {
        debugPrint('Audio playback error for $path: $e');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerCompleteSub?.cancel();
    _playerDurationSub?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPlayback() {
    setState(() => _isPlaying = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (widget.meditation != null && widget.meditation!.audioGuidance.isNotEmpty) {
          final int stepInterval =
              (_targetDurationSeconds / widget.meditation!.audioGuidance.length).round();
          if (stepInterval > 0) {
            _currentStepIndex = (_elapsedSeconds ~/ stepInterval)
                .clamp(0, widget.meditation!.audioGuidance.length - 1);
          }
        }

        if (_elapsedSeconds >= _targetDurationSeconds) {
          _finishSession();
        }
      });
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _timer?.cancel();
      _pulseController.stop();
      _audioPlayer?.pause();
      setState(() => _isPlaying = false);
    } else {
      _pulseController.repeat(reverse: true);
      _audioPlayer?.resume();
      _startPlayback();
    }
  }

  void _finishSession() {
    _timer?.cancel();
    _pulseController.stop();
    _audioPlayer?.stop();
    setState(() {
      _isPlaying = false;
      _isFinished = true;
    });
    _recordSession();
  }

  void _recordSession() {
    final AppState state = AppScope.read(context);
    final String title = widget.meditation?.title ?? widget.sound?.name ?? 'Calming Session';
    final WellnessType type =
        widget.meditation != null ? WellnessType.meditation : WellnessType.sound;

    state.recordWellnessSession(
      WellnessSession(
        id: 'meditation_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        title: title,
        durationSeconds: _elapsedSeconds > 0 ? _elapsedSeconds : 180,
        timestamp: DateTime.now(),
        caregiverNote: 'Enjoyed $title session for ${(_elapsedSeconds / 60).toStringAsFixed(1)} min',
      ),
    );
  }

  void _stopAndClose() {
    _timer?.cancel();
    _pulseController.stop();
    if (_elapsedSeconds > 10 && !_isFinished) {
      _recordSession();
    }
    Navigator.of(context).pop();
  }

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _themeColor => AppColors.primary;

  String get _title => widget.meditation?.title ?? widget.sound?.name ?? 'Meditation';

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final double progress = (_elapsedSeconds / _targetDurationSeconds).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: state.highContrast ? Colors.white : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30, color: AppColors.ink),
          onPressed: _stopAndClose,
          tooltip: 'Back to Wellness',
        ),
        title: Text(_title, style: AppText.h3.wght(800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            children: <Widget>[
              if (_isFinished) ...<Widget>[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const ConfettiOverlay(),
                        const SizedBox(height: 16),
                        const Companion(state: CompanionState.gentle, size: 140),
                        const SizedBox(height: 24),
                        Text(
                          'Meditation Complete',
                          style: AppText.h1.sized(30).tint(AppColors.primaryDeep),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Thank you for taking time to care for your mind.\nHave a peaceful day.',
                          textAlign: TextAlign.center,
                          style: AppText.bodyLarge.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 36),
                        BigButton(
                          label: 'Return to Wellness Corner',
                          icon: Icons.check_circle_rounded,
                          color: _themeColor,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 12),
                // Pulse visualizer ring
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (BuildContext context, Widget? child) {
                            final double scale = 0.9 + (_pulseController.value * 0.15);
                            return Transform.scale(
                              scale: _isPlaying ? scale : 1.0,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _themeColor.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: _themeColor.withValues(alpha: 0.6),
                                    width: 3,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: _themeColor.withValues(alpha: 0.25),
                                      blurRadius: 30,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    widget.meditation?.icon ?? widget.sound?.icon ?? Icons.spa_rounded,
                                    size: 76,
                                    color: _themeColor,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        if (widget.meditation != null &&
                            widget.meditation!.audioGuidance.isNotEmpty) ...<Widget>[
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Padding(
                              key: ValueKey<int>(_currentStepIndex),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '"${widget.meditation!.audioGuidance[_currentStepIndex]}"',
                                style: AppText.h3.sized(20).copyWith(height: 1.4).tint(AppColors.primaryDeep),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ] else ...<Widget>[
                          Text(
                            widget.sound?.description ?? 'Calming sound playing softly...',
                            style: AppText.bodyLarge.tint(AppColors.inkSoft),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Progress and Timer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: <Widget>[
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: Corners.r(Corners.sm),
                        backgroundColor: AppColors.hairline,
                        color: _themeColor,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(_formatTime(_elapsedSeconds),
                              style: AppText.caption.wght(700)),
                          Text(_formatTime(_targetDurationSeconds),
                              style: AppText.caption.tint(AppColors.inkMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RoundIconButton(
                      icon: Icons.stop_rounded,
                      size: 54,
                      color: AppColors.danger,
                      onPressed: _stopAndClose,
                      tooltip: 'Stop Meditation',
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: Corners.r(Corners.lg),
                        ),
                      ),
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 32,
                      ),
                      label: Text(
                        _isPlaying ? 'Pause' : 'Resume',
                        style: AppText.h3.tint(Colors.white).wght(700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
