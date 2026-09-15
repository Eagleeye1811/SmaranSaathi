import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'market_stalls.dart';

/// The market floor: every open stall shown at once as a directly-tappable
/// region, positioned by its fractional [Stall.rect]. Unlike Familiar
/// Place's rooms (stepped through in sequence via a "next room" button),
/// the patient can walk to any stall directly — matching "there are many
/// stalls" and free, unforced exploration.
class MarketMap extends StatelessWidget {
  const MarketMap({
    super.key,
    required this.stalls,
    required this.selectedId,
    required this.visited,
    required this.onSelect,
    this.height = 220,
  });

  final List<Stall> stalls;
  final String? selectedId;
  final Set<String> visited;
  final ValueChanged<String> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Corners.r(Corners.md),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[AppColors.oliveTint, AppColors.surfaceMuted],
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            return Stack(
              children: <Widget>[
                for (final Stall s in stalls)
                  Positioned(
                    left: s.rect.left * c.maxWidth,
                    top: s.rect.top * c.maxHeight,
                    width: s.rect.width * c.maxWidth,
                    height: s.rect.height * c.maxHeight,
                    child: _StallBox(
                      stall: s,
                      selected: s.id == selectedId,
                      visited: visited.contains(s.id),
                      onTap: () => onSelect(s.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StallBox extends StatelessWidget {
  const _StallBox({
    required this.stall,
    required this.selected,
    required this.visited,
    required this.onTap,
  });

  final Stall stall;
  final bool selected;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? stall.awning.withValues(alpha: 0.16) : Colors.white,
            borderRadius: Corners.r(Corners.md),
            border: Border.all(
              color: selected ? stall.awning : AppColors.hairline,
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: AppColors.softShadow(y: 2, blur: 7, opacity: 0.05),
          ),
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: stall.awning.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(stall.icon, color: stall.awning, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        stall.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.wght(selected ? 800 : 600),
                      ),
                    ),
                  ],
                ),
              ),
              if (visited)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable item at a stall — visually close to Familiar Place's
/// `ObjectTile`, plus a real price tag deducted from the patient's budget on
/// purchase. Picking any item is never "wrong": [inBasket] items show a
/// checkmark, everything else stays fully interactive — there is no
/// dismissed/disabled state (a purchase the budget can't cover is simply
/// declined with a gentle message, not shown as a disabled tile).
class MarketItemTile extends StatelessWidget {
  const MarketItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.inBasket = false,
  });

  final MarketItem item;
  final VoidCallback? onTap;
  final bool inBasket;

  @override
  Widget build(BuildContext context) {
    final Color color = inBasket ? AppColors.success : item.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: inBasket ? AppColors.successTint : Colors.white,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(
            color: inBasket ? AppColors.success : AppColors.hairline,
            width: inBasket ? 2.2 : 1.3,
          ),
          boxShadow: inBasket ? null : AppColors.softShadow(y: 3, blur: 9, opacity: 0.045),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(item.icon, size: 26, color: color),
                ),
                if (inBasket)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.sized(12.5).wght(inBasket ? 800 : 600),
            ),
            const SizedBox(height: 2),
            Text(AppLocalizations.of(context).gameVillageMarketPriceTag(item.price),
                style: AppText.caption.sized(10.5).tint(AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
