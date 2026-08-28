import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/illustration.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';

class Instrument {
  const Instrument({
    required this.id,
    required this.name,
    required this.description,
    required this.sceneId,
    required this.color,
    required this.pattern,
    required this.haptic,
  });

  final String id;
  final String name;
  final String description;
  final String sceneId;
  final Color color;

  /// Relative bar heights used by the on-screen waveform, so each instrument
  /// has a visibly distinct "voice" as well as an audible one.
  final List<double> pattern;
  final HapticKind haptic;
}

enum HapticKind { heavy, medium, light }

/// Melody of the Valleys — auditory sequence memory using North-Eastern
/// instruments.
///
/// Audio playback needs a plugin, which this prototype deliberately avoids, so
/// each instrument is rendered as a distinct animated waveform plus its own
/// haptic signature. The memory task itself is unchanged.
class MelodyGame extends StatefulWidget {
  const MelodyGame({super.key});

  @override
  State<MelodyGame> createState() => _MelodyGameState();
}

enum _Phase { intro, playing, listening, feedback }

class _MelodyGameState extends State<MelodyGame> {
  static const List<Instrument> instruments = <Instrument>[
    Instrument(
      id: 'dhol',
      name: 'Dhol',
      description: 'The deep Bihu drum',
      sceneId: 'dhol',
      color: AppColors.terracotta,
      pattern: <double>[1.0, 0.4, 0.85, 0.3, 0.2],
      haptic: HapticKind.heavy,
    ),
    Instrument(
      id: 'pepa',
      name: 'Pepa',
      description: 'The buffalo-horn pipe',
      sceneId: 'pepa',
      color: AppColors.accent,
      pattern: <double>[0.35, 0.7, 0.9, 0.85, 0.6],
      haptic: HapticKind.medium,
    ),
    Instrument(
      id: 'gogona',
      name: 'Gogona',
      description: 'The bamboo jaw harp',
      sceneId: 'gogona',
      color: AppColors.primary,
      pattern: <double>[0.6, 0.25, 0.7, 0.25, 0.65],
      haptic: HapticKind.light,
    ),
  ];

  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.melody);
  late final AppState _state = AppScope.read(context);
  late final int _level = _state.levelOf(GameId.melody);

  static const int _roundsPerSession = 3;

  _Phase _phase = _Phase.intro;
  int _round = 0;
  List<int> _sequence = <int>[];
  final List<int> _input = <int>[];
  int? _activeIndex;
  bool _roundCorrect = true;
  Timer? _playTimer;

  int get _sequenceLength => switch (_level) {
        1 => 2,
        2 => 3,
        3 => 4,
        4 => 4,
        _ => 5,
      };

  Duration get _beat => _level >= 4
      ? const Duration(milliseconds: 460)
      : const Duration(milliseconds: 720);

  @override
  void initState() {
    super.initState();
    _sequence = _makeSequence(0);
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  List<int> _makeSequence(int round) {
    // Deterministic so the demo replays identically.
    int seed = (_level * 977 + round * 313 + 7) & 0x7fffffff;
    final List<int> out = <int>[];
    for (int i = 0; i < _sequenceLength + (round > 1 && _level >= 3 ? 1 : 0); i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      int next = seed % instruments.length;
      if (out.isNotEmpty && next == out.last && instruments.length > 1) {
        next = (next + 1) % instruments.length;
      }
      out.add(next);
    }
    return out;
  }

  void _play() {
    setState(() {
      _phase = _Phase.playing;
      _input.clear();
      _activeIndex = null;
    });
    int i = 0;
    _playTimer?.cancel();
    _playTimer = Timer.periodic(_beat, (Timer t) {
      if (!mounted) return;
      if (i >= _sequence.length) {
        t.cancel();
        setState(() {
          _activeIndex = null;
          _phase = _Phase.listening;
        });
        return;
      }
      final int idx = _sequence[i];
      setState(() => _activeIndex = idx);
      _buzz(instruments[idx]);
      Future<void>.delayed(
        Duration(milliseconds: (_beat.inMilliseconds * 0.62).round()),
        () {
          if (mounted && _phase == _Phase.playing) setState(() => _activeIndex = null);
        },
      );
      i++;
    });
  }

  void _buzz(Instrument ins) {
    if (_state.reduceMotion) return;
    switch (ins.haptic) {
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.light:
        HapticFeedback.selectionClick();
    }
  }

  void _tap(int index) {
    if (_phase != _Phase.listening) return;
    _buzz(instruments[index]);
    setState(() {
      _activeIndex = index;
      _input.add(index);
    });
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (mounted) setState(() => _activeIndex = null);
    });

    final int pos = _input.length - 1;
    _tracker.attempts++;
    if (_sequence[pos] == index) {
      _tracker.correct++;
    } else {
      _tracker.mistakes++;
      _roundCorrect = false;
    }

    if (_input.length == _sequence.length) {
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _phase = _Phase.feedback);
      });
    }
  }

  void _nextRound() {
    if (_round + 1 >= _roundsPerSession) {
      _finish();
      return;
    }
    setState(() {
      _round++;
      _roundCorrect = true;
      _sequence = _makeSequence(_round);
      _input.clear();
    });
    _play();
  }

  void _replay() {
    _tracker.hints++;
    _play();
  }

  void _finish() {
    _playTimer?.cancel();
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.melody, _level),
    );
    final AdaptiveDecision d = _state.finishGame(GameId.melody, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _level,
          highlights: <({String label, String value})>[
            (label: 'Tunes played', value: '$_roundsPerSession'),
            (label: 'Notes in a tune', value: '$_sequenceLength'),
            (label: 'Replays used', value: '${_tracker.hints}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String message = switch (_phase) {
      _Phase.intro => 'Listen to the tune I play, then play it back to me.',
      _Phase.playing => 'Listen…',
      _Phase.listening => 'Now you. Play the tune back.',
      _Phase.feedback => _roundCorrect
          ? 'That is exactly right. Beautiful.'
          : 'Close! Let us try another tune.',
    };

    return GameShell(
      game: _game,
      level: _level,
      stepLabel: 'Tune ${_round + 1} of $_roundsPerSession',
      progress: (_round + (_phase == _Phase.feedback ? 1 : 0.4)) / _roundsPerSession,
      companionMessage: message,
      companionState: switch (_phase) {
        _Phase.playing => CompanionState.thinking,
        _Phase.listening => CompanionState.listening,
        _Phase.feedback =>
          _roundCorrect ? CompanionState.celebrating : CompanionState.encouraging,
        _ => CompanionState.happy,
      },
      bottom: _buildBottom(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── the tune being played / entered ──────────────────────────
            MmCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.graphic_eq_rounded, size: 17, color: _game.accent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _phase == _Phase.listening || _phase == _Phase.feedback
                              ? 'YOUR TUNE'
                              : 'THE TUNE',
                          style: AppText.overline.tint(_game.accent),
                        ),
                      ),
                      Text('${_sequence.length} notes', style: AppText.caption),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SequenceStrip(
                    sequence: _sequence,
                    input: _input,
                    reveal: _phase == _Phase.feedback,
                    playingIndex: _phase == _Phase.playing ? _activeIndex : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),

            // ── instruments ─────────────────────────────────────────────
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final bool row = c.maxWidth > 520;
                final List<Widget> tiles = <Widget>[
                  for (int i = 0; i < instruments.length; i++)
                    _InstrumentTile(
                      instrument: instruments[i],
                      active: _activeIndex == i,
                      enabled: _phase == _Phase.listening,
                      onTap: () => _tap(i),
                    ),
                ];
                if (row) {
                  return Row(
                    children: <Widget>[
                      for (int i = 0; i < tiles.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == tiles.length - 1 ? 0 : 12),
                            child: tiles[i],
                          ),
                        ),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final Widget t in tiles)
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: t),
                  ],
                );
              },
            ),
            const SizedBox(height: Insets.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: Corners.r(Corners.sm),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.volume_up_rounded, size: 17, color: AppColors.inkMuted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'In this prototype each instrument is shown as its own waveform and '
                      'vibration. The full product plays real dhol, pepa and gogona recordings.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottom() {
    switch (_phase) {
      case _Phase.intro:
        return BigButton(
          label: 'Play the tune',
          icon: Icons.play_arrow_rounded,
          color: _game.accent,
          onPressed: _play,
        );
      case _Phase.playing:
        return BigButton(
          label: 'Listening…',
          icon: Icons.graphic_eq_rounded,
          color: _game.accent,
          onPressed: null,
        );
      case _Phase.listening:
        return Row(
          children: <Widget>[
            Expanded(
              child: BigButton(
                label: 'Play it again',
                icon: Icons.replay_rounded,
                color: _game.accent,
                outlined: true,
                height: 62,
                onPressed: _replay,
              ),
            ),
          ],
        );
      case _Phase.feedback:
        return BigButton(
          label: _round + 1 >= _roundsPerSession ? 'Finish' : 'Next tune',
          icon: Icons.arrow_forward_rounded,
          color: _game.accent,
          onPressed: _nextRound,
        );
    }
  }
}

class _SequenceStrip extends StatelessWidget {
  const _SequenceStrip({
    required this.sequence,
    required this.input,
    required this.reveal,
    required this.playingIndex,
  });

  final List<int> sequence;
  final List<int> input;
  final bool reveal;
  final int? playingIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < sequence.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == sequence.length - 1 ? 0 : 8),
              child: _slot(i),
            ),
          ),
      ],
    );
  }

  Widget _slot(int i) {
    final bool entered = i < input.length;
    final bool correct = entered && input[i] == sequence[i];
    final Instrument? shown = entered
        ? _MelodyGameState.instruments[input[i]]
        : (reveal ? _MelodyGameState.instruments[sequence[i]] : null);

    Color border = AppColors.hairline;
    if (entered) border = correct ? AppColors.success : AppColors.danger;

    return AnimatedContainer(
      duration: Motion.quick,
      height: 62,
      decoration: BoxDecoration(
        color: shown == null ? AppColors.surfaceMuted : shown.color.withValues(alpha: 0.12),
        borderRadius: Corners.r(Corners.sm),
        border: Border.all(color: border, width: entered ? 2 : 1.2),
      ),
      child: Center(
        child: shown == null
            ? Text('${i + 1}', style: AppText.body.wght(700).tint(AppColors.inkMuted))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    entered && !correct ? Icons.close_rounded : Icons.music_note_rounded,
                    size: 20,
                    color: entered && !correct ? AppColors.danger : shown.color,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shown.name,
                    style: AppText.caption.sized(11).wght(700).tint(shown.color),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InstrumentTile extends StatelessWidget {
  const _InstrumentTile({
    required this.instrument,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final Instrument instrument;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      scale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? instrument.color.withValues(alpha: 0.16) : Colors.white,
          borderRadius: Corners.r(Corners.lg),
          border: Border.all(
            color: active ? instrument.color : AppColors.hairline,
            width: active ? 3 : 1.4,
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: instrument.color.withValues(alpha: 0.34),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ]
              : AppColors.softShadow(y: 4, blur: 12, opacity: 0.05),
        ),
        child: Row(
          children: <Widget>[
            AnimatedScale(
              scale: active ? 1.07 : 1,
              duration: const Duration(milliseconds: 180),
              child: SceneImage(
                sceneId: instrument.sceneId,
                size: 66,
                radius: Corners.md,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(instrument.name, style: AppText.h3.wght(800)),
                  const SizedBox(height: 2),
                  Text(instrument.description, style: AppText.bodySmall),
                  const SizedBox(height: 10),
                  _Waveform(
                    pattern: instrument.pattern,
                    color: instrument.color,
                    active: active,
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

class _Waveform extends StatelessWidget {
  const _Waveform({required this.pattern, required this.color, required this.active});

  final List<double> pattern;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < pattern.length * 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200 + i * 24),
                curve: Curves.easeOut,
                width: 4,
                height: active
                    ? 6 + pattern[i % pattern.length] * 20
                    : 4 + pattern[i % pattern.length] * 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: active ? 0.95 : 0.35),
                  borderRadius: Corners.r(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
