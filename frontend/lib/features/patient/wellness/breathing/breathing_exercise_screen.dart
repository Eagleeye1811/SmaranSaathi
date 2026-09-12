import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wellness.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/ui_kit.dart';

enum BreathingPhase { inhale, hold, exhale, holdAfterExhale, complete }

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key, required this.technique});

  final BreathingTechnique technique;

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  Timer? _phaseTimer;

  bool _started = false;
  bool _finished = false;
  int _currentCycle = 1;
  BreathingPhase _phase = BreathingPhase.inhale;
  int _secondsRemaining = 0;
  int _totalElapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.technique.inhaleSeconds),
    );
    _secondsRemaining = widget.technique.inhaleSeconds;
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _started = true;
      _currentCycle = 1;
      _totalElapsedSeconds = 0;
    });
    _beginPhase(BreathingPhase.inhale);
  }

  void _beginPhase(BreathingPhase phase) {
    _phaseTimer?.cancel();
    _phase = phase;

    if (phase == BreathingPhase.complete) {
      _animController.stop();
      setState(() => _finished = true);
      _recordSession();
      return;
    }

    int durationSeconds = switch (phase) {
      BreathingPhase.inhale => widget.technique.inhaleSeconds,
      BreathingPhase.hold => widget.technique.holdSeconds,
      BreathingPhase.exhale => widget.technique.exhaleSeconds,
      BreathingPhase.holdAfterExhale => widget.technique.holdAfterExhaleSeconds,
      _ => 0,
    };

    if (durationSeconds <= 0) {
      _nextPhase();
      return;
    }

    setState(() => _secondsRemaining = durationSeconds);

    if (phase == BreathingPhase.inhale) {
      _animController.duration = Duration(seconds: durationSeconds);
      _animController.forward(from: 0.0);
    } else if (phase == BreathingPhase.exhale) {
      _animController.duration = Duration(seconds: durationSeconds);
      _animController.reverse(from: 1.0);
    }

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      setState(() {
        _totalElapsedSeconds++;
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        _nextPhase();
      }
    });
  }

  void _nextPhase() {
    switch (_phase) {
      case BreathingPhase.inhale:
        if (widget.technique.holdSeconds > 0) {
          _beginPhase(BreathingPhase.hold);
        } else {
          _beginPhase(BreathingPhase.exhale);
        }
      case BreathingPhase.hold:
        _beginPhase(BreathingPhase.exhale);
      case BreathingPhase.exhale:
        if (widget.technique.holdAfterExhaleSeconds > 0) {
          _beginPhase(BreathingPhase.holdAfterExhale);
        } else {
          _checkCycleEnd();
        }
      case BreathingPhase.holdAfterExhale:
        _checkCycleEnd();
      case BreathingPhase.complete:
        break;
    }
  }

  void _checkCycleEnd() {
    if (_currentCycle >= widget.technique.recommendedCycles) {
      _beginPhase(BreathingPhase.complete);
    } else {
      setState(() => _currentCycle++);
      _beginPhase(BreathingPhase.inhale);
    }
  }

  void _stopEarly() {
    _phaseTimer?.cancel();
    _animController.stop();
    if (_totalElapsedSeconds > 5) {
      _recordSession();
    }
    Navigator.of(context).pop();
  }

  void _recordSession() {
    final AppState state = AppScope.read(context);
    state.recordWellnessSession(
      WellnessSession(
        id: 'breathing_${DateTime.now().millisecondsSinceEpoch}',
        type: WellnessType.breathing,
        title: widget.technique.title,
        durationSeconds: _totalElapsedSeconds > 0 ? _totalElapsedSeconds : 60,
        timestamp: DateTime.now(),
        caregiverNote: 'Completed $_currentCycle cycle(s) of ${widget.technique.title}',
      ),
    );
  }

  String get _phasePrompt => switch (_phase) {
        BreathingPhase.inhale => 'Inhale Slowly...',
        BreathingPhase.hold => 'Hold Breath...',
        BreathingPhase.exhale => 'Exhale Gently...',
        BreathingPhase.holdAfterExhale => 'Rest Breath...',
        BreathingPhase.complete => 'Wonderful Work!',
      };

  Color get _phaseColor => AppColors.primary;

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
          onPressed: _stopEarly,
          tooltip: 'Back to Wellness',
        ),
        title: Text(widget.technique.title, style: AppText.h3.wght(800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            children: <Widget>[
              if (!_started) ...<Widget>[
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.technique.icon,
                                size: 72, color: AppColors.primary),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.technique.title,
                            style: AppText.h1.sized(28),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.technique.subtitle,
                            style: AppText.body.tint(AppColors.inkMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          MmCard(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  widget.technique.description,
                                  style: AppText.bodyLarge.copyWith(height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _CycleChip(
                                        label: 'Inhale ${widget.technique.inhaleSeconds}s',
                                        color: AppColors.primary),
                                    if (widget.technique.holdSeconds > 0)
                                      _CycleChip(
                                          label: 'Hold ${widget.technique.holdSeconds}s',
                                          color: AppColors.primary),
                                    _CycleChip(
                                        label: 'Exhale ${widget.technique.exhaleSeconds}s',
                                        color: AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          BigButton(
                            label: 'Start Breathing Exercise',
                            icon: Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            onPressed: _startExercise,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (_finished) ...<Widget>[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const ConfettiOverlay(),
                        const SizedBox(height: 16),
                        const Companion(state: CompanionState.celebrating, size: 140),
                        const SizedBox(height: 24),
                        Text(
                          'Session Complete!',
                          style: AppText.h1.sized(30).tint(AppColors.primaryDeep),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You completed ${widget.technique.recommendedCycles} peaceful breathing cycles.\nYour mind and body are now relaxed.',
                          textAlign: TextAlign.center,
                          style: AppText.bodyLarge.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 36),
                        BigButton(
                          label: 'Done & Return to Wellness',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.primary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...<Widget>[
                // Active breathing guide
                Text(
                  'Cycle $_currentCycle of ${widget.technique.recommendedCycles}',
                  style: AppText.overline.sized(13),
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _phaseColor.withValues(alpha: 0.15),
                    borderRadius: Corners.r(Corners.lg),
                    border: Border.all(color: _phaseColor, width: 2),
                  ),
                  child: Text(
                    _phasePrompt,
                    style: AppText.h2.tint(_phaseColor).wght(800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_secondsRemaining s',
                  style: AppText.h1.sized(36).tint(_phaseColor),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (BuildContext context, Widget? child) {
                        final double scale = 0.55 + (_animController.value * 0.45);
                        return Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            // Outer pulsing glow circle
                            Transform.scale(
                              scale: scale * 1.15,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _phaseColor.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                            // Main expanding/contracting circle
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      _phaseColor,
                                      _phaseColor.withValues(alpha: 0.75),
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: _phaseColor.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _phase == BreathingPhase.inhale
                                        ? Icons.north_rounded
                                        : _phase == BreathingPhase.exhale
                                            ? Icons.south_rounded
                                            : Icons.pause_rounded,
                                    size: 54,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BigButton(
                  label: 'Stop Exercise',
                  icon: Icons.stop_rounded,
                  color: AppColors.danger,
                  onPressed: _stopEarly,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppText.caption.tint(color).wght(700),
      ),
    );
  }
}
