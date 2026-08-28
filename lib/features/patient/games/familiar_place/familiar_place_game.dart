import 'dart:async';

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

enum _Phase { memorise, explore }

class _FamiliarPlaceGameState extends State<FamiliarPlaceGame> {
  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.familiarPlace);
  late final AppState _state = AppScope.read(context);
  late final int _level = _state.levelOf(GameId.familiarPlace);

  _Phase _phase = _Phase.memorise;
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

  List<RoomObject> get _targets => <RoomObject>[
        _clock,
        _book,
        _cup,
        if (_level >= 3) _japi,
      ];

  int get _hintBudget => switch (_level) {
        1 => 3,
        2 => 2,
        3 => 2,
        _ => 1,
      };

  int get _roomCount => switch (_level) {
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
          objects: chosen[i].objects,
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
          RoomObject(
              id: 'loom', name: 'Handloom', icon: Icons.grid_on_rounded, color: AppColors.terracotta),
          RoomObject(
              id: 'shuttle', name: 'Shuttle', icon: Icons.swap_horiz_rounded, color: AppColors.accent),
          RoomObject(
              id: 'yarn', name: 'Yarn', icon: Icons.circle_rounded, color: AppColors.plum),
          RoomObject(
              id: 'gamosa', name: 'Gamosa', icon: Icons.view_stream_rounded, color: AppColors.danger),
          RoomObject(
              id: 'scissors', name: 'Scissors', icon: Icons.content_cut_rounded, color: AppColors.inkSoft),
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
  ];

  RoomObject? get _nextTarget {
    for (final RoomObject t in _targets) {
      if (!_found.contains(t.id)) return t;
    }
    return null;
  }

  // ── lifecycle ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    _tracker.attempts++;
    final bool isTarget = _targets.any((RoomObject t) => t.id == o.id);
    setState(() {
      _hintedObjectId = null;
      if (isTarget) {
        _tracker.correct++;
        _found.add(o.id);
        _feedbackPositive = true;
        _feedback = 'Excellent! You found the ${o.name.toLowerCase()}.';
        _revealedHints.clear();
      } else {
        _tracker.mistakes++;
        _wrongTaps.add(o.id);
        _feedbackPositive = false;
        _feedback = 'That is not one of the things we are looking for. Keep going.';
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
    _timer?.cancel();
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.familiarPlace, _level),
      completed: completed,
    );
    final AdaptiveDecision d = _state.finishGame(GameId.familiarPlace, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _level,
          highlights: <({String label, String value})>[
            (label: 'Objects to find', value: '${_targets.length}'),
            (label: 'Objects found', value: '${_found.length}'),
            (label: 'Rooms visited', value: '${_visited.length}'),
            (label: 'Hints used', value: '${_tracker.hints}/$_hintBudget'),
          ],
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.memorise) return _buildMemorise();
    return _buildExplore();
  }

  Widget _buildMemorise() {
    return GameShell(
      game: _game,
      level: _level,
      companionMessage:
          'Before we walk through the house, remember these ${_targets.length} things.',
      companionState: CompanionState.thinking,
      bottom: BigButton(
        label: 'I will remember them',
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
                  Text('REMEMBER THESE', style: AppText.overline),
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
                      'You will walk through $_roomCount rooms. Tap a thing when you '
                      'think it is one of these.',
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
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final Room room = _rooms[_roomIndex];
    final RoomObject? target = _nextTarget;

    return GameShell(
      game: _game,
      level: _level,
      stepLabel: '${_found.length}/${_targets.length} found',
      progress: _found.length / _targets.length,
      hintsLeft: _hintBudget - _tracker.hints,
      hintsTotal: _hintBudget,
      onHint: target == null ? null : _useHint,
      scrollable: !wide,
      bottom: Row(
        children: <Widget>[
          Expanded(
            child: BigButton(
              label: 'Next room',
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
          _targetStrip(),
          const SizedBox(height: Insets.md),
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
                  _targetStrip(vertical: true),
                  const SizedBox(height: Insets.md),
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

  Widget _targetStrip({bool vertical = false}) {
    final Widget items = vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final RoomObject t in _targets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _targetChip(t, wide: true),
                ),
            ],
          )
        : Row(
            children: <Widget>[
              for (final RoomObject t in _targets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _targetChip(t),
                  ),
                ),
            ],
          );

    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('LOOKING FOR', style: AppText.overline),
          const SizedBox(height: 10),
          items,
        ],
      ),
    );
  }

  Widget _targetChip(RoomObject t, {bool wide = false}) {
    final bool got = _found.contains(t.id);
    return AnimatedContainer(
      duration: Motion.normal,
      padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 8, vertical: 10),
      decoration: BoxDecoration(
        color: got ? AppColors.successTint : AppColors.surfaceMuted,
        borderRadius: Corners.r(Corners.sm),
        border: Border.all(
          color: got ? AppColors.success.withValues(alpha: 0.5) : AppColors.hairline,
        ),
      ),
      child: wide
          ? Row(
              children: <Widget>[
                Icon(got ? Icons.check_circle_rounded : t.icon,
                    size: 20, color: got ? AppColors.success : t.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.name,
                      style: AppText.body.wght(700).tint(
                            got ? AppColors.success : AppColors.ink,
                          )),
                ),
              ],
            )
          : Column(
              children: <Widget>[
                Icon(got ? Icons.check_circle_rounded : t.icon,
                    size: 24, color: got ? AppColors.success : t.color),
                const SizedBox(height: 5),
                Text(
                  t.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.sized(11.5).wght(700).tint(
                        got ? AppColors.success : AppColors.inkSoft,
                      ),
                ),
              ],
            ),
    );
  }

  Widget _roomPanel(Room room, {required double mapHeight}) {
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
                    Text('YOU ARE IN', style: AppText.overline),
                    const SizedBox(height: 2),
                    Text(room.name, style: AppText.h2.sized(21)),
                  ],
                ),
              ),
              PillTag(
                label: 'Room ${_roomIndex + 1} of ${_rooms.length}',
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
                child: Text('HINTS  ·  $left LEFT',
                    style: AppText.overline.tint(AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_revealedHints.isEmpty)
            Text(
              'Tap the lightbulb at the top if you would like a clue.',
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
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('THINGS IN THIS ROOM', style: AppText.overline),
          const SizedBox(height: 4),
          Text('Tap one if you think it is something we are looking for.',
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
