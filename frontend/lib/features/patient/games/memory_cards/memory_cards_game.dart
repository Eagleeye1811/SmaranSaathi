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
import '../game_result_screen.dart';
import '../game_shell.dart';



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
            (label: 'Pairs found', value: '${_matched.length ~/ 2}/$_pairs'),
            (label: 'Tries', value: '${_tracker.attempts}'),
            (label: 'Wrong turns', value: '${_tracker.mistakes}'),
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

    final double width = MediaQuery.sizeOf(context).width;
    final int cols = _columns(width);
    final int found = _matched.length ~/ 2;

    return Stack(
      children: <Widget>[
        GameShell(
          game: _game,
          level: _selectedLevel,

          stepLabel: '$found of $_pairs pairs',
          progress: found / _pairs,
          companionMessage: _done
              ? 'Every pair found. Wonderful, ${_state.patient.shortName}.'
              : (_lastMatchName != null && _flipped.isEmpty
                  ? 'You found the $_lastMatchName. Keep going.'
                  : 'Turn over two cards and see if they match.'),
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
                    Expanded(
                      child: _CountChip(
                        label: 'Pairs found',
                        value: '$found / $_pairs',
                        color: AppColors.success,
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CountChip(
                        label: 'Tries',
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
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: 'Turn over cards to find matching pairs.',
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: 'Start game',
        icon: Icons.play_arrow_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.play),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
                            subtitle: '4 pairs',
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
                            subtitle: '6 pairs',
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
                            subtitle: '8 pairs',
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
                            subtitle: '10 pairs',
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
                            subtitle: '12 pairs',
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
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('MEMORY PAIRS', style: AppText.overline),
                  const SizedBox(height: 8),
                  Text('Visual Memory', style: AppText.h1.sized(26)),
                  const SizedBox(height: 8),
                  Text(
                    'Flip cards two at a time to find matching pairs of cultural symbols.',
                    style: AppText.bodySmall,
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

