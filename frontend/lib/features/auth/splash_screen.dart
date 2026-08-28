import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The video splash screen shown on app launch. Plays [assets/videos/splash_screen.mp4]
/// in full screen and smoothly transitions to [next] upon completion.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _initialized = false;
  bool _hasStartedPlaying = false;
  bool _ready = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() async {
    _videoController = VideoPlayerController.asset('assets/videos/splash_screen.mp4');

    try {
      await _videoController.initialize();
      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      await _videoController.setLooping(false);
      await _videoController.setVolume(1.0);
      await _videoController.play();
      _videoController.addListener(_videoListener);

      final Duration duration = _videoController.value.duration;
      final Duration timeout = duration > Duration.zero
          ? duration + const Duration(milliseconds: 1500)
          : const Duration(seconds: 8);
      _fallbackTimer = Timer(timeout, _proceed);
    } catch (e) {
      debugPrint('Error initializing splash video: $e');
      _proceed();
    }
  }

  void _videoListener() {
    if (!mounted || _ready) return;
    final VideoPlayerValue value = _videoController.value;

    if (value.isPlaying || value.position > const Duration(milliseconds: 100)) {
      _hasStartedPlaying = true;
    }

    if (_hasStartedPlaying &&
        !value.isPlaying &&
        value.position >= (value.duration - const Duration(milliseconds: 400))) {
      _proceed();
    }
  }

  void _proceed() {
    if (_ready) return;
    _ready = true;
    _fallbackTimer?.cancel();

    try {
      _videoController.removeListener(_videoListener);
      _videoController.pause();
    } catch (_) {}

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    try {
      _videoController.removeListener(_videoListener);
      _videoController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: _ready
          ? KeyedSubtree(
              key: const ValueKey<String>('next_screen'),
              child: widget.next,
            )
          : Scaffold(
              key: const ValueKey<String>('splash_screen'),
              backgroundColor: Colors.black,
              body: SizedBox.expand(
                child: _initialized && _videoController.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController.value.size.width,
                          height: _videoController.value.size.height,
                          child: VideoPlayer(_videoController),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
    );
  }
}
