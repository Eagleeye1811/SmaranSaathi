import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../core/models/game.dart';

/// Level item definition for the serpentine game path map.
class GameLevelItem {
  const GameLevelItem({
    required this.levelNum,
    required this.title,
    this.subtitle = '',
    this.icon,
    this.stars = 0,
  });

  final int levelNum;
  final String title;
  final String subtitle;
  final IconData? icon;
  final int stars;
}

/// A clean, thematic Candy Crush style serpentine level path map.
///
/// Features:
/// - Scrollable map container with smooth physics and auto-centering on current level
/// - Visible locked levels extending along the winding path (up to 8+ levels)
/// - Support for custom background images (assets, network URLs, or ImageProviders)
/// - Increased gap between header badge and Level 1 circle
/// - Game-concept themed background watermark icons matching each game
/// - Continuous winding path extending into the horizon
/// - Sleek 48px circular level nodes with active glowing selection rings
class GameLevelPathMap extends StatefulWidget {
  const GameLevelPathMap({
    super.key,
    required this.levels,
    required this.selectedLevel,
    required this.maxUnlockedLevel,
    required this.accentColor,
    required this.onLevelSelected,
    this.gameId,
    this.conceptIcons,
    this.backgroundImageAsset,
    this.backgroundImageUrl,
    this.backgroundImage,
    this.mapHeight = 390.0,
    this.totalDisplayLevels = 8,
  });

  final List<GameLevelItem> levels;
  final int selectedLevel;
  final int maxUnlockedLevel;
  final Color accentColor;
  final ValueChanged<int> onLevelSelected;
  final GameId? gameId;
  final List<IconData>? conceptIcons;

  /// Optional custom local asset path for map background image (e.g. 'assets/images/map_bg.png')
  final String? backgroundImageAsset;

  /// Optional custom network URL for map background image
  final String? backgroundImageUrl;

  /// Optional custom ImageProvider for map background
  final ImageProvider? backgroundImage;

  /// Fixed viewport height for the scrollable map card (default 390.0)
  final double mapHeight;

  /// Total levels displayed on the serpentine path including upcoming locked levels (default 8)
  final int totalDisplayLevels;

  @override
  State<GameLevelPathMap> createState() => _GameLevelPathMapState();
}

class _GameLevelPathMapState extends State<GameLevelPathMap> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController = ScrollController();
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveLevel());
  }

  @override
  void didUpdateWidget(covariant GameLevelPathMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevel != widget.selectedLevel) {
      _scrollToActiveLevel();
    }
  }

  void _scrollToActiveLevel() {
    if (!_scrollController.hasClients) return;
    const double startY = 82.0;
    const double rowHeight = 78.0;
    final int activeIdx = (widget.selectedLevel - 1).clamp(0, _effectiveLevels.length - 1);
    final double targetY = startY + (activeIdx * rowHeight) - (widget.mapHeight / 2) + 24;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double scrollOffset = targetY.clamp(0.0, math.max(0.0, maxScroll));

    _scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Ensures levels list extends to totalDisplayLevels so upcoming locked levels are visible on the map.
  List<GameLevelItem> get _effectiveLevels {
    final List<GameLevelItem> list = List<GameLevelItem>.from(widget.levels);
    final int targetCount = math.max(list.length, widget.totalDisplayLevels);

    for (int i = list.length + 1; i <= targetCount; i++) {
      list.add(
        GameLevelItem(
          levelNum: i,
          title: 'Level $i',
          subtitle: 'Locked stage',
          stars: 0,
        ),
      );
    }
    return list;
  }

  List<IconData> get _defaultThemeIcons {
    if (widget.conceptIcons != null && widget.conceptIcons!.isNotEmpty) {
      return widget.conceptIcons!;
    }

    if (widget.gameId != null) {
      switch (widget.gameId!) {
        case GameId.procedure:
          return const <IconData>[
            Icons.emoji_food_beverage_rounded,
            Icons.local_laundry_service_rounded,
            Icons.cookie_rounded,
            Icons.wash_rounded,
            Icons.dry_cleaning_rounded,
          ];
        case GameId.memoryCards:
          return const <IconData>[
            Icons.grid_view_rounded,
            Icons.style_rounded,
            Icons.extension_rounded,
            Icons.view_comfy_rounded,
          ];
        case GameId.melody:
          return const <IconData>[
            Icons.music_note_rounded,
            Icons.graphic_eq_rounded,
            Icons.equalizer_rounded,
            Icons.queue_music_rounded,
          ];
        case GameId.story:
          return const <IconData>[
            Icons.menu_book_rounded,
            Icons.auto_stories_rounded,
            Icons.import_contacts_rounded,
            Icons.psychology_rounded,
          ];
        case GameId.weaves:
          return const <IconData>[
            Icons.grid_3x3_rounded,
            Icons.auto_awesome_mosaic_rounded,
            Icons.diamond_rounded,
            Icons.pattern_rounded,
          ];
        case GameId.familiarPlace:
          return const <IconData>[
            Icons.home_rounded,
            Icons.meeting_room_rounded,
            Icons.holiday_village_rounded,
            Icons.map_rounded,
          ];
        case GameId.villageMarket:
          return const <IconData>[
            Icons.storefront_rounded,
            Icons.shopping_basket_rounded,
            Icons.shopping_bag_rounded,
            Icons.nature_people_rounded,
          ];
        default:
          break;
      }
    }

    return const <IconData>[
      Icons.auto_awesome_rounded,
      Icons.star_rounded,
      Icons.explore_rounded,
    ];
  }

  ImageProvider? get _resolvedBackgroundImage {
    if (widget.backgroundImage != null) return widget.backgroundImage;
    if (widget.backgroundImageAsset != null && widget.backgroundImageAsset!.isNotEmpty) {
      return AssetImage(widget.backgroundImageAsset!);
    }
    if (widget.backgroundImageUrl != null && widget.backgroundImageUrl!.isNotEmpty) {
      return NetworkImage(widget.backgroundImageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        const double nodeSize = 48.0;
        const double rowHeight = 78.0;
        const double startY = 82.0; // Increased gap below header badge
        final List<GameLevelItem> displayLevels = _effectiveLevels;
        final int count = displayLevels.length;

        // Compute (x, y) node coordinates for a smooth serpentine S-curve path
        final List<Offset> positions = <Offset>[];
        for (int i = 0; i < count; i++) {
          final double t = count > 1 ? i / (count - 1) : 0;
          final double side = math.sin(t * math.pi * (count - 1) * 0.55);
          final double x = (width / 2) + side * (width * 0.26);
          final double y = startY + (i * rowHeight);
          positions.add(Offset(x, y));
        }

        final double contentHeight = startY + (count * rowHeight) + 50;
        final ImageProvider? bgImage = _resolvedBackgroundImage;

        return Container(
          width: width,
          height: widget.mapHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: bgImage == null
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      widget.accentColor.withValues(alpha: 0.09),
                      AppColors.surface,
                      widget.accentColor.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // 1. Custom Background Image layer (if provided)
              if (bgImage != null)
                Positioned.fill(
                  child: Image(
                    image: bgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surface,
                    ),
                  ),
                ),

              // 2. Background tint overlay (retains readable contrast over images or themes)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: bgImage != null
                          ? <Color>[
                              Colors.black.withValues(alpha: 0.45),
                              Colors.black.withValues(alpha: 0.30),
                              Colors.black.withValues(alpha: 0.55),
                            ]
                          : <Color>[
                              widget.accentColor.withValues(alpha: 0.05),
                              Colors.transparent,
                              widget.accentColor.withValues(alpha: 0.05),
                            ],
                    ),
                  ),
                ),
              ),

              // 3. Concept-themed background watermark icons (if no image specified)
              if (bgImage == null)
                Positioned.fill(
                  child: _GameConceptBackground(
                    themeIcons: _defaultThemeIcons,
                    accentColor: widget.accentColor,
                  ),
                ),

              // 4. Scrollable Serpentine Path Canvas
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: width,
                    height: contentHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // Continuous wire trail extending through all levels
                        CustomPaint(
                          size: Size(width, contentHeight),
                          painter: _ContinuousWireTrailPainter(
                            positions: positions,
                            accentColor: widget.accentColor,
                            maxUnlockedIndex: widget.maxUnlockedLevel - 1,
                            totalHeight: contentHeight,
                            hasImageBg: bgImage != null,
                          ),
                        ),

                        // Render Level Nodes along the scrollable path
                        for (int i = 0; i < count; i++) ...<Widget>[
                          _buildCompactNode(
                            index: i,
                            item: displayLevels[i],
                            position: positions[i],
                            nodeSize: nodeSize,
                            hasImageBg: bgImage != null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Header Tag & Scroll Hint (Pinned overlay at top)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgImage != null
                          ? AppColors.ink.withValues(alpha: 0.82)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.unfold_more_rounded, size: 14, color: widget.accentColor),
                        const SizedBox(width: 5),
                        Text(
                          'LEVEL PATH  •  SWIPE TO EXPLORE',
                          style: AppText.overline.copyWith(
                            color: bgImage != null ? Colors.white : widget.accentColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactNode({
    required int index,
    required GameLevelItem item,
    required Offset position,
    required double nodeSize,
    required bool hasImageBg,
  }) {
    final bool isUnlocked = item.levelNum <= widget.maxUnlockedLevel;
    final bool isSelected = item.levelNum == widget.selectedLevel;

    return Positioned(
      left: position.dx - (nodeSize / 2),
      top: position.dy - (nodeSize / 2),
      width: nodeSize,
      height: nodeSize,
      child: GestureDetector(
        onTap: isUnlocked ? () => widget.onLevelSelected(item.levelNum) : null,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (BuildContext context, Widget? child) {
            final double scale = isSelected ? 1.0 + (_pulseController.value * 0.08) : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isUnlocked
                      ? RadialGradient(
                          center: const Alignment(-0.3, -0.3),
                          radius: 0.85,
                          colors: isSelected
                              ? <Color>[
                                  Color.lerp(widget.accentColor, Colors.white, 0.35)!,
                                  widget.accentColor,
                                  Color.lerp(widget.accentColor, Colors.black, 0.2)!,
                                ]
                              : <Color>[
                                  Colors.white,
                                  widget.accentColor.withValues(alpha: 0.15),
                                  widget.accentColor.withValues(alpha: 0.4),
                                ],
                        )
                      : RadialGradient(
                          center: const Alignment(-0.3, -0.3),
                          radius: 0.8,
                          colors: hasImageBg
                              ? <Color>[
                                  Colors.black45,
                                  Colors.black54,
                                  Colors.black87,
                                ]
                              : <Color>[
                                  Colors.grey.shade200,
                                  Colors.grey.shade300,
                                  Colors.grey.shade400,
                                ],
                        ),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : (isUnlocked
                            ? widget.accentColor
                            : (hasImageBg ? Colors.white38 : Colors.grey.shade400)),
                    width: isSelected ? 3.5 : 2.0,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isSelected
                          ? widget.accentColor.withValues(alpha: 0.5)
                          : (isUnlocked
                              ? AppColors.ink.withValues(alpha: 0.12)
                              : Colors.transparent),
                      blurRadius: isSelected ? 10 : 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: isUnlocked
                      ? Text(
                          '${item.levelNum}',
                          style: AppText.h2.copyWith(
                            color: isSelected ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.0,
                            shadows: isSelected
                                ? <Shadow>[
                                    const Shadow(
                                      blurRadius: 3,
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: hasImageBg ? Colors.white70 : Colors.grey.shade700,
                            ),
                            Text(
                              '${item.levelNum}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: hasImageBg ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget rendering theme-specific watermark concept icons in the card background.
class _GameConceptBackground extends StatelessWidget {
  const _GameConceptBackground({
    required this.themeIcons,
    required this.accentColor,
  });

  final List<IconData> themeIcons;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (themeIcons.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: <Widget>[
        Positioned(
          top: 30,
          right: 18,
          child: Icon(
            themeIcons[0 % themeIcons.length],
            size: 42,
            color: accentColor.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          top: 130,
          left: 16,
          child: Icon(
            themeIcons[1 % themeIcons.length],
            size: 38,
            color: accentColor.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          top: 230,
          right: 22,
          child: Icon(
            themeIcons[2 % themeIcons.length],
            size: 44,
            color: accentColor.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          top: 330,
          left: 20,
          child: Icon(
            themeIcons[(3 < themeIcons.length ? 3 : 0)],
            size: 40,
            color: accentColor.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          top: 440,
          right: 28,
          child: Icon(
            themeIcons[4 % themeIcons.length],
            size: 42,
            color: accentColor.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

/// Painter for the continuous thin wire trail that extends beyond Level 5.
class _ContinuousWireTrailPainter extends CustomPainter {
  _ContinuousWireTrailPainter({
    required this.positions,
    required this.accentColor,
    required this.maxUnlockedIndex,
    required this.totalHeight,
    required this.hasImageBg,
  });

  final List<Offset> positions;
  final Color accentColor;
  final int maxUnlockedIndex;
  final double totalHeight;
  final bool hasImageBg;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final Path fullPath = Path();

    // Start path slightly above level 1
    final Offset p1 = positions[0];
    fullPath.moveTo(p1.dx, p1.dy - 20);
    fullPath.lineTo(p1.dx, p1.dy);

    for (int i = 0; i < positions.length - 1; i++) {
      final Offset pStart = positions[i];
      final Offset pEnd = positions[i + 1];
      final double midY = (pStart.dy + pEnd.dy) / 2;
      fullPath.cubicTo(pStart.dx, midY, pEnd.dx, midY, pEnd.dx, pEnd.dy);
    }

    // Extend path smoothly beyond last level to show continuation!
    final Offset pLast = positions.last;
    final Offset pPrev = positions[positions.length - 2];
    final double extendX = pLast.dx + (pLast.dx - pPrev.dx) * 0.4;
    final double extendY = totalHeight - 14;

    fullPath.cubicTo(
      pLast.dx, (pLast.dy + extendY) / 2,
      extendX, extendY - 10,
      extendX, extendY,
    );

    // 1. Thin Outer Casing Shadow
    final Paint casingPaint = Paint()
      ..color = hasImageBg ? Colors.black45 : AppColors.ink.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(fullPath, casingPaint);

    // 2. Base Wire Line (for locked segments)
    final Paint baseWirePaint = Paint()
      ..color = hasImageBg ? Colors.white38 : AppColors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(fullPath, baseWirePaint);

    // 3. Unlocked Active Wire Highlight
    final Path activePath = Path();
    activePath.moveTo(p1.dx, p1.dy - 20);
    activePath.lineTo(p1.dx, p1.dy);

    final int limit = math.min(maxUnlockedIndex, positions.length - 1);
    for (int i = 0; i < limit; i++) {
      final Offset pStart = positions[i];
      final Offset pEnd = positions[i + 1];
      final double midY = (pStart.dy + pEnd.dy) / 2;
      activePath.cubicTo(pStart.dx, midY, pEnd.dx, midY, pEnd.dx, pEnd.dy);
    }

    final Paint activeWirePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activeWirePaint);

    // 4. Continuation indicator dots at the end
    final Paint dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(extendX, extendY + 6), 2.5, dotPaint);
    canvas.drawCircle(Offset(extendX, extendY + 14), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ContinuousWireTrailPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.maxUnlockedIndex != maxUnlockedIndex ||
        oldDelegate.totalHeight != totalHeight ||
        oldDelegate.hasImageBg != hasImageBg;
  }
}

