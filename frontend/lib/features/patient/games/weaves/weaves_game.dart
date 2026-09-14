import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/motifs.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';
import '../widgets/game_level_path_map.dart';

/// A textile whose motifs the patient rebuilds.
class Textile {
  const Textile({
    required this.name,
    required this.origin,
    required this.palette,
    required this.motifs,
  });

  final String name;
  final String origin;
  final List<Color> palette;

  /// Three tile seeds: the diagonal motif, the light ground, the accent.
  final List<int> motifs;
}

/// Weaves of the Hills — attention and visual pattern memory, built from the
/// geometry of North-Eastern handloom borders.
class WeavesGame extends StatefulWidget {
  const WeavesGame({super.key});

  @override
  State<WeavesGame> createState() => _WeavesGameState();
}

enum _Phase { intro, preview, hidden, choose, solved }

class _WeavesGameState extends State<WeavesGame> {
  static const List<Textile> textiles = <Textile>[
    Textile(
      name: 'Gamosa border',
      origin: 'Assam',
      palette: <Color>[Color(0xFFFCF7EE), Color(0xFFC0392B), Color(0xFFE0913A)],
      motifs: <int>[0, 2, 5],
    ),
    Textile(
      name: 'Phanek stripe',
      origin: 'Manipur',
      palette: <Color>[Color(0xFF2E3F6B), Color(0xFFE0913A), Color(0xFFF3E4D0)],
      motifs: <int>[3, 1, 4],
    ),
    Textile(
      name: 'Hill shawl',
      origin: 'Nagaland & Mizoram',
      palette: <Color>[Color(0xFFF1E6D2), Color(0xFF2E7D6B), Color(0xFFC9694F)],
      motifs: <int>[4, 5, 0],
    ),
    Textile(
      name: 'Eri weave',
      origin: 'Meghalaya',
      palette: <Color>[Color(0xFF7A5680), Color(0xFF3F5B86), Color(0xFFEFE3CE)],
      motifs: <int>[1, 3, 2],
    ),
  ];

  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.weaves);
  late final AppState _state = AppScope.read(context);
  late final int _maxUnlockedLevel = _state.levelOf(GameId.weaves);
  late int _selectedLevel;

  static const int _roundsPerSession = 3;

  _Phase _phase = _Phase.intro;

  int _round = 0;
  Timer? _previewTimer;
  int _previewLeft = 5;
  bool _justSolved = false;
  String? _feedback;
  bool _feedbackPositive = true;

  late Textile _textile;
  late List<List<int>> _grid;
  late List<int> _blanks;
  late List<int> _options;
  final Map<int, int> _filled = <int, int>{};

  int get _gridSize => _selectedLevel >= 5 ? 4 : 3;
  int get _blankCount => _selectedLevel >= 4 ? 2 : 1;

  /// From level 3 the pattern is hidden before the patient rebuilds it.
  bool get _hidesPattern => _selectedLevel >= 2;
  int get _previewSeconds => _selectedLevel >= 4 ? 4 : 6;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.weaves);
    _setupRound();
  }

  void _changeLevel(int lvl) {
    setState(() {
      _selectedLevel = lvl;
      _setupRound();
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _setupRound() {
    _textile = textiles[(_selectedLevel + _round) % textiles.length];
    final int n = _gridSize;
    _grid = List<List<int>>.generate(n, (int r) {
      return List<int>.generate(n, (int c) {
        if (r == c || r + c == n - 1) return _textile.motifs[0];
        return (r + c).isEven ? _textile.motifs[1] : _textile.motifs[2];
      });
    });

    // Deterministic blank selection, avoiding the very centre so the motif
    // stays readable.
    final List<int> cells = List<int>.generate(n * n, (int i) => i);
    int seed = (_selectedLevel * 613 + _round * 271 + 41) & 0x7fffffff;
    _blanks = <int>[];
    while (_blanks.length < _blankCount) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final int pick = cells[seed % cells.length];
      if (!_blanks.contains(pick)) _blanks.add(pick);
    }

    final int answer = _grid[_blanks.first ~/ n][_blanks.first % n];
    final Set<int> opts = <int>{answer};
    int s2 = seed;
    while (opts.length < 4) {
      s2 = (s2 * 1103515245 + 12345) & 0x7fffffff;
      opts.add(s2 % 6);
    }
    _options = opts.toList()..shuffle(math.Random(seed));

    _filled.clear();
    _feedback = null;
    _justSolved = false;
    _previewLeft = _previewSeconds;

    if (_hidesPattern) {
      _phase = _Phase.preview;
      _previewTimer?.cancel();
      _previewTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted) return;
        setState(() => _previewLeft--);
        if (_previewLeft <= 0) {
          t.cancel();
          setState(() => _phase = _Phase.choose);
        }
      });
    } else {
      _phase = _Phase.choose;
    }
  }

  int _answerFor(int cell) => _grid[cell ~/ _gridSize][cell % _gridSize];

  int? get _activeBlank {
    for (final int b in _blanks) {
      if (!_filled.containsKey(b)) return b;
    }
    return null;
  }

  void _choose(int seedOption) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int? blank = _activeBlank;
    if (blank == null) return;
    _tracker.attempts++;
    final bool correct = seedOption == _answerFor(blank);
    setState(() {
      if (correct) {
        _tracker.correct++;
        _filled[blank] = seedOption;
        _feedbackPositive = true;
        _feedback = l.gameWeavesFeedbackCorrect;
        if (_activeBlank == null) {
          _phase = _Phase.solved;
          _justSolved = true;
        } else {
          // Re-roll options for the next blank in the same round.
          final int answer = _answerFor(_activeBlank!);
          final Set<int> opts = <int>{answer};
          int s = (_round * 733 + _filled.length * 97 + 13) & 0x7fffffff;
          while (opts.length < 4) {
            s = (s * 1103515245 + 12345) & 0x7fffffff;
            opts.add(s % 6);
          }
          _options = opts.toList()..shuffle(math.Random(s));
        }
      } else {
        _tracker.mistakes++;
        _feedbackPositive = false;
        _feedback = l.gameWeavesFeedbackWrong;
      }
    });
  }

  void _peek() {
    if (_phase != _Phase.choose || !_hidesPattern) return;
    _tracker.hints++;
    setState(() {
      _phase = _Phase.preview;
      _previewLeft = 2;
    });
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _previewLeft--);
      if (_previewLeft <= 0) {
        t.cancel();
        setState(() => _phase = _Phase.choose);
      }
    });
  }

  void _nextRound() {
    if (_round + 1 >= _roundsPerSession) {
      _finish();
      return;
    }
    setState(() {
      _round++;
      _setupRound();
    });
  }

  void _finish() {
    final AppLocalizations l = AppLocalizations.of(context);
    _previewTimer?.cancel();
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.weaves, _selectedLevel),
    );
    final AdaptiveDecision d = _state.finishGame(GameId.weaves, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _selectedLevel,
          highlights: <({String label, String value})>[
            (label: l.gameWeavesPatternsRebuilt, value: '$_roundsPerSession'),
            (label: l.gameWeavesPiecesPlaced, value: '${_tracker.correct}'),
            (label: l.gameWeavesSecondLooks, value: '${_tracker.hints}'),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) return _buildIntro();

    final AppLocalizations l = AppLocalizations.of(context);
    final bool showPattern = _phase != _Phase.choose || !_hidesPattern;
    final String message = switch (_phase) {
      _Phase.preview => l.gameWeavesLookCarefully,
      _Phase.hidden => l.gameWeavesNowRebuild,
      _Phase.choose => l.gameWeavesWhichPiece,
      _Phase.solved => l.gameWeavesBeautiful,
      _ => '',
    };

    return Stack(
      children: <Widget>[
        GameShell(
          game: _game,
          level: _selectedLevel,

          stepLabel: l.gameWeavesPatternOfTotal(_round + 1, _roundsPerSession),
          progress: (_round + (_phase == _Phase.solved ? 1 : 0.45)) / _roundsPerSession,
          hintsLeft: _hidesPattern ? (3 - _tracker.hints).clamp(0, 3) : null,
          hintsTotal: _hidesPattern ? 3 : null,
          onHint: _tracker.hints < 3 ? _peek : null,
          companionMessage: message,
          companionState: switch (_phase) {
            _Phase.preview => CompanionState.thinking,
            _Phase.solved => CompanionState.celebrating,
            _ => CompanionState.encouraging,
          },
          bottom: _phase == _Phase.solved
              ? BigButton(
                  label: _round + 1 >= _roundsPerSession
                      ? l.gameWeavesFinish
                      : l.gameWeavesNextPattern,
                  icon: Icons.arrow_forward_rounded,
                  color: _game.accent,
                  onPressed: _nextRound,
                )
              : (_phase == _Phase.preview && _hidesPattern
                  ? BigButton(
                      label: l.gameWeavesHidingIn(_previewLeft),
                      icon: Icons.visibility_rounded,
                      color: _game.accent,
                      onPressed: null,
                    )
                  : null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── the textile ──────────────────────────────────────────
                MmCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppColors.liftShadow(),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(_textile.name, style: AppText.h3.wght(800)),
                                const SizedBox(height: 2),
                                Text(_textile.origin, style: AppText.caption),
                              ],
                            ),
                          ),
                          if (_phase == _Phase.preview)
                            PillTag(
                              label: l.gameWeavesMemorise(_previewLeft),
                              color: AppColors.accent,
                              icon: Icons.visibility_rounded,
                              dense: true,
                            )
                          else
                            PillTag(
                              label: l.gameWeavesPlacedCount(_filled.length, _blanks.length),
                              color: _game.accent,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: _PatternGrid(
                            grid: _grid,
                            palette: _textile.palette,
                            blanks: _blanks,
                            filled: _filled,
                            revealed: showPattern,
                            activeBlank: _activeBlank,
                            accent: _game.accent,
                          ),
                        ),
                      ),
                      if (!showPattern) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.visibility_off_rounded,
                                size: 16, color: AppColors.inkMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.gameWeavesCoveredHint,
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // A woven selvedge, drawn under every textile.
                      const SizedBox(height: 14),
                      WovenStrip(height: 12, colors: _textile.palette.reversed.toList()),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),

                if (_feedback != null) ...<Widget>[
                  FeedbackBubble(message: _feedback!, positive: _feedbackPositive),
                  const SizedBox(height: Insets.md),
                ],

                // ── candidate pieces ─────────────────────────────────────
                if (_phase == _Phase.choose) ...<Widget>[
                  Text(l.gameWeavesChooseMissingPiece, style: AppText.overline),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < _options.length; i++)
                        Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: i == _options.length - 1 ? 0 : 10),
                            child: Pressable(
                              onTap: () => _choose(_options[i]),
                              scale: 0.94,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: Corners.r(Corners.md),
                                  border: Border.all(color: AppColors.hairline, width: 1.4),
                                  boxShadow:
                                      AppColors.softShadow(y: 4, blur: 10, opacity: 0.05),
                                ),
                                child: WeaveTile(
                                  seed: _options[i],
                                  palette: _textile.palette,
                                  radius: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (_justSolved && !_state.reduceMotion)
          const Positioned.fill(
            child: IgnorePointer(child: ConfettiOverlay(count: 26, seed: 3)),
          ),
      ],
    );
  }

  Widget _buildIntro() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: l.gameWeavesIntroMessage,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: l.gameWeavesStartPattern,
        icon: Icons.play_arrow_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.preview),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Level Path Map ──────────────────────────────────────
            GameLevelPathMap(
              gameId: GameId.weaves,
              accentColor: _game.accent,
              selectedLevel: _selectedLevel,
              maxUnlockedLevel: _maxUnlockedLevel,
              onLevelSelected: _changeLevel,
              levels: <GameLevelItem>[
                GameLevelItem(
                  levelNum: 1,
                  title: l.gameLevelEasy,
                  subtitle: l.gameWeavesSubtitle1Blank,
                  icon: Icons.grid_view_rounded,
                  stars: 3,
                ),
                GameLevelItem(
                  levelNum: 2,
                  title: l.gameLevelMedium,
                  subtitle: l.gameWeavesSubtitleHiddenWeave,
                  icon: Icons.view_module_rounded,
                  stars: 2,
                ),
                GameLevelItem(
                  levelNum: 3,
                  title: l.gameLevelHard,
                  subtitle: l.gameWeavesSubtitle2Blanks,
                  icon: Icons.dashboard_customize_rounded,
                  stars: 2,
                ),
                GameLevelItem(
                  levelNum: 4,
                  title: l.gameLevelExpert,
                  subtitle: l.gameWeavesSubtitleFastWeave,
                  icon: Icons.auto_awesome_mosaic_rounded,
                  stars: 1,
                ),
                GameLevelItem(
                  levelNum: 5,
                  title: l.gameLevelMastery,
                  subtitle: l.gameWeavesSubtitle4x4Grid,
                  icon: Icons.diamond_rounded,
                  stars: 0,
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameWeavesCategoryLabel, style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(l.gameWeavesTitle, style: AppText.h1.sized(26)),
                  const SizedBox(height: 8),
                  Text(
                    l.gameWeavesInstructions,
                    style: AppText.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  // A first look at today's colours, in the same woven
                  // strip the actual pattern is built from — the palette
                  // this round is drawn in, before a single tile is shown.
                  ClipRRect(
                    borderRadius: Corners.r(Corners.sm),
                    child: WovenStrip(height: 16, colors: _textile.palette),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_textile.name} · ${_textile.origin}',
                    style: AppText.caption.tint(AppColors.inkMuted),
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


class _PatternGrid extends StatelessWidget {
  const _PatternGrid({
    required this.grid,
    required this.palette,
    required this.blanks,
    required this.filled,
    required this.revealed,
    required this.activeBlank,
    required this.accent,
  });

  final List<List<int>> grid;
  final List<Color> palette;
  final List<int> blanks;
  final Map<int, int> filled;
  final bool revealed;
  final int? activeBlank;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final int n = grid.length;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: palette.first,
          borderRadius: Corners.r(Corners.md),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: n * n,
          itemBuilder: (BuildContext context, int i) {
            final bool isBlank = blanks.contains(i);
            final bool isFilled = filled.containsKey(i);

            if (isBlank && !isFilled) {
              final bool active = activeBlank == i;
              return AnimatedContainer(
                duration: Motion.normal,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: Corners.r(8),
                  border: Border.all(
                    color: active ? accent : AppColors.hairline,
                    width: active ? 2.6 : 1.4,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: active ? accent : AppColors.inkMuted,
                ),
              );
            }

            final int seed = isFilled ? filled[i]! : grid[i ~/ n][i % n];
            final bool hidden = !revealed && !isFilled;

            if (hidden) return const CoveredTile();

            return TweenAnimationBuilder<double>(
              key: ValueKey<String>('$i-$isFilled'),
              tween: Tween<double>(begin: isFilled ? 0.6 : 1, end: 1),
              duration: Motion.normal,
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double t, Widget? child) =>
                  Transform.scale(scale: t.clamp(0, 1), child: child),
              child: WeaveTile(seed: seed, palette: palette, radius: 8),
            );
          },
        ),
      ),
    );
  }
}
