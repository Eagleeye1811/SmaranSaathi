import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/companion.dart';
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
  late final int _maxUnlockedLevel = _state.levelOf(GameId.melody);
  late int _selectedLevel;

  static const int _roundsPerSession = 3;

  _Phase _phase = _Phase.intro;
  int _round = 0;
  List<int> _sequence = <int>[];
  final List<int> _input = <int>[];
  int? _activeIndex;
  bool _roundCorrect = true;
  Timer? _playTimer;

  int get _sequenceLength => switch (_selectedLevel) {
        1 => 2,
        2 => 3,
        3 => 4,
        4 => 4,
        _ => 5,
      };

  Duration get _beat => _selectedLevel >= 4
      ? const Duration(milliseconds: 460)
      : const Duration(milliseconds: 720);


  final Map<String, AudioPlayer> _audioPlayers = <String, AudioPlayer>{};

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.melody);
    _sequence = _makeSequence(0);
    _initAudio();
  }

  void _changeLevel(int lvl) {
    setState(() {
      _selectedLevel = lvl;
      _sequence = _makeSequence(_round);
    });
  }


  void _initAudio() {
    for (final Instrument ins in instruments) {
      final AudioPlayer player = AudioPlayer();
      _audioPlayers[ins.id] = player;
    }
  }

  void _playSound(Instrument ins) {
    try {
      final AudioPlayer? player = _audioPlayers[ins.id];
      if (player != null) {
        player.stop();
        player.setVolume(1.0);
        player.play(AssetSource('audio/${ins.id}.wav'), volume: 1.0);
      }
    } catch (e) {
      debugPrint('Error playing sound for ${ins.id}: $e');
    }
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    for (final AudioPlayer player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }

  List<int> _makeSequence(int round) {
    // Deterministic so the demo replays identically.
    int seed = (_selectedLevel * 977 + round * 313 + 7) & 0x7fffffff;
    final List<int> out = <int>[];
    for (int i = 0; i < _sequenceLength + (round > 1 && _selectedLevel >= 3 ? 1 : 0); i++) {
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
      _playSound(instruments[idx]);
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
    _playSound(instruments[index]);
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
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.melody, _selectedLevel),
    );
    final AdaptiveDecision d = _state.finishGame(GameId.melody, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _selectedLevel,
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
      level: _selectedLevel,
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
            if (_phase == _Phase.intro) ...<Widget>[
              MmCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('CHOOSE LEVEL', style: AppText.overline),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 96,
                            child: _LevelOptionChip(
                              levelNum: 1,
                              title: 'Easy',
                              subtitle: '2 notes',
                              unlocked: 1 <= _maxUnlockedLevel,
                              selected: _selectedLevel == 1,
                              onTap: (1 <= _maxUnlockedLevel) ? () => _changeLevel(1) : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: _LevelOptionChip(
                              levelNum: 2,
                              title: 'Medium',
                              subtitle: '3 notes',
                              unlocked: 2 <= _maxUnlockedLevel,
                              selected: _selectedLevel == 2,
                              onTap: (2 <= _maxUnlockedLevel) ? () => _changeLevel(2) : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: _LevelOptionChip(
                              levelNum: 3,
                              title: 'Hard',
                              subtitle: '4 notes',
                              unlocked: 3 <= _maxUnlockedLevel,
                              selected: _selectedLevel == 3,
                              onTap: (3 <= _maxUnlockedLevel) ? () => _changeLevel(3) : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: _LevelOptionChip(
                              levelNum: 4,
                              title: 'Expert',
                              subtitle: '4 notes · Fast',
                              unlocked: 4 <= _maxUnlockedLevel,
                              selected: _selectedLevel == 4,
                              onTap: (4 <= _maxUnlockedLevel) ? () => _changeLevel(4) : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: _LevelOptionChip(
                              levelNum: 5,
                              title: 'Mastery',
                              subtitle: '5 notes · Fast',
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
            ],
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

            // ── instruments (Inverted Triangle Layout) ──────────────────────
            Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _InstrumentTile(
                        instrument: instruments[0],
                        active: _activeIndex == 0,
                        enabled: _phase == _Phase.listening,
                        onTap: () => _tap(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InstrumentTile(
                        instrument: instruments[1],
                        active: _activeIndex == 1,
                        enabled: _phase == _Phase.listening,
                        onTap: () => _tap(1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    child: _InstrumentTile(
                      instrument: instruments[2],
                      active: _activeIndex == 2,
                      enabled: _phase == _Phase.listening,
                      onTap: () => _tap(2),
                    ),
                  ),
                ),
              ],
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

  static const Color activeColor = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Corners.r(Corners.xl),
          border: Border.all(
            color: active ? activeColor : AppColors.hairline,
            width: active ? 3.0 : 1.2,
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ]
              : AppColors.softShadow(y: 2, blur: 8, opacity: 0.03),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 86,
              height: 86,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Lottie.asset(
                  'assets/animations/${instrument.id}.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: active || enabled,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              instrument.name,
              style: AppText.h3.sized(17).wght(800).tint(
                active ? activeColor : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelOptionChip extends StatelessWidget {
  const _LevelOptionChip({
    required this.levelNum,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final int levelNum;
  final String title;
  final String subtitle;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: unlocked
              ? (selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceMuted)
              : AppColors.surfaceMuted.withValues(alpha: 0.4),
          borderRadius: Corners.r(Corners.md),
          border: Border.all(
            color: unlocked
                ? (selected ? AppColors.primary : AppColors.hairline)
                : AppColors.hairline.withValues(alpha: 0.4),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Level $levelNum',
                  style: AppText.caption.wght(800).tint(
                        unlocked
                            ? (selected ? AppColors.primary : AppColors.inkMuted)
                            : AppColors.inkMuted.withValues(alpha: 0.5),
                      ),
                ),
                if (!unlocked) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: AppColors.inkMuted.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppText.caption.sized(12).wght(700).tint(
                    unlocked
                        ? (selected ? AppColors.primary : AppColors.ink)
                        : AppColors.inkMuted.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? subtitle : 'Locked 🔒',
              style: AppText.caption.sized(10).tint(
                    unlocked ? AppColors.inkMuted : AppColors.inkMuted.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}






