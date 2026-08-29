import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/memory_fragment.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';

/// The reward space for the memory companion: one room per [MemoryCategory],
/// furnished — not scored — by whatever the patient has actually shared with
/// Mitra. There is nothing to get wrong here; a room with nothing in it yet
/// is just a room waiting, not a failure.
class MemoryHomeScreen extends StatelessWidget {
  const MemoryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<MemoryFragment> all = state.memoryFragments;
    final Map<MemoryCategory, List<MemoryFragment>> byCategory = <MemoryCategory, List<MemoryFragment>>{
      for (final MemoryCategory c in MemoryCategory.values)
        c: all.where((MemoryFragment f) => f.category == c).toList(growable: false),
    };
    final int furnished = byCategory.values.where((List<MemoryFragment> v) => v.isNotEmpty).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: MotifBackground(
          opacity: 0.04,
          color: AppColors.terracotta,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.md, Insets.gutter, Insets.sm),
                  child: ScreenHeader(
                    eyebrow: l.memoryHomeEyebrow,
                    title: l.memoryHomeTitle,
                    subtitle: furnished == 0
                        ? l.memoryHomeSubtitleEmpty
                        : l.memoryHomeSubtitleProgress(furnished, MemoryCategory.values.length),
                    leading: RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                  child: WovenStrip(
                    height: 10,
                    colors: const <Color>[
                      AppColors.terracotta,
                      AppColors.accent,
                      AppColors.primary,
                      AppColors.plum,
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Insets.sm,
                    crossAxisSpacing: Insets.sm,
                    childAspectRatio: 0.86,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int i) {
                      final MemoryCategory category = MemoryCategory.values[i];
                      return _RoomCard(
                        category: category,
                        fragments: byCategory[category]!,
                        onTap: () => _openRoom(context, category, byCategory[category]!),
                      );
                    },
                    childCount: MemoryCategory.values.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoom(BuildContext context, MemoryCategory category, List<MemoryFragment> fragments) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RoomDetailSheet(category: category, fragments: fragments),
    );
  }
}

/// One tappable room. The woven tile itself is [MemoryFragment]-agnostic —
/// its palette and seed are fixed per category — while [faded] (no fragments
/// yet) is the only thing that changes how it reads visually, so an empty
/// room still looks like part of the same house, just unlit.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.category, required this.fragments, required this.onTap});

  final MemoryCategory category;
  final List<MemoryFragment> fragments;
  final VoidCallback onTap;

  static const Map<MemoryCategory, IconData> _icons = <MemoryCategory, IconData>{
    MemoryCategory.family: Icons.groups_rounded,
    MemoryCategory.childhood: Icons.child_care_rounded,
    MemoryCategory.work: Icons.handyman_rounded,
    MemoryCategory.festivals: Icons.celebration_rounded,
    MemoryCategory.food: Icons.restaurant_rounded,
    MemoryCategory.village: Icons.holiday_village_rounded,
  };

  static const Map<MemoryCategory, List<Color>> _palettes = <MemoryCategory, List<Color>>{
    MemoryCategory.family: <Color>[AppColors.terracottaTint, AppColors.terracotta, AppColors.plum],
    MemoryCategory.childhood: <Color>[AppColors.accentTint, AppColors.accent, AppColors.terracotta],
    MemoryCategory.work: <Color>[AppColors.indigoTint, AppColors.indigo, AppColors.primary],
    MemoryCategory.festivals: <Color>[AppColors.plumTint, AppColors.plum, AppColors.accent],
    MemoryCategory.food: <Color>[AppColors.successTint, AppColors.success, AppColors.accent],
    MemoryCategory.village: <Color>[AppColors.primaryTint, AppColors.primary, AppColors.secondary],
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool furnished = fragments.isNotEmpty;
    final List<Color> palette = _palettes[category]!;

    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Corners.r(Corners.lg),
          boxShadow: AppColors.softShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            WeaveTile(seed: category.index * 7 + 3, palette: palette, faded: !furnished),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: furnished ? 0.42 : 0.30),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icons[category], size: 16, color: palette[1]),
              ),
            ),
            if (furnished)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: Corners.r(Corners.pill),
                  ),
                  child: Text('${fragments.length}',
                      style: AppText.caption.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(category.localizedLabel(l),
                      style: AppText.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    furnished ? l.memoryHomeTapToLookInside : l.memoryHomeNotFurnishedYet,
                    style: AppText.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
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

/// What's inside one room — every story shared under that category, oldest
/// first, so it reads like a life unfolding rather than a log.
class _RoomDetailSheet extends StatelessWidget {
  const _RoomDetailSheet({required this.category, required this.fragments});

  final MemoryCategory category;
  final List<MemoryFragment> fragments;

  static String _shortDate(DateTime d, AppLocalizations l) {
    final List<String> months = <String>[
      l.caregiverMonthJan, l.caregiverMonthFeb, l.caregiverMonthMar, l.caregiverMonthApr,
      l.caregiverMonthMay, l.caregiverMonthJun, l.caregiverMonthJul, l.caregiverMonthAug,
      l.caregiverMonthSep, l.caregiverMonthOct, l.caregiverMonthNov, l.caregiverMonthDec,
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (BuildContext context, ScrollController scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: Corners.r(Corners.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(category.localizedLabel(l), style: AppText.h2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: fragments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                        child: Center(
                          child: Text(
                            category.localizedEmptyRoomLabel(l),
                            textAlign: TextAlign.center,
                            style: AppText.body.copyWith(color: AppColors.inkSoft),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(
                            Insets.gutter, 0, Insets.gutter, Insets.lg),
                        itemCount: fragments.length,
                        itemBuilder: (BuildContext context, int i) {
                          final MemoryFragment f = fragments[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Insets.sm),
                            child: MmCard(
                              padding: const EdgeInsets.all(Insets.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(f.summary, style: AppText.body.copyWith(height: 1.45)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: <Widget>[
                                      Text(l.memoryHomeSharedOn(_shortDate(f.createdAt, l)),
                                          style: AppText.caption),
                                      if (f.mentionedName != null)
                                        Text('· ${f.mentionedName}', style: AppText.caption),
                                      if (f.timesResurfaced > 0)
                                        Text(l.memoryHomeRevisitedCount(f.timesResurfaced),
                                            style: AppText.caption),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
