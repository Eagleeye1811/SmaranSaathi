import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/patient.dart';

/// Whether a market item is on the day's mentioned list, a sensible but
/// optional pick, or pure impulse — never labelled as "wrong" to the
/// patient, only used internally to score list-completion and restraint.
enum MarketItemRole { needed, optional, impulse }

@immutable
class MarketItem {
  const MarketItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.price,
    required this.role,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// Shown on the tile and deducted from the patient's real, on-screen
  /// budget the moment the item is bought — see `_tapItem` in
  /// `village_market_game.dart`.
  final int price;
  final MarketItemRole role;
}

@immutable
class Stall {
  const Stall({
    required this.id,
    required this.name,
    required this.icon,
    required this.awning,
    required this.items,
    this.rect = Rect.zero,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color awning;
  final List<MarketItem> items;

  /// Position in a 0..1 × 0..1 market-floor space, filled in by
  /// [MarketContent.layoutFor] once the visible stall count is known —
  /// mirrors `Room.rect` in `familiar_place/house_map.dart`.
  final Rect rect;

  Stall withRect(Rect r) =>
      Stall(id: id, name: name, icon: icon, awning: awning, items: items, rect: r);
}

/// Content for The Village Market Adventure.
///
/// Stalls open in a fixed order as the level rises — three at level 1,
/// growing to all six by level 5 — kept in lockstep with
/// `AdaptiveDifficultyService.levelDescription` for `GameId.villageMarket`
/// and the game's own `_stallCountFor`. Prices are real: they're deducted
/// from the patient's stated starting budget as items go into the basket.
class MarketContent {
  const MarketContent._();

  static const MarketItem rice = MarketItem(
    id: 'rice',
    name: 'Rice',
    icon: Icons.rice_bowl_rounded,
    color: AppColors.olive,
    price: 40,
    role: MarketItemRole.needed,
  );
  static const MarketItem lentils = MarketItem(
    id: 'lentils',
    name: 'Lentils',
    icon: Icons.scatter_plot_rounded,
    color: AppColors.terracotta,
    price: 50,
    role: MarketItemRole.optional,
  );
  static const MarketItem puffedRice = MarketItem(
    id: 'puffed_rice',
    name: 'Puffed rice snack',
    icon: Icons.cookie_rounded,
    color: AppColors.accent,
    price: 15,
    role: MarketItemRole.impulse,
  );

  static const MarketItem vegetables = MarketItem(
    id: 'vegetables',
    name: 'Vegetables',
    icon: Icons.eco_rounded,
    color: AppColors.primary,
    price: 60,
    role: MarketItemRole.needed,
  );
  static const MarketItem potatoes = MarketItem(
    id: 'potatoes',
    name: 'Potatoes',
    icon: Icons.circle_rounded,
    color: AppColors.terracotta,
    price: 30,
    role: MarketItemRole.optional,
  );
  static const MarketItem fruit = MarketItem(
    id: 'fruit',
    name: 'Seasonal fruit',
    icon: Icons.local_florist_rounded,
    color: AppColors.accent,
    price: 45,
    role: MarketItemRole.impulse,
  );

  static const MarketItem mustardOil = MarketItem(
    id: 'mustard_oil',
    name: 'Mustard oil',
    icon: Icons.opacity_rounded,
    color: AppColors.accent,
    price: 120,
    role: MarketItemRole.needed,
  );
  static const MarketItem turmeric = MarketItem(
    id: 'turmeric',
    name: 'Turmeric',
    icon: Icons.circle_rounded,
    color: AppColors.accent,
    price: 25,
    role: MarketItemRole.optional,
  );
  static const MarketItem jaggerySweet = MarketItem(
    id: 'jaggery_sweet',
    name: 'Jaggery sweet',
    icon: Icons.cookie_rounded,
    color: AppColors.terracotta,
    price: 20,
    role: MarketItemRole.impulse,
  );

  static const MarketItem umbrella = MarketItem(
    id: 'umbrella',
    name: 'Umbrella',
    icon: Icons.umbrella_rounded,
    color: AppColors.secondary,
    price: 90,
    role: MarketItemRole.optional,
  );
  static const MarketItem gamosa = MarketItem(
    id: 'gamosa',
    name: 'Gamosa',
    icon: Icons.checkroom_rounded,
    color: AppColors.terracotta,
    price: 70,
    role: MarketItemRole.impulse,
  );
  static const MarketItem thread = MarketItem(
    id: 'thread',
    name: 'Thread',
    icon: Icons.style_rounded,
    color: AppColors.plum,
    price: 15,
    role: MarketItemRole.impulse,
  );

  static const MarketItem sweets = MarketItem(
    id: 'sweets',
    name: 'Sweets',
    icon: Icons.cake_rounded,
    color: AppColors.plum,
    price: 35,
    role: MarketItemRole.impulse,
  );
  static const MarketItem paan = MarketItem(
    id: 'paan',
    name: 'Paan',
    icon: Icons.eco_rounded,
    color: AppColors.primary,
    price: 10,
    role: MarketItemRole.impulse,
  );

  static const MarketItem basket = MarketItem(
    id: 'basket',
    name: 'Bamboo basket',
    icon: Icons.shopping_basket_rounded,
    color: AppColors.olive,
    price: 80,
    role: MarketItemRole.optional,
  );
  static const MarketItem broom = MarketItem(
    id: 'broom',
    name: 'Broom',
    icon: Icons.cleaning_services_rounded,
    color: AppColors.terracotta,
    price: 40,
    role: MarketItemRole.impulse,
  );
  static const MarketItem coinPurse = MarketItem(
    id: 'coin_purse',
    name: 'Coin purse',
    icon: Icons.savings_rounded,
    color: AppColors.indigo,
    price: 25,
    role: MarketItemRole.impulse,
  );

  /// The six stalls, in the fixed order they open as the level rises.
  /// `rect` is left at `Rect.zero` here — [layoutFor] fills it in.
  static const List<Stall> _all = <Stall>[
    Stall(
      id: 'grains',
      name: 'Rice & grains',
      icon: Icons.rice_bowl_rounded,
      awning: AppColors.olive,
      items: <MarketItem>[rice, lentils, puffedRice],
    ),
    Stall(
      id: 'produce',
      name: 'Vegetables',
      icon: Icons.eco_rounded,
      awning: AppColors.primary,
      items: <MarketItem>[vegetables, potatoes, fruit],
    ),
    Stall(
      id: 'spices',
      name: 'Oil & spices',
      icon: Icons.opacity_rounded,
      awning: AppColors.accent,
      items: <MarketItem>[mustardOil, turmeric, jaggerySweet],
    ),
    Stall(
      id: 'cloth',
      name: 'Cloth',
      icon: Icons.checkroom_rounded,
      awning: AppColors.secondary,
      items: <MarketItem>[umbrella, gamosa, thread],
    ),
    Stall(
      id: 'sweets',
      name: 'Sweets',
      icon: Icons.cake_rounded,
      awning: AppColors.plum,
      items: <MarketItem>[sweets, paan],
    ),
    Stall(
      id: 'household',
      name: 'Basket & household',
      icon: Icons.shopping_basket_rounded,
      awning: AppColors.indigo,
      items: <MarketItem>[basket, broom, coinPurse],
    ),
  ];

  /// The `count` stalls open at this level, laid out on the 0..1 market
  /// floor used by `MarketMap`.
  static List<Stall> layoutFor(int count) {
    final int n = count.clamp(3, _all.length);
    final List<Rect> rects = _rectsFor(n);
    final List<Stall> open = _all.take(n).toList(growable: false);
    return <Stall>[for (int i = 0; i < open.length; i++) open[i].withRect(rects[i])];
  }

  static List<Rect> _rectsFor(int count) => switch (count) {
        3 => const <Rect>[
            Rect.fromLTWH(0, 0, 0.31, 1.0),
            Rect.fromLTWH(0.345, 0, 0.31, 1.0),
            Rect.fromLTWH(0.69, 0, 0.31, 1.0),
          ],
        4 => const <Rect>[
            Rect.fromLTWH(0, 0, 0.48, 0.48),
            Rect.fromLTWH(0.52, 0, 0.48, 0.48),
            Rect.fromLTWH(0, 0.52, 0.48, 0.48),
            Rect.fromLTWH(0.52, 0.52, 0.48, 0.48),
          ],
        5 => const <Rect>[
            Rect.fromLTWH(0, 0, 0.31, 0.46),
            Rect.fromLTWH(0.345, 0, 0.31, 0.46),
            Rect.fromLTWH(0.69, 0, 0.31, 0.46),
            Rect.fromLTWH(0, 0.52, 0.48, 0.48),
            Rect.fromLTWH(0.52, 0.52, 0.48, 0.48),
          ],
        _ => const <Rect>[
            Rect.fromLTWH(0, 0, 0.31, 0.46),
            Rect.fromLTWH(0.345, 0, 0.31, 0.46),
            Rect.fromLTWH(0.69, 0, 0.31, 0.46),
            Rect.fromLTWH(0, 0.52, 0.31, 0.46),
            Rect.fromLTWH(0.345, 0.52, 0.31, 0.46),
            Rect.fromLTWH(0.69, 0.52, 0.31, 0.46),
          ],
      };

  /// The three fixed "needed" items mentioned by [shoppingListGiver]'s
  /// speaker — rice, vegetables and mustard oil, matching the product
  /// brief's own example. Kept fixed rather than derived, so the mentioned
  /// line Mitra says always matches what actually gets asked about later.
  static const List<MarketItem> neededItems = <MarketItem>[rice, vegetables, mustardOil];

  /// Looks up any item across all six stalls, regardless of which are
  /// currently open — used once a patient already has it in the basket.
  static MarketItem itemById(String id) {
    for (final Stall s in _all) {
      for (final MarketItem i in s.items) {
        if (i.id == id) return i;
      }
    }
    throw StateError('Unknown market item id: $id');
  }
}

/// Resolves who "gave" today's shopping list. Actually consulting the
/// patient's profile — unlike `procedure_game.dart`'s dead
/// `PersonalizationService.procedureTitle()` — so the line is genuinely
/// personal when a mother/grandmother figure is recorded, and a warm
/// default otherwise.
String shoppingListGiver(Patient patient) {
  for (final FamilyMember m in patient.family) {
    final String r = m.relation.toLowerCase();
    if (r.contains('mother') ||
        r.contains('grandmother') ||
        r.contains('aama') ||
        r.contains('maa')) {
      return m.name;
    }
  }
  return 'Aama';
}
