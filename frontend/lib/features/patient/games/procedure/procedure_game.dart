import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';

/// One step of an everyday procedure.
class ProcedureStep {
  const ProcedureStep(this.label, this.icon, this.color, {this.detail = ''});
  final String label;
  final IconData icon;
  final Color color;
  final String detail;
}

class Procedure {
  const Procedure({
    required this.title,
    required this.intro,
    required this.steps,
    this.videoPath,
    this.personal = false,
  });

  final String title;
  final String intro;
  final List<ProcedureStep> steps;
  final String? videoPath;
  final bool personal;
}

/// Procedural-memory activity: watch a familiar sequence, then rebuild it.
///
/// Interaction is tap-to-order rather than drag-and-drop — dragging is the
/// first gesture that becomes unreliable for elderly users with tremor.
class ProcedureGame extends StatefulWidget {
  const ProcedureGame({super.key});

  @override
  State<ProcedureGame> createState() => _ProcedureGameState();
}

enum _Phase { intro, watch, build }

class _ProcedureGameState extends State<ProcedureGame> {
  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.procedure);

  late final AppState _state = AppScope.read(context);
  late final int _maxUnlockedLevel = _state.levelOf(GameId.procedure);
  late int _selectedLevel;
  Procedure get _procedure => _procedureFor(_selectedLevel, _state.patient.shortName);

  _Phase _phase = _Phase.intro;
  final List<int> _placed = <int>[];

  late List<int> _shuffled;
  String? _feedback;
  bool _feedbackPositive = true;
  int _hintsLeft = 3;
  int? _hintedIndex;

  /// Level 4 and above remove the picture-tile assistance during rebuilding.
  bool get _lowAssistance => _selectedLevel >= 4;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.procedure);
    _initLevelOrder();
  }

  void _initLevelOrder() {
    final List<int> order = List<int>.generate(_procedure.steps.length, (int i) => i);
    _shuffled = _deterministicShuffle(order, _selectedLevel * 31 + order.length);
  }

  void _changeLevel(int lvl) {
    setState(() {
      _selectedLevel = lvl;
      _placed.clear();
      _feedback = null;
      _hintedIndex = null;
      _initLevelOrder();
    });
  }


  List<int> _deterministicShuffle(List<int> input, int seed) {
    final List<int> list = List<int>.from(input);
    int s = seed;
    for (int i = list.length - 1; i > 0; i--) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final int j = s % (i + 1);
      final int tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    // Guarantee it isn't accidentally already correct.
    bool same = true;
    for (int i = 0; i < list.length; i++) {
      if (list[i] != i) same = false;
    }
    if (same && list.length > 1) {
      final int t = list[0];
      list[0] = list[1];
      list[1] = t;
    }
    return list;
  }

  static Procedure _procedureFor(int level, String name) {
    switch (level) {
      case 2:
        return const Procedure(
          title: 'Washing clothes',
          intro: 'Let us go through the steps of washing traditional clothes.',
          videoPath: 'assets/videos/washing_clothes.mp4',
          steps: <ProcedureStep>[
            ProcedureStep('Soak in soapy water', Icons.wash_rounded, AppColors.secondary,
                detail: 'In warm water with soap'),
            ProcedureStep('Gently scrub clean', Icons.clean_hands_rounded, AppColors.terracotta,
                detail: 'Scrub fabric edges'),
            ProcedureStep('Rinse with fresh water', Icons.opacity_rounded, AppColors.primary,
                detail: 'Until water runs clear'),
            ProcedureStep('Squeeze excess water', Icons.compress_rounded, AppColors.plum,
                detail: 'Twist and wring gently'),
            ProcedureStep('Hang on clothesline to dry', Icons.dry_cleaning_rounded, AppColors.accent,
                detail: 'Under the morning sun'),
          ],
        );

      case 3:
      case 4:
        return const Procedure(
          title: 'Making til pitha',
          intro:
              'You made these every Magh Bihu. Let us go through the steps together.',
          steps: <ProcedureStep>[
            ProcedureStep('Soak the rice', Icons.rice_bowl_rounded, AppColors.secondary),
            ProcedureStep('Grind it into flour', Icons.blur_circular_rounded, AppColors.plum),
            ProcedureStep('Roast the sesame', Icons.local_fire_department_rounded,
                AppColors.terracotta),
            ProcedureStep('Mix with jaggery', Icons.cookie_rounded, AppColors.accent),
            ProcedureStep('Spread on the hot pan', Icons.crop_square_rounded, AppColors.primary),
            ProcedureStep('Roll it and serve', Icons.restaurant_rounded, AppColors.indigo),
          ],
        );
      case 1:
      default:
        return const Procedure(
          title: 'Making tea',
          intro: 'Let us try something you know well. Watch how the tea is made.',
          videoPath: 'assets/videos/procedural_test.mp4',
          steps: <ProcedureStep>[
            ProcedureStep('Fill the kettle', Icons.opacity_rounded, AppColors.secondary,
                detail: 'Fill under the tap'),
            ProcedureStep('Boil the water', Icons.local_fire_department_rounded,
                AppColors.terracotta,
                detail: 'Switch on the kettle'),
            ProcedureStep('Add the tea leaves', Icons.eco_rounded, AppColors.primary,
                detail: 'Into the teapot'),
            ProcedureStep('Add milk and sugar', Icons.water_drop_rounded, AppColors.plum,
                detail: 'Pour milk and stir sugar'),
          ],
        );
    }
  }


  // ── flow ───────────────────────────────────────────────────────────────

  void _startWatching() => setState(() => _phase = _Phase.watch);

  void _place(int stepIndex) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_placed.contains(stepIndex)) return;
    final int expected = _placed.length;
    _tracker.attempts++;
    setState(() {
      _hintedIndex = null;
      if (stepIndex == expected) {
        _tracker.correct++;
        _placed.add(stepIndex);
        _feedbackPositive = true;
        _feedback = _placed.length == _procedure.steps.length
            ? l.gameProcedureCompleteSequence
            : l.gameProcedureCorrectNext(_procedure.steps[stepIndex].label);
      } else {
        _tracker.mistakes++;
        _feedbackPositive = false;
        _feedback = l.gameProcedureNotQuite(_placed.isEmpty
            ? l.gameProcedureVeryBeginning
            : _procedure.steps[_placed.last].label);
      }
    });

    if (_placed.length == _procedure.steps.length) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _finish();
      });
    }
  }

  void _useHint() {
    if (_hintsLeft <= 0) return;
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() {
      _hintsLeft--;
      _tracker.hints++;
      _hintedIndex = _placed.length;
      _feedbackPositive = true;
      _feedback = l.gameProcedureHintNextStep(_procedure.steps[_placed.length].label);
    });
  }

  void _finish() {
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.procedure, _selectedLevel),
    );
    final AdaptiveDecision decision = _state.finishGame(GameId.procedure, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: decision,
          playedLevel: _selectedLevel,
        ),
      ),
    );
  }


  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.intro => _buildIntro(),
      _Phase.watch => _buildWatch(),
      _ => _buildRebuild(),
    };
  }

  Widget _buildIntro() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: _procedure.intro,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: l.gameProcedureShowSteps,
        icon: Icons.visibility_rounded,
        color: _game.accent,
        onPressed: _startWatching,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Level Selector ──────────────────────────────────────
            MmCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameMemoryCardsChooseLevel, style: AppText.overline),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 112,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 1,
                            title: 'Making tea',
                            subtitle: '4 steps • Video',
                            unlocked: 1 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 1,
                            onTap: (1 <= _maxUnlockedLevel) ? () => _changeLevel(1) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 2,
                            title: 'Washing clothes',
                            subtitle: '5 steps • Video',
                            unlocked: 2 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 2,
                            onTap: (2 <= _maxUnlockedLevel) ? () => _changeLevel(2) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 3,
                            title: 'Til pitha',
                            subtitle: '6 steps • Cards',
                            unlocked: 3 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 3,
                            onTap: (3 <= _maxUnlockedLevel) ? () => _changeLevel(3) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 4,
                            title: 'Til pitha (Adv)',
                            subtitle: '6 steps • Advanced',
                            unlocked: 4 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 4,
                            onTap: (4 <= _maxUnlockedLevel) ? () => _changeLevel(4) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 5,
                            title: 'Washing (Master)',
                            subtitle: '5 steps • Mastery',
                            unlocked: 5 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 5,
                            onTap: (5 <= _maxUnlockedLevel) ? () => _changeLevel(5) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Insets.md),

            // ── Selected Procedure Info ────────────────────────────
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameProcedureSelectedLabel, style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(_procedure.title, style: AppText.h1.sized(28)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      PillTag(
                        label: l.gameProcedureStepsCount(_procedure.steps.length),
                        color: _game.accent,
                        icon: Icons.format_list_numbered_rounded,
                      ),
                      if (_procedure.videoPath != null)
                        PillTag(
                          label: l.gameProcedureVideoAvailable,
                          color: AppColors.secondary,
                          icon: Icons.play_circle_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildWatch() {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool hasVideo = _procedure.videoPath != null;
    return GameShell(
      game: _game,
      level: _selectedLevel,
      stepLabel: hasVideo ? l.gameProcedureWatchVideoLabel : l.gameProcedureStudyStepsLabel,
      progress: 0.5,
      companionMessage: hasVideo
          ? l.gameProcedureWatchVideoMessage
          : l.gameProcedureReadThroughSteps(_procedure.title.toLowerCase()),
      companionState: CompanionState.thinking,
      bottom: BigButton(
        label: l.gameProcedureReadyToBuild,
        icon: Icons.check_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.build),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (hasVideo)
              _ProcedureVideoWidget(
                videoPath: _procedure.videoPath!,
              )
            else
              MmCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_procedure.title.toUpperCase(), style: AppText.overline),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _procedure.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StepCard(
                          step: _procedure.steps[i],
                          showIcon: true,
                          highlighted: false,
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


  Widget _buildRebuild() {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<int> remaining =
        _shuffled.where((int i) => !_placed.contains(i)).toList(growable: false);
    final bool done = _placed.length == _procedure.steps.length;

    return GameShell(
      game: _game,
      level: _selectedLevel,

      stepLabel: l.gameProcedurePlacedOfTotal(_placed.length, _procedure.steps.length),
      progress: _placed.length / _procedure.steps.length,
      hintsLeft: _hintsLeft,
      hintsTotal: 3,
      onHint: done ? null : _useHint,
      companionMessage: done
          ? l.gameProcedureWholeSequence(_state.patient.shortName)
          : _placed.isEmpty
              ? l.gameProcedureWhatComesFirst
              : l.gameProcedureWhatComesAfter(_procedure.steps[_placed.last].label),
      companionState: done ? CompanionState.celebrating : CompanionState.encouraging,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── the sequence being built ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: Corners.r(Corners.lg),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameProcedureSequenceSoFar, style: AppText.overline),
                  const SizedBox(height: 10),
                  for (int slot = 0; slot < _procedure.steps.length; slot++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Slot(
                        index: slot + 1,
                        step: slot < _placed.length ? _procedure.steps[_placed[slot]] : null,
                        highlight: slot == _placed.length,
                        accent: _game.accent,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: FeedbackBubble(
                  message: _feedback!,
                  positive: _feedbackPositive,
                ),
              ),
            if (!done) ...<Widget>[
              Text(l.gameProcedureTapNextStep, style: AppText.overline),
              const SizedBox(height: 10),
              for (final int i in remaining)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AttentionPulse(
                    active: _hintedIndex == i && !_state.reduceMotion,
                    color: AppColors.accent,
                    child: _StepCard(
                      step: _procedure.steps[i],
                      showIcon: !_lowAssistance,
                      highlighted: _hintedIndex == i,
                      onTap: () => _place(i),
                    ),

                  ),
                ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    this.onTap,
    this.showIcon = true,
    this.highlighted = false,
  });

  final ProcedureStep step;
  final VoidCallback? onTap;
  final bool showIcon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(
            color: highlighted ? AppColors.accent : AppColors.hairline,
            width: highlighted ? 2.4 : 1.4,
          ),
          boxShadow: AppColors.softShadow(y: 4, blur: 12, opacity: 0.05),
        ),
        child: Row(
          children: <Widget>[
            if (showIcon) ...<Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.12),
                  borderRadius: Corners.r(Corners.sm),
                ),
                child: Icon(step.icon, size: 26, color: step.color),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(step.label, style: AppText.patientBody.wght(700).sized(18)),
            ),
            const Icon(Icons.touch_app_rounded, size: 20, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}


class _Slot extends StatelessWidget {
  const _Slot({
    required this.index,
    required this.step,
    required this.highlight,
    required this.accent,
  });

  final int index;
  final ProcedureStep? step;
  final bool highlight;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool filled = step != null;
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: filled ? AppColors.successTint : Colors.transparent,
        borderRadius: Corners.r(Corners.sm),
        border: Border.all(
          color: filled
              ? AppColors.success.withValues(alpha: 0.4)
              : (highlight ? accent : AppColors.hairline),
          width: highlight && !filled ? 2.2 : 1.3,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: filled ? AppColors.success : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: filled
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text('$index', style: AppText.caption.wght(800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step?.label ?? (highlight ? l.gameProcedureChooseStepBelow : '—'),
              style: filled
                  ? AppText.body.wght(700)
                  : AppText.body.tint(highlight ? accent : AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcedureVideoWidget extends StatefulWidget {
  const _ProcedureVideoWidget({
    required this.videoPath,
  });

  final String videoPath;

  @override
  State<_ProcedureVideoWidget> createState() => _ProcedureVideoWidgetState();
}

class _ProcedureVideoWidgetState extends State<_ProcedureVideoWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
        }
      }).catchError((dynamic error) {
        debugPrint('Error initializing procedure video: $error');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_hasError) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: Corners.r(Corners.lg),
        ),
        child: Center(
          child: Text(l.gameProcedureVideoLoadError),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: Corners.r(Corners.lg),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return MmCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: Corners.r(Corners.md),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio > 0
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  VideoPlayer(_controller),
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton.icon(
                onPressed: () {
                  _controller.seekTo(Duration.zero);
                  _controller.play();
                  setState(() {});
                },
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: Text(l.gameProcedureReplayVideo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
