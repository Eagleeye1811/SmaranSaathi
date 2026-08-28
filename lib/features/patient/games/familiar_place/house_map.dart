import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';

/// One room in the top-view house.
class Room {
  const Room({
    required this.id,
    required this.name,
    required this.rect,
    required this.icon,
    required this.objects,
    required this.floor,
  });

  final String id;
  final String name;

  /// Position in a 0..1 × 0..1 floor-plan space.
  final Rect rect;
  final IconData icon;
  final List<RoomObject> objects;
  final Color floor;
}

class RoomObject {
  const RoomObject({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

/// A 2-D top view of a familiar Assam-type house, drawn rather than
/// photographed so it reads clearly at any size and in high contrast.
class HouseMap extends StatelessWidget {
  const HouseMap({
    super.key,
    required this.rooms,
    required this.currentIndex,
    required this.visited,
    this.height = 190,
  });

  final List<Room> rooms;
  final int currentIndex;
  final Set<String> visited;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: currentIndex.toDouble()),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
        builder: (BuildContext context, double pos, _) {
          return CustomPaint(
            painter: _HousePainter(rooms: rooms, position: pos, visited: visited),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _HousePainter extends CustomPainter {
  _HousePainter({required this.rooms, required this.position, required this.visited});

  final List<Room> rooms;
  final double position;
  final Set<String> visited;

  @override
  void paint(Canvas canvas, Size size) {
    const double pad = 10;
    final Rect plan = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);

    Rect place(Rect r) => Rect.fromLTWH(
          plan.left + r.left * plan.width,
          plan.top + r.top * plan.height,
          r.width * plan.width,
          r.height * plan.height,
        );

    // outer wall
    canvas.drawRRect(
      RRect.fromRectAndRadius(plan.inflate(4), const Radius.circular(16)),
      Paint()
        ..color = AppColors.inkSoft.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final int current = position.round().clamp(0, rooms.length - 1);

    for (int i = 0; i < rooms.length; i++) {
      final Room room = rooms[i];
      final Rect r = place(room.rect);
      final bool isCurrent = i == current;
      final bool seen = visited.contains(room.id);

      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(10)),
        Paint()
          ..color = isCurrent
              ? room.floor
              : (seen ? room.floor.withValues(alpha: 0.42) : AppColors.surfaceMuted),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(10)),
        Paint()
          ..color = isCurrent ? AppColors.secondary : AppColors.hairline
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 2.6 : 1.2,
      );

      // room label
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: room.name,
          style: AppText.caption
              .sized(r.width > 74 ? 11.5 : 9.5)
              .wght(isCurrent ? 800 : 600)
              .tint(isCurrent ? AppColors.secondary : AppColors.inkMuted),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: r.width - 8);
      tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.bottom - tp.height - 7));

      if (seen && !isCurrent) {
        canvas.drawCircle(
          Offset(r.right - 12, r.top + 12),
          6,
          Paint()..color = AppColors.success.withValues(alpha: 0.85),
        );
      }
    }

    // the walking figure, interpolated between rooms
    final int from = position.floor().clamp(0, rooms.length - 1);
    final int to = position.ceil().clamp(0, rooms.length - 1);
    final double t = position - from;
    final Offset a = place(rooms[from].rect).center;
    final Offset b = place(rooms[to].rect).center;
    final Offset c = Offset.lerp(a, b, t)! - const Offset(0, 6);

    canvas.drawCircle(c, 15, Paint()..color = AppColors.secondary.withValues(alpha: 0.18));
    canvas.drawCircle(c + const Offset(0, 4), 6.5, Paint()..color = AppColors.secondary);
    canvas.drawCircle(c - const Offset(0, 6), 5, Paint()..color = const Color(0xFFD9A277));
    canvas.drawArc(
      Rect.fromCenter(center: c - const Offset(0, 7), width: 11, height: 10),
      3.34,
      2.6,
      false,
      Paint()
        ..color = const Color(0xFF3A322B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HousePainter old) =>
      old.position != position || old.visited.length != visited.length;
}

/// A large, high-contrast object tile — the only thing the patient taps.
class ObjectTile extends StatelessWidget {
  const ObjectTile({
    super.key,
    required this.object,
    required this.onTap,
    this.found = false,
    this.dismissed = false,
    this.hinted = false,
    this.compact = false,
  });

  final RoomObject object;
  final VoidCallback? onTap;
  final bool found;
  final bool dismissed;
  final bool hinted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = found ? AppColors.success : object.color;
    return Opacity(
      opacity: dismissed ? 0.42 : 1,
      child: GestureDetector(
        onTap: found || dismissed ? null : onTap,
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14, horizontal: 6),
          decoration: BoxDecoration(
            color: found ? AppColors.successTint : Colors.white,
            borderRadius: Corners.r(Corners.md),
            border: Border.all(
              color: found
                  ? AppColors.success
                  : (hinted ? AppColors.accent : AppColors.hairline),
              width: found || hinted ? 2.2 : 1.3,
            ),
            boxShadow: found ? null : AppColors.softShadow(y: 3, blur: 9, opacity: 0.045),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: compact ? 40 : 54,
                    height: compact ? 40 : 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(object.icon, size: compact ? 22 : 29, color: color),
                  ),
                  if (found)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 5 : 8),
              Text(
                object.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.sized(compact ? 12.5 : 14.5).wght(found ? 800 : 600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
