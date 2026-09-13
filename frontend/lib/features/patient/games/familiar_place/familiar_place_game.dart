import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';
import 'house_map.dart';

/// Progressive hints for one target object — general, then situational, then
/// close to the answer.
class ObjectHints {
  const ObjectHints(this.objectId, this.hints);
  final String objectId;
  final List<String> hints;
}

/// Familiar Place Explorer — spatial memory in a house that looks like home.
///
/// Three panels: hints on the left, the room and floor plan in the centre,
/// the objects in the current room on the right. On a phone the same three
/// panels stack; on a tablet they sit side by side.
class FamiliarPlaceGame extends StatefulWidget {
  const FamiliarPlaceGame({super.key});

  @override
  State<FamiliarPlaceGame> createState() => _FamiliarPlaceGameState();
}

enum _Phase { intro, memorise, explore }

class _FamiliarPlaceGameState extends State<FamiliarPlaceGame> {
  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.familiarPlace);
  late final AppState _state = AppScope.read(context);
  late final int _maxUnlockedLevel = _state.levelOf(GameId.familiarPlace);
  late int _selectedLevel;

  _Phase _phase = _Phase.intro;

  int _roomIndex = 0;
  final Set<String> _found = <String>{};
  final Set<String> _wrongTaps = <String>{};
  final Set<String> _visited = <String>{};
  final List<String> _revealedHints = <String>[];
  String? _hintedObjectId;

  String? _feedback;
  bool _feedbackPositive = true;

  Timer? _timer;
  int _secondsLeft = 180;

  // ── content ────────────────────────────────────────────────────────────

  static const RoomObject _clock =
      RoomObject(id: 'clock', name: 'Wall clock', icon: Icons.schedule_rounded, color: AppColors.indigo);
  static const RoomObject _book =
      RoomObject(id: 'book', name: 'Book', icon: Icons.menu_book_rounded, color: AppColors.terracotta);
  static const RoomObject _cup = RoomObject(
      id: 'cup', name: 'Tea cup', icon: Icons.emoji_food_beverage_rounded, color: AppColors.accent);
  static const RoomObject _japi =
      RoomObject(id: 'japi', name: 'Japi hat', icon: Icons.umbrella_rounded, color: AppColors.primary);
  static const RoomObject _loom =
      RoomObject(id: 'loom', name: 'Handloom', icon: Icons.grid_on_rounded, color: AppColors.terracotta);

  List<RoomObject> get _targets => <RoomObject>[
        _clock,
        _cup,
        _book,
        if (_roomCount >= 4) _japi,
        if (_roomCount >= 5) _loom,
      ];


  int get _hintBudget => switch (_selectedLevel) {
        1 => 3,
        2 => 2,
        3 => 2,
        _ => 1,
      };

  int get _roomCount => switch (_selectedLevel) {
        1 => 3,
        2 => 4,
        3 => 4,
        _ => 5,
      };


  late final List<Room> _rooms = _layoutFor(_roomCount);

  /// The floor plan is re-tiled for each room count so the house always looks
  /// like a whole house rather than one with a missing corner.
  List<Room> _layoutFor(int count) {
    final List<Rect> plan = switch (count) {
      3 => const <Rect>[
          Rect.fromLTWH(0, 0, 0.55, 0.50),
          Rect.fromLTWH(0.57, 0, 0.43, 0.50),
          Rect.fromLTWH(0, 0.52, 1.0, 0.48),
        ],
      4 => const <Rect>[
          Rect.fromLTWH(0, 0, 0.56, 0.52),
          Rect.fromLTWH(0.58, 0, 0.42, 0.52),
          Rect.fromLTWH(0, 0.54, 0.44, 0.46),
          Rect.fromLTWH(0.46, 0.54, 0.54, 0.46),
        ],
      _ => const <Rect>[
          Rect.fromLTWH(0, 0, 0.52, 0.46),
          Rect.fromLTWH(0.54, 0, 0.46, 0.46),
          Rect.fromLTWH(0, 0.48, 0.36, 0.52),
          Rect.fromLTWH(0.38, 0.48, 0.30, 0.52),
          Rect.fromLTWH(0.70, 0.48, 0.30, 0.52),
        ],
    };
    final List<Room> source = _buildRooms();
    // Level 5 adds the loom room, which sits between the bedroom and the yard.
    final List<Room> chosen = count >= 5
        ? <Room>[source[0], source[1], source[2], source[4], source[3]]
        : source.take(count).toList();
    return <Room>[
      for (int i = 0; i < chosen.length; i++)
        Room(
          id: chosen[i].id,
          name: chosen[i].name,
          rect: plan[i],
          icon: chosen[i].icon,
          objects: List<RoomObject>.from(chosen[i].objects)
            ..shuffle(math.Random(_selectedLevel * 997 + i * 41 + 13)),
          floor: chosen[i].floor,
        ),
    ];
  }


  List<Room> _buildRooms() {
    return <Room>[
      const Room(
        id: 'living',
        name: 'Living room',
        icon: Icons.weekend_rounded,
        rect: Rect.fromLTWH(0, 0, 0.56, 0.52),
        floor: Color(0xFFEDE3D2),
        objects: <RoomObject>[
          _clock,
          RoomObject(
              id: 'radio', name: 'Radio', icon: Icons.radio_rounded, color: AppColors.inkSoft),
          RoomObject(
              id: 'chair', name: 'Cane chair', icon: Icons.chair_rounded, color: AppColors.accent),
          RoomObject(
              id: 'photo',
              name: 'Photograph',
              icon: Icons.photo_rounded,
              color: AppColors.secondary),
          RoomObject(
              id: 'xorai', name: 'Xorai', icon: Icons.emoji_events_rounded, color: AppColors.accent),
          RoomObject(
              id: 'fan', name: 'Hand fan', icon: Icons.toys_rounded, color: AppColors.primary),
        ],
      ),
      const Room(
        id: 'kitchen',
        name: 'Kitchen',
        icon: Icons.soup_kitchen_rounded,
        rect: Rect.fromLTWH(0.58, 0, 0.42, 0.52),
        floor: Color(0xFFE6EFDF),
        objects: <RoomObject>[
          _cup,
          RoomObject(
              id: 'pot', name: 'Cooking pot', icon: Icons.rice_bowl_rounded, color: AppColors.terracotta),
          RoomObject(
              id: 'jug', name: 'Water jug', icon: Icons.water_drop_rounded, color: AppColors.secondary),
          RoomObject(
              id: 'basket', name: 'Bamboo basket', icon: Icons.shopping_basket_rounded, color: AppColors.accent),
          RoomObject(
              id: 'stove', name: 'Stove', icon: Icons.local_fire_department_rounded, color: AppColors.danger),
          RoomObject(
              id: 'spoon', name: 'Ladle', icon: Icons.restaurant_rounded, color: AppColors.inkSoft),
        ],
      ),
      const Room(
        id: 'bedroom',
        name: 'Bedroom',
        icon: Icons.bed_rounded,
        rect: Rect.fromLTWH(0, 0.54, 0.44, 0.46),
        floor: Color(0xFFE8E3F0),
        objects: <RoomObject>[
          _book,
          RoomObject(
              id: 'pillow', name: 'Pillow', icon: Icons.bed_rounded, color: AppColors.plum),
          RoomObject(
              id: 'shawl', name: 'Shawl', icon: Icons.layers_rounded, color: AppColors.terracotta),
          RoomObject(
              id: 'mirror', name: 'Mirror', icon: Icons.crop_portrait_rounded, color: AppColors.secondary),
          RoomObject(
              id: 'comb', name: 'Comb', icon: Icons.content_cut_rounded, color: AppColors.inkSoft),
          RoomObject(
              id: 'lamp', name: 'Oil lamp', icon: Icons.light_rounded, color: AppColors.accent),
        ],
      ),
      const Room(
        id: 'courtyard',
        name: 'Courtyard',
        icon: Icons.park_rounded,
        rect: Rect.fromLTWH(0.46, 0.54, 0.54, 0.46),
        floor: Color(0xFFE2EFE0),
        objects: <RoomObject>[
          _japi,
          RoomObject(
              id: 'broom', name: 'Broom', icon: Icons.cleaning_services_rounded, color: AppColors.inkSoft),
          RoomObject(
              id: 'plant', name: 'Tulsi plant', icon: Icons.local_florist_rounded, color: AppColors.primary),
          RoomObject(
              id: 'bucket', name: 'Bucket', icon: Icons.delete_outline_rounded, color: AppColors.secondary),
          RoomObject(
              id: 'umbrella', name: 'Umbrella', icon: Icons.beach_access_rounded, color: AppColors.plum),
          RoomObject(
              id: 'cycle', name: 'Bicycle', icon: Icons.pedal_bike_rounded, color: AppColors.terracotta),
        ],
      ),
      const Room(
        id: 'loomroom',
        name: 'Loom room',
        icon: Icons.grid_on_rounded,
        rect: Rect.fromLTWH(0.62, 0.28, 0.38, 0.24),
        floor: Color(0xFFF3E6DB),
        objects: <RoomObject>[
          _loom,
          RoomObject(
              id: 'shuttle', name: 'Shuttle', icon: Icons.swap_horiz_rounded, color: AppColors.accent),
          RoomObject(
              id: 'yarn', name: 'Yarn', icon: Icons.circle_rounded, color: AppColors.plum),
          RoomObject(
              id: 'gamosa', name: 'Gamosa', icon: Icons.view_stream_rounded, color: AppColors.danger),
          RoomObject(
              id: 'scissors', name: 'Scissors', icon: Icons.content_cut_rounded, color: AppColors.inkSoft),
          RoomObject(
              id: 'fan2', name: 'Hand fan', icon: Icons.toys_rounded, color: AppColors.primary),
        ],
      ),
    ];
  }


  static const List<ObjectHints> _hintBook = <ObjectHints>[
    ObjectHints('clock', <String>[
      'It tells you what time it is.',
      'You look at it when you wake up.',
      'It hangs on the wall in the living room.',
    ]),
    ObjectHints('book', <String>[
      'It is something you can read.',
      'You may find it near a table.',
      'Look beside the bed, in the bedroom.',
    ]),
    ObjectHints('cup', <String>[
      'You hold it every single morning.',
      'It is warm when it is full.',
      'Look in the kitchen, near the stove.',
    ]),
    ObjectHints('japi', <String>[
      'It keeps the sun off your head.',
      'It is made of bamboo and leaves.',
      'It is hanging out in the courtyard.',
    ]),
    ObjectHints('loom', <String>[
      'It is used for weaving cloth.',
      'You shuttle threads across it.',
      'Look in the loom room.',
    ]),
  ];


  RoomObject? get _nextTarget {
    for (final RoomObject t in _targets) {
      if (!_found.contains(t.id)) return t;
    }
    return null;
  }

  // ── lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.familiarPlace);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _changeLevel(int lvl) {
    setState(() {
      _selectedLevel = lvl;
    });
  }


  void _startExploring() {
    setState(() {
      _phase = _Phase.explore;
      _visited.add(_rooms.first.id);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _finish(completed: false);
      }
    });
  }

  void _tapObject(RoomObject o) {
    if (_found.contains(o.id) || _wrongTaps.contains(o.id)) return;
    final AppLocalizations l = AppLocalizations.of(context);
    _tracker.attempts++;
    final bool isTarget = _targets.any((RoomObject t) => t.id == o.id);
    setState(() {
      _hintedObjectId = null;
      if (isTarget) {
        _tracker.correct++;
        _found.add(o.id);
        _feedbackPositive = true;
        _feedback = l.gameFamiliarPlaceExcellentFound(o.name.toLowerCase());
        _revealedHints.clear();
      } else {
        _tracker.mistakes++;
        _wrongTaps.add(o.id);
        _feedbackPositive = false;
        _feedback = l.gameFamiliarPlaceNotWhatWeAreLookingFor;
      }
    });

    if (_found.length == _targets.length) {
      _timer?.cancel();
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _finish(completed: true);
      });
    }
  }

  void _useHint() {
    final RoomObject? target = _nextTarget;
    if (target == null) return;
    if (_tracker.hints >= _hintBudget) return;
    final ObjectHints book =
        _hintBook.firstWhere((ObjectHints h) => h.objectId == target.id);
    final int idx = _revealedHints.length.clamp(0, book.hints.length - 1);
    setState(() {
      _tracker.hints++;
      _revealedHints.add(book.hints[idx]);
      if (_revealedHints.length >= 3) _hintedObjectId = target.id;
    });
  }

  void _nextRoom() {
    setState(() {
      _roomIndex = (_roomIndex + 1) % _rooms.length;
      _visited.add(_rooms[_roomIndex].id);
      _feedback = null;
    });
  }

  void _finish({required bool completed}) {
    final AppLocalizations l = AppLocalizations.of(context);
    _timer?.cancel();
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.familiarPlace, _selectedLevel),
      completed: completed,
    );
    final AdaptiveDecision d = _state.finishGame(GameId.familiarPlace, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _selectedLevel,
          highlights: <({String label, String value})>[
            (label: l.gameFamiliarPlaceObjectsToFind, value: '${_targets.length}'),
            (label: l.gameFamiliarPlaceObjectsFound, value: '${_found.length}'),
            (label: l.gameFamiliarPlaceRoomsVisited, value: '${_visited.length}'),
            (label: l.gameFamiliarPlaceHintsUsed, value: '${_tracker.hints}/$_hintBudget'),
          ],
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) return _buildIntro();
    if (_phase == _Phase.memorise) return _buildMemorise();
    return _buildExplore();
  }

  Widget _buildIntro() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: l.gameFamiliarPlaceIntroMessage,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: l.gameFamiliarPlaceStartExploring,
        icon: Icons.explore_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.memorise),
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
                  Text(l.gameMemoryCardsChooseLevel, style: AppText.overline),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 1,
                            title: l.gameLevelEasy,
                            subtitle: l.gameFamiliarPlaceRoomsCount(3),
                            unlocked: 1 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 1,
                            onTap: (1 <= _maxUnlockedLevel) ? () => _changeLevel(1) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 2,
                            title: l.gameLevelMedium,
                            subtitle: l.gameFamiliarPlaceRoomsCount(4),
                            unlocked: 2 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 2,
                            onTap: (2 <= _maxUnlockedLevel) ? () => _changeLevel(2) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 3,
                            title: l.gameLevelHard,
                            subtitle: l.gameFamiliarPlaceRoomsCount(5),
                            unlocked: 3 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 3,
                            onTap: (3 <= _maxUnlockedLevel) ? () => _changeLevel(3) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 4,
                            title: l.gameLevelExpert,
                            subtitle: l.gameFamiliarPlaceSubtitle5RoomsOneHint,
                            unlocked: 4 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 4,
                            onTap: (4 <= _maxUnlockedLevel) ? () => _changeLevel(4) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            accent: _game.accent,
                            levelNum: 5,
                            title: l.gameLevelMastery,
                            subtitle: l.gameFamiliarPlaceSubtitle5RoomsFast,
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
                  Text(l.gameFamiliarPlaceCategoryLabel, style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(l.gameFamiliarPlaceTitle, style: AppText.h1.sized(26)),
                  const SizedBox(height: 8),
                  Text(
                    l.gameFamiliarPlaceInstructions,
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

  Widget _buildMemorise() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,

      companionMessage: l.gameFamiliarPlaceRememberThese(_targets.length),
      companionState: CompanionState.thinking,
      bottom: BigButton(
        label: l.gameFamiliarPlaceIWillRemember,
        icon: Icons.arrow_forward_rounded,
        color: _game.accent,
        onPressed: _startExploring,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MmCard(
              shadow: AppColors.liftShadow(),
              child: Column(
                children: <Widget>[
                  Text(l.gameFamiliarPlaceRememberTheseLabel, style: AppText.overline),
                  const SizedBox(height: Insets.md),
                  for (int i = 0; i < _targets.length; i++)
                    FadeInUp(
                      delayMs: 120 * i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                color: _targets[i].color.withValues(alpha: 0.12),
                                borderRadius: Corners.r(Corners.md),
                              ),
                              child: Icon(_targets[i].icon,
                                  size: 34, color: _targets[i].color),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(_targets[i].name,
                                  style: AppText.h2.sized(22)),
                            ),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}', style: AppText.body.wght(800)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: _game.tint,
                borderRadius: Corners.r(Corners.md),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.home_rounded, color: _game.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.gameFamiliarPlaceWalkThroughRooms(_roomCount),
                      style: AppText.bodySmall.tint(AppColors.ink),
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

  Widget _buildExplore() {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final Room room = _rooms[_roomIndex];
    final RoomObject? target = _nextTarget;

    return GameShell(
      game: _game,
      level: _selectedLevel,
      stepLabel: l.gameFamiliarPlaceFoundOfTotal(_found.length, _targets.length),
      progress: _found.length / _targets.length,
      hintsLeft: _hintBudget - _tracker.hints,
      hintsTotal: _hintBudget,
      onHint: target == null ? null : _useHint,
      scrollable: !wide,
      bottom: Row(
        children: <Widget>[
          Expanded(
            child: BigButton(
              label: l.gameFamiliarPlaceNextRoom,
              icon: Icons.arrow_forward_rounded,
              color: _game.accent,
              height: 62,
              onPressed: _nextRoom,
            ),
          ),
          const SizedBox(width: 12),
          _TimerPill(secondsLeft: _secondsLeft),
        ],
      ),
      child: wide ? _wideLayout(room) : _narrowLayout(room),
    );
  }

  // ── layouts ────────────────────────────────────────────────────────────

  Widget _narrowLayout(Room room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _roomPanel(room, mapHeight: 150),
          const SizedBox(height: Insets.md),
          if (_revealedHints.isNotEmpty) ...<Widget>[
            _hintPanel(),
            const SizedBox(height: Insets.md),
          ],
          if (_feedback != null) ...<Widget>[
            FeedbackBubble(message: _feedback!, positive: _feedbackPositive),
            const SizedBox(height: Insets.md),
          ],
          _objectPanel(room, columns: 3),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _wideLayout(Room room) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── left: hints ──────────────────────────────────────────────
          SizedBox(
            width: 250,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _hintPanel(alwaysShow: true),
                ],
              ),
            ),
          ),

          const SizedBox(width: Insets.md),
          // ── centre: the room ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _roomPanel(room, mapHeight: 220),
                  if (_feedback != null) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    FeedbackBubble(message: _feedback!, positive: _feedbackPositive),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          // ── right: objects in this room ──────────────────────────────
          SizedBox(
            width: 300,
            child: SingleChildScrollView(child: _objectPanel(room, columns: 2)),
          ),
        ],
      ),
    );
  }

  // ── panels ─────────────────────────────────────────────────────────────


  Widget _roomPanel(Room room, {required double mapHeight}) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: room.icon, color: _game.accent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.gameFamiliarPlaceYouAreIn, style: AppText.overline),
                    const SizedBox(height: 2),
                    Text(room.name, style: AppText.h2.sized(21)),
                  ],
                ),
              ),
              PillTag(
                label: l.gameFamiliarPlaceRoomOfTotal(_roomIndex + 1, _rooms.length),
                color: _game.accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          HouseMap(
            rooms: _rooms,
            currentIndex: _roomIndex,
            visited: _visited,
            height: mapHeight,
          ),
        ],
      ),
    );
  }

  Widget _hintPanel({bool alwaysShow = false}) {
    if (_revealedHints.isEmpty && !alwaysShow) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context);
    final int left = _hintBudget - _tracker.hints;
    return MmCard(
      padding: const EdgeInsets.all(14),
      color: AppColors.accentTint,
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.gameFamiliarPlaceHintsLeft(left),
                    style: AppText.overline.tint(AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_revealedHints.isEmpty)
            Text(
              l.gameFamiliarPlaceTapLightbulb,
              style: AppText.bodySmall.tint(AppColors.ink),
            )
          else
            for (int i = 0; i < _revealedHints.length; i++)
              FadeInUp(
                key: ValueKey<int>(i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: AppText.caption.sized(11).wght(800).tint(Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_revealedHints[i],
                            style: AppText.body.wght(600).tint(AppColors.ink)),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _objectPanel(Room room, {required int columns}) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.gameFamiliarPlaceThingsInRoom, style: AppText.overline),
          const SizedBox(height: 4),
          Text(l.gameFamiliarPlaceTapOneIfYouThink,
              style: AppText.caption),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns == 2 ? 0.92 : 0.76,
            ),
            itemCount: room.objects.length,
            itemBuilder: (BuildContext context, int i) {
              final RoomObject o = room.objects[i];
              return ObjectTile(
                object: o,
                found: _found.contains(o.id),
                dismissed: _wrongTaps.contains(o.id),
                hinted: _hintedObjectId == o.id,
                compact: columns >= 3,
                onTap: () => _tapObject(o),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.secondsLeft});
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final bool low = secondsLeft <= 30;
    final String label =
        '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: low ? AppColors.dangerTint : Colors.white,
        borderRadius: Corners.r(Corners.pill),
        border: Border.all(color: low ? AppColors.danger : AppColors.hairline, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.timer_outlined,
              size: 19, color: low ? AppColors.danger : AppColors.inkMuted),
          const SizedBox(width: 7),
          Text(label,
              style: AppText.body
                  .wght(800)
                  .tint(low ? AppColors.danger : AppColors.inkSoft)),
        ],
      ),
    );
  }
}
