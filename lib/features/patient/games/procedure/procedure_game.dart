import 'package:flutter/material.dart';

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
    this.personal = false,
  });

  final String title;
  final String intro;
  final List<ProcedureStep> steps;
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
  late final int _level = _state.levelOf(GameId.procedure);
  late final Procedure _procedure = _procedureFor(_level, _state.patient.shortName);

  _Phase _phase = _Phase.intro;
  int _watchIndex = 0;
  final List<int> _placed = <int>[];
  late final List<int> _shuffled;
  String? _feedback;
  bool _feedbackPositive = true;
  int _hintsLeft = 3;
  int? _hintedIndex;

  /// Level 4 and above remove the picture-tile assistance during rebuilding.
  bool get _lowAssistance => _level >= 4;

  @override
  void initState() {
    super.initState();
    final List<int> order = List<int>.generate(_procedure.steps.length, (int i) => i);
    // A deterministic shuffle keeps demo runs reproducible.
    _shuffled = _deterministicShuffle(order, _level * 31 + order.length);
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
      case 1:
        return const Procedure(
          title: 'Making tea',
          intro: 'Let us try something you know well. Watch how the tea is made.',
          steps: <ProcedureStep>[
            ProcedureStep('Boil the water', Icons.local_fire_department_rounded,
                AppColors.terracotta,
                detail: 'On the stove, until it bubbles'),
            ProcedureStep('Add the tea leaves', Icons.eco_rounded, AppColors.primary,
                detail: 'Two spoons'),
            ProcedureStep('Add milk and sugar', Icons.water_drop_rounded, AppColors.secondary),
            ProcedureStep('Pour and serve', Icons.emoji_food_beverage_rounded, AppColors.accent),
          ],
        );
      case 2:
        return const Procedure(
          title: 'Making tea',
          intro: 'Let us try something you know well. Watch how the tea is made.',
          steps: <ProcedureStep>[
            ProcedureStep('Fill the kettle', Icons.opacity_rounded, AppColors.secondary),
            ProcedureStep('Boil the water', Icons.local_fire_department_rounded,
                AppColors.terracotta),
            ProcedureStep('Add the tea leaves', Icons.eco_rounded, AppColors.primary),
            ProcedureStep('Add milk and sugar', Icons.water_drop_rounded, AppColors.plum),
            ProcedureStep('Pour and serve', Icons.emoji_food_beverage_rounded, AppColors.accent),
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
      default:
        return Procedure(
          title: 'Dressing the loom',
          personal: true,
          intro:
              '$name used to weave traditional patterns. Let us see what you remember about setting up the loom.',
          steps: const <ProcedureStep>[
            ProcedureStep('Wind the yarn onto the beam', Icons.rotate_right_rounded,
                AppColors.terracotta),
            ProcedureStep('Draw each thread through the heddle', Icons.linear_scale_rounded,
                AppColors.primary),
            ProcedureStep('Pass the threads through the reed', Icons.view_week_rounded,
                AppColors.secondary),
            ProcedureStep('Tie the warp to the front beam', Icons.link_rounded, AppColors.plum),
            ProcedureStep('Fill the shuttle with weft', Icons.swap_horiz_rounded,
                AppColors.accent),
            ProcedureStep('Weave the first row', Icons.grid_on_rounded, AppColors.indigo),
          ],
        );
    }
  }

  // ── flow ───────────────────────────────────────────────────────────────

  void _startWatching() => setState(() => _phase = _Phase.watch);

  void _nextWatch() {
    if (_watchIndex < _procedure.steps.length - 1) {
      setState(() => _watchIndex++);
    } else {
      setState(() => _phase = _Phase.build);
    }
  }

  void _place(int stepIndex) {
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
            ? 'That is the whole sequence. Beautifully done.'
            : 'Yes — "${_procedure.steps[stepIndex].label}" comes next.';
      } else {
        _tracker.mistakes++;
        _feedbackPositive = false;
        _feedback = 'Not quite. Think about what happens right after '
            '"${_placed.isEmpty ? 'the very beginning' : _procedure.steps[_placed.last].label}".';
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
    setState(() {
      _hintsLeft--;
      _tracker.hints++;
      _hintedIndex = _placed.length;
      _feedbackPositive = true;
      _feedback = 'The next step is "${_procedure.steps[_placed.length].label}".';
    });
  }

  void _finish() {
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.procedure, _level),
    );
    final AdaptiveDecision decision = _state.finishGame(GameId.procedure, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: decision,
          playedLevel: _level,
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
    return GameShell(
      game: _game,
      level: _level,
      companionMessage: _procedure.intro,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: 'Show me the steps',
        icon: Icons.visibility_rounded,
        color: _game.accent,
        onPressed: _startWatching,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('TODAY\'S PROCEDURE', style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(_procedure.title, style: AppText.h1.sized(28)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      PillTag(
                        label: '${_procedure.steps.length} steps',
                        color: _game.accent,
                        icon: Icons.format_list_numbered_rounded,
                      ),
                      if (_procedure.personal)
                        const PillTag(
                          label: 'From your own life',
                          color: AppColors.terracotta,
                          icon: Icons.favorite_rounded,
                        ),
                    ],
                  ),
                  if (_lowAssistance) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: Corners.r(Corners.sm),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.tips_and_updates_rounded,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This time there will be fewer pictures to help you.',
                              style: AppText.bodySmall.tint(AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatch() {
    final ProcedureStep step = _procedure.steps[_watchIndex];
    final bool last = _watchIndex == _procedure.steps.length - 1;
    return GameShell(
      game: _game,
      level: _level,
      stepLabel: 'Step ${_watchIndex + 1} of ${_procedure.steps.length}',
      progress: (_watchIndex + 1) / _procedure.steps.length,
      companionMessage: 'Watch carefully. You will put these back in order in a moment.',
      companionState: CompanionState.thinking,
      bottom: BigButton(
        label: last ? 'I am ready' : 'Next step',
        icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
        color: _game.accent,
        onPressed: _nextWatch,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          children: <Widget>[
            AnimatedSwitcher(
              duration: Motion.normal,
              transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                      .animate(a),
                  child: child,
                ),
              ),
              child: _StepCard(
                key: ValueKey<int>(_watchIndex),
                index: _watchIndex + 1,
                step: step,
                big: true,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _procedure.steps.length; i++)
                  AnimatedContainer(
                    duration: Motion.normal,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _watchIndex ? 26 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: i <= _watchIndex
                          ? _game.accent
                          : _game.accent.withValues(alpha: 0.2),
                      borderRadius: Corners.r(Corners.pill),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRebuild() {
    final List<int> remaining =
        _shuffled.where((int i) => !_placed.contains(i)).toList(growable: false);
    final bool done = _placed.length == _procedure.steps.length;

    return GameShell(
      game: _game,
      level: _level,
      stepLabel: '${_placed.length} of ${_procedure.steps.length} placed',
      progress: _placed.length / _procedure.steps.length,
      hintsLeft: _hintsLeft,
      hintsTotal: 3,
      onHint: done ? null : _useHint,
      companionMessage: done
          ? 'That is the whole sequence, ${_state.patient.shortName}.'
          : _placed.isEmpty
              ? 'What comes first?'
              : 'And what comes after "${_procedure.steps[_placed.last].label}"?',
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
                  Text('THE SEQUENCE SO FAR', style: AppText.overline),
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
              Text('TAP THE STEP THAT COMES NEXT', style: AppText.overline),
              const SizedBox(height: 10),
              for (final int i in remaining)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AttentionPulse(
                    active: _hintedIndex == i && !_state.reduceMotion,
                    color: AppColors.accent,
                    child: _StepCard(
                      step: _procedure.steps[i],
                      big: false,
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
    super.key,
    required this.step,
    required this.big,
    this.index,
    this.onTap,
    this.showIcon = true,
    this.highlighted = false,
  });

  final ProcedureStep step;
  final bool big;
  final int? index;
  final VoidCallback? onTap;
  final bool showIcon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (big) {
      return MmCard(
        padding: const EdgeInsets.all(Insets.lg),
        shadow: AppColors.liftShadow(),
        child: Column(
          children: <Widget>[
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, size: 56, color: step.color),
            ),
            const SizedBox(height: Insets.md),
            if (index != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: step.color,
                  borderRadius: Corners.r(Corners.pill),
                ),
                child: Text('Step $index',
                    style: AppText.label.tint(Colors.white).wght(800)),
              ),
            const SizedBox(height: 12),
            Text(step.label, textAlign: TextAlign.center, style: AppText.h2.sized(24)),
            if (step.detail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(step.detail, textAlign: TextAlign.center, style: AppText.bodySmall),
            ],
          ],
        ),
      );
    }

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
              step?.label ?? (highlight ? 'Choose this step below' : '—'),
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
