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
import '../../../../core/widgets/illustration.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';
import '../widgets/game_level_path_map.dart';



/// One face in the deck.
class CardFace {
  const CardFace(this.sceneId, this.name);
  final String sceneId;
  final String name;
}

/// NER Memory Cards — recognition memory using images from around the
/// North East rather than abstract symbols, so every reveal is also a small
/// moment of recognition.
class MemoryCardsGame extends StatefulWidget {
  const MemoryCardsGame({super.key});

  @override
  State<MemoryCardsGame> createState() => _MemoryCardsGameState();
}

enum _Phase { intro, play }

class _MemoryCardsGameState extends State<MemoryCardsGame> {
  static const List<CardFace> deck = <CardFace>[
    CardFace('rhino', 'One-horned rhino'),
    CardFace('gamosa', 'Gamosa'),
    CardFace('dhol', 'Dhol'),
    CardFace('japi', 'Japi'),
    CardFace('bamboo', 'Bamboo'),
    CardFace('paddy', 'Paddy field'),
    CardFace('hills', 'The hills'),
    CardFace('xorai', 'Xorai'),
    CardFace('orchid', 'Foxtail orchid'),
    CardFace('village_home', 'Village house'),
    CardFace('tea_garden', 'Tea garden'),
    CardFace('river', 'The Brahmaputra'),
  ];

  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.memoryCards);
  late final AppState _state = AppScope.read(context);
  late final int _maxUnlockedLevel = _state.levelOf(GameId.memoryCards);
  late int _selectedLevel;


  _Phase _phase = _Phase.intro;

  int get _pairs => switch (_selectedLevel) {
        1 => 4,
        2 => 6,
        3 => 8,
        _ => 12,
      };


  late List<int> _board;
  final Set<int> _matched = <int>{};
  final List<int> _flipped = <int>[];
  bool _locked = false;
  bool _done = false;
  String? _lastMatchName;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.memoryCards);
    _setupBoard();
  }

  void _setupBoard() {
    _matched.clear();
    _flipped.clear();
    _locked = false;
    _done = false;
    _lastMatchName = null;
    final List<int> cards = <int>[];
    for (int i = 0; i < _pairs; i++) {
      cards..add(i)..add(i);
    }
    cards.shuffle(math.Random(_selectedLevel * 4177 + _pairs));
    _board = cards;
  }

  void _changeLevel(int lvl) {
    setState(() {
      _selectedLevel = lvl;
      _setupBoard();
    });
  }


  void _tap(int index) {
    if (_locked || _matched.contains(index) || _flipped.contains(index)) return;
    setState(() => _flipped.add(index));
    if (_flipped.length < 2) return;

    _locked = true;
    _tracker.attempts++;
    final int a = _flipped[0];
    final int b = _flipped[1];

    if (_board[a] == _board[b]) {
      _tracker.correct++;
      Future<void>.delayed(const Duration(milliseconds: 460), () {
        if (!mounted) return;
        setState(() {
          _matched..add(a)..add(b);
          _lastMatchName = deck[_board[a]].name;
          _flipped.clear();
          _locked = false;
          if (_matched.length == _board.length) _done = true;
        });
        if (_done) {
          Future<void>.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) _finish();
          });
        }
      });
    } else {
      _tracker.mistakes++;
      Future<void>.delayed(const Duration(milliseconds: 950), () {
        if (!mounted) return;
        setState(() {
          _flipped.clear();
          _locked = false;
        });
      });
    }
  }

  void _finish() {
    final AppLocalizations l = AppLocalizations.of(context);
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.memoryCards, _selectedLevel),
    );
    final AdaptiveDecision d = _state.finishGame(GameId.memoryCards, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _selectedLevel,
          highlights: <({String label, String value})>[
            (label: l.gameMemoryCardsPairsFound, value: '${_matched.length ~/ 2}/$_pairs'),
            (label: l.gameMemoryCardsTries, value: '${_tracker.attempts}'),
            (label: l.gameMemoryCardsWrongTurns, value: '${_tracker.mistakes}'),
          ],
        ),
      ),
    );
  }


  int _columns(double width) {
    if (_pairs <= 4) return width > 520 ? 4 : 2;
    if (_pairs <= 6) return width > 520 ? 4 : 3;
    if (_pairs <= 8) return width > 520 ? 4 : 4;
    return width > 720 ? 6 : 4;
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) return _buildIntro();

    final AppLocalizations l = AppLocalizations.of(context);
    final double width = MediaQuery.sizeOf(context).width;
    final int cols = _columns(width);
    final int found = _matched.length ~/ 2;

    return Stack(
      children: <Widget>[
        GameShell(
          game: _game,
          level: _selectedLevel,

          stepLabel: l.gameMemoryCardsStepLabel(found, _pairs),
          progress: found / _pairs,
          companionMessage: _done
              ? l.gameMemoryCardsAllFound(_state.patient.shortName)
              : (_lastMatchName != null && _flipped.isEmpty
                  ? l.gameMemoryCardsFoundMatch(_lastMatchName!)
                  : l.gameMemoryCardsTurnOverTwo),
          companionState: _done
              ? CompanionState.celebrating
              : (_lastMatchName != null && _flipped.isEmpty
                  ? CompanionState.happy
                  : CompanionState.encouraging),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // A live-filling ring instead of a static check icon —
                    // "found / total" is a genuine fraction, and this app
                    // already has exactly this ring on the Game Hub for the
                    // same kind of "N of M done" stat, just unused in-game
                    // until now.
                    Expanded(
                      child: _RingCountChip(
                        label: l.gameMemoryCardsPairsFound,
                        value: '$found / $_pairs',
                        progress: _pairs == 0 ? 0 : found / _pairs,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CountChip(
                        label: l.gameMemoryCardsTries,
                        value: '${_tracker.attempts}',
                        color: _game.accent,
                        icon: Icons.touch_app_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _board.length,
                  itemBuilder: (BuildContext context, int i) {
                    final bool faceUp = _flipped.contains(i) || _matched.contains(i);
                    return _MemoryCard(
                      face: deck[_board[i]],
                      faceUp: faceUp,
                      matched: _matched.contains(i),
                      showLabel: cols <= 4,
                      onTap: () => _tap(i),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (_done && !_state.reduceMotion) const Positioned.fill(child: ConfettiOverlay()),
      ],
    );
  }

  Widget _buildIntro() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: l.gameMemoryCardsIntroMessage,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: l.gameStartGame,
        icon: Icons.play_arrow_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.play),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Level Path Map ──────────────────────────────────────
            GameLevelPathMap(
              gameId: GameId.memoryCards,
              accentColor: _game.accent,
              selectedLevel: _selectedLevel,
              maxUnlockedLevel: _maxUnlockedLevel,
              onLevelSelected: _changeLevel,
              levels: <GameLevelItem>[
                GameLevelItem(
                  levelNum: 1,
                  title: l.gameLevelEasy,
                  subtitle: l.gameMemoryCardsPairsCount(4),
                  icon: Icons.grid_view_rounded,
                  stars: 3,
                ),
                GameLevelItem(
                  levelNum: 2,
                  title: l.gameLevelMedium,
                  subtitle: l.gameMemoryCardsPairsCount(6),
                  icon: Icons.grid_3x3_rounded,
                  stars: 2,
                ),
                GameLevelItem(
                  levelNum: 3,
                  title: l.gameLevelHard,
                  subtitle: l.gameMemoryCardsPairsCount(8),
                  icon: Icons.view_comfy_rounded,
                  stars: 2,
                ),
                GameLevelItem(
                  levelNum: 4,
                  title: l.gameLevelExpert,
                  subtitle: l.gameMemoryCardsPairsCount(10),
                  icon: Icons.apps_rounded,
                  stars: 1,
                ),
                GameLevelItem(
                  levelNum: 5,
                  title: l.gameLevelMastery,
                  subtitle: l.gameMemoryCardsPairsCount(12),
                  icon: Icons.workspace_premium_rounded,
                  stars: 0,
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameMemoryCardsCategoryLabel, style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(l.gameMemoryCardsTitle, style: AppText.h1.sized(26)),
                  const SizedBox(height: 8),
                  Text(
                    l.gameMemoryCardsInstructions,
                    style: AppText.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  // A handful of faces from today's deck, so the pairs
                  // being matched are something recognisable from the
                  // very first glance, not a mystery until the cards flip.
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: deck.length,
                      separatorBuilder: (BuildContext context, int i) =>
                          const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int i) => ClipRRect(
                        borderRadius: Corners.r(Corners.sm),
                        child: SceneImage(sceneId: deck[i].sceneId, size: 56),
                      ),
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


class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppText.caption),
                const SizedBox(height: 1),
                Text(value, style: AppText.body.wght(800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Same bordered-box shape as [_CountChip], but for a stat that's genuinely
/// a fraction of a known total — the ring visibly fills as pairs are found,
/// rather than only the number changing.
class _RingCountChip extends StatelessWidget {
  const _RingCountChip({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;

  /// 0..1
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          ProgressRing(value: progress, size: 38, stroke: 4, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppText.caption),
                const SizedBox(height: 1),
                Text(value, style: AppText.body.wght(800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.face,
    required this.faceUp,
    required this.matched,
    required this.onTap,
    required this.showLabel,
  });

  final CardFace face;
  final bool faceUp;
  final bool matched;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: faceUp ? null : onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: faceUp ? 1 : 0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        builder: (BuildContext context, double t, _) {
          final bool showFront = t >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(t * math.pi),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _front(),
                  )
                : _back(),
          );
        },
      ),
    );
  }

  Widget _front() {
    return AnimatedContainer(
      duration: Motion.normal,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(
          color: matched ? AppColors.success : AppColors.hairline,
          width: matched ? 2.4 : 1.3,
        ),
        boxShadow: AppColors.softShadow(y: 3, blur: 10, opacity: 0.05),
      ),
      padding: const EdgeInsets.all(5),
      child: Column(
        children: <Widget>[
          Expanded(child: SceneImage(sceneId: face.sceneId, radius: 10, fit: false)),
          if (showLabel) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              face.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.sized(10.5).wght(700).tint(
                    matched ? AppColors.success : AppColors.inkSoft,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _back() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: Corners.r(Corners.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3F5B86), Color(0xFF2A3F63)],
        ),
        boxShadow: AppColors.softShadow(y: 3, blur: 10, opacity: 0.06),
      ),
      child: CustomPaint(painter: const _CardBackPainter()),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    const double step = 17;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 5)
            ..lineTo(x + 5, y)
            ..lineTo(x, y + 5)
            ..lineTo(x - 5, y)
            ..close(),
          p,
        );
      }
    }

    // centre mark
    final Offset c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - size.width * 0.15)
        ..lineTo(c.dx + size.width * 0.15, c.dy)
        ..lineTo(c.dx, c.dy + size.width * 0.15)
        ..lineTo(c.dx - size.width * 0.15, c.dy)
        ..close(),
      Paint()..color = const Color(0xFFE0913A).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => false;
}
