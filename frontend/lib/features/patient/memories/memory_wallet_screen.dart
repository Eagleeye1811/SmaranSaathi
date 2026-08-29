import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/memory_fragment.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../widgets/patient_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';

/// "My Memories" — the memory wallet.
///
/// The point of this screen is not utility, it is recognition: everything the
/// app knows about this person, shown back to them as something warm.
class MemoryWalletScreen extends StatefulWidget {
  const MemoryWalletScreen({super.key});

  @override
  State<MemoryWalletScreen> createState() => _MemoryWalletScreenState();
}

enum _Tab { family, places, stories, favourites, all }

class _MemoryWalletScreenState extends State<MemoryWalletScreen> {
  _Tab _tab = _Tab.family;

  static Map<_Tab, ({String label, IconData icon})> _tabsFor(AppLocalizations l) =>
      <_Tab, ({String label, IconData icon})>{
        _Tab.family: (label: l.walletTabFamily, icon: Icons.favorite_rounded),
        _Tab.places: (label: l.walletTabPlaces, icon: Icons.place_rounded),
        _Tab.stories: (label: l.walletTabStories, icon: Icons.auto_stories_rounded),
        _Tab.favourites: (label: l.walletTabFavourites, icon: Icons.star_rounded),
        _Tab.all: (label: l.walletTabAll, icon: Icons.photo_library_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final Patient p = state.patient;

    return MotifBackground(
      opacity: 0.045,
      washColors: <Color>[
        AppColors.terracottaTint.withValues(alpha: 0.85),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: <Widget>[
              const PatientTopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                      child: FadeInUp(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('My Memories', style: AppText.patientTitle.sized(28)),
                            const SizedBox(height: 6),
                            Text(
                              'The people, places and things that are yours.',
                              style: AppText.body.tint(AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    SizedBox(
                      height: 46,
                      child: ListView(
                        key: const Key('wallet-tabs'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                        children: <Widget>[
                          for (final MapEntry<_Tab, ({String label, IconData icon})> e
                              in _tabs.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 9),
                              child: _TabChip(
                                label: e.value.label,
                                icon: e.value.icon,
                                selected: _tab == e.key,
                                onTap: () => setState(() => _tab = e.key),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                      child: AnimatedSwitcher(
                        duration: Motion.normal,
                        child: KeyedSubtree(
                          key: ValueKey<_Tab>(_tab),
                          child: _body(p),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(Patient p) {
    switch (_tab) {
      case _Tab.family:
        return _family(p);
      case _Tab.places:
        return _grid(p.assetsOf(MemoryAssetKind.place));
      case _Tab.stories:
        return _stories(p);
      case _Tab.favourites:
        return _favourites(p);
      case _Tab.all:
        return _grid(p.assets);
    }
  }

  Widget _family(Patient p) {
    if (p.family.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      return EmptyState(
        title: l.walletNoFamilyTitle,
        message: l.walletNoFamilyMessage,
        icon: Icons.favorite_rounded,
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < p.family.length; i++)
          FadeInUp(
            delayMs: i * 60,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MmCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppColors.softShadow(y: 4, blur: 12),
                      ),
                      child: SceneImage(
                        sceneId: p.family[i].sceneId,
                        size: 82,
                        circle: true,
                        borderColor: Colors.white,
                        borderWidth: 3,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(p.family[i].name, style: AppText.h2.sized(23)),
                          const SizedBox(height: 3),
                          PillTag(
                            label: p.family[i].relation,
                            color: AppColors.terracotta,
                            dense: true,
                          ),
                          if (p.family[i].note.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(p.family[i].note, style: AppText.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Two real sources feed this gallery: [MemoryFragment]s the patient has
  /// actually shared with Mitra (dated, so they lead, newest first) and the
  /// [LifeMemory] background a caregiver filled in during onboarding.
  /// Neither is demo filler — this is what recollecting looks like.
  Widget _stories(Patient p) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<MemoryFragment> fragments = List<MemoryFragment>.of(state.memoryFragments)
      ..sort((MemoryFragment a, MemoryFragment b) => b.createdAt.compareTo(a.createdAt));

    if (fragments.isEmpty && p.memories.isEmpty) {
      return EmptyState(
        title: l.walletNoStoriesTitle,
        message: l.walletNoStoriesMessage,
        icon: Icons.auto_stories_rounded,
      );
    }

    int delay = 0;
    return Column(
      children: <Widget>[
        for (final MemoryFragment f in fragments)
          FadeInUp(
            delayMs: (delay++) * 50,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        SoftIcon(
                          icon: f.category.icon,
                          color: AppColors.chartSeries[delay % AppColors.chartSeries.length],
                          size: 38,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(f.category.localizedLabel(l), style: AppText.h3)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(f.summary, style: AppText.patientBody.sized(18)),
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
            ),
          ),
        for (final LifeMemory m in p.memories)
          FadeInUp(
            delayMs: (delay++) * 50,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        SoftIcon(
                          icon: _storyIcon(m.category),
                          color: AppColors.chartSeries[delay % AppColors.chartSeries.length],
                          size: 38,
                        ),
                        const SizedBox(width: 12),
                        Text(m.category, style: AppText.h3),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(m.prompt, style: AppText.caption.wght(700)),
                    const SizedBox(height: 4),
                    Text(m.answer, style: AppText.patientBody.sized(18)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _shortDate(DateTime d, AppLocalizations l) {
    final List<String> months = <String>[
      l.caregiverMonthJan, l.caregiverMonthFeb, l.caregiverMonthMar, l.caregiverMonthApr,
      l.caregiverMonthMay, l.caregiverMonthJun, l.caregiverMonthJul, l.caregiverMonthAug,
      l.caregiverMonthSep, l.caregiverMonthOct, l.caregiverMonthNov, l.caregiverMonthDec,
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  IconData _storyIcon(String category) => switch (category.toLowerCase()) {
        'work' => Icons.handyman_rounded,
        'activities' => Icons.self_improvement_rounded,
        'places' => Icons.place_rounded,
        'stories' => Icons.auto_stories_rounded,
        'food' => Icons.restaurant_rounded,
        'traditions' => Icons.celebration_rounded,
        _ => Icons.favorite_rounded,
      };

  Widget _favourites(Patient p) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<({String label, String value, String scene, Color color})> items =
        <({String label, String value, String scene, Color color})>[
      if (p.favouriteActivity.isNotEmpty)
        (
          label: l.walletFavouriteActivity,
          value: p.favouriteActivity,
          scene: 'weaving',
          color: AppColors.terracotta
        ),
      if (p.favouriteFood.isNotEmpty)
        (
          label: l.walletFavouriteFood,
          value: p.favouriteFood,
          scene: 'pitha',
          color: AppColors.accent
        ),
      if (p.tradition.isNotEmpty)
        (
          label: l.walletFavouriteTradition,
          value: p.tradition,
          scene: 'bihu',
          color: AppColors.primary
        ),
      if (p.occupation.isNotEmpty)
        (
          label: l.walletHerWork,
          value: p.occupation,
          scene: 'gamosa',
          color: AppColors.plum
        ),
    ];

    if (items.isEmpty) {
      return EmptyState(
        title: l.walletNoFavouritesTitle,
        message: l.walletNoFavouritesMessage,
        icon: Icons.star_rounded,
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          FadeInUp(
            delayMs: i * 60,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MmCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: SceneImage(sceneId: items[i].scene, radius: 0, fit: false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(items[i].label.toUpperCase(),
                                style: AppText.overline.tint(items[i].color)),
                            const SizedBox(height: 6),
                            Text(items[i].value, style: AppText.h3.wght(800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(List<MemoryAsset> assets) {
    if (assets.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      return EmptyState(
        title: l.walletNothingHereTitle,
        message: l.walletNothingHereMessage,
        icon: Icons.photo_library_rounded,
      );
    }
    return Column(
      children: <Widget>[
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: assets.length,
          itemBuilder: (BuildContext context, int i) => FadeInUp(
            delayMs: (i % 6) * 50,
            child: _AssetCard(
              asset: assets[i],
              onTap: () => _showAsset(context, assets[i]),
            ),
          ),
        ),
      ],
    );
  }

  void _showAsset(BuildContext context, MemoryAsset asset) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => _AssetSheet(asset: asset),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.normal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.terracotta : Colors.white,
          borderRadius: Corners.r(Corners.pill),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.hairline,
            width: 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.inkSoft),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppText.body
                  .wght(selected ? 800 : 600)
                  .tint(selected ? Colors.white : AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onTap});
  final MemoryAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      padding: EdgeInsets.zero,
      clip: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: SceneImage(sceneId: asset.sceneId, radius: 0, fit: false)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(asset.title,
                    style: AppText.body.wght(800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  asset.year ?? asset.kind.label,
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetSheet extends StatelessWidget {
  const _AssetSheet({required this.asset});
  final MemoryAsset asset;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: Corners.r(Corners.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: Corners.r(3),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Container(
            decoration: BoxDecoration(
              borderRadius: Corners.r(Corners.lg),
              boxShadow: AppColors.liftShadow(),
            ),
            child: SceneImage(sceneId: asset.sceneId, size: 230, radius: Corners.lg),
          ),
          const SizedBox(height: Insets.lg),
          Text(asset.title, style: AppText.h1.sized(26), textAlign: TextAlign.center),
          if (asset.year != null) ...<Widget>[
            const SizedBox(height: 6),
            PillTag(label: asset.year!, color: AppColors.terracotta, dense: true),
          ],
          if (asset.caption.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(asset.caption,
                textAlign: TextAlign.center, style: AppText.patientBody.sized(18)),
          ],
          const SizedBox(height: Insets.lg),
          CompanionSpeech(
            message: l.walletTellMeAboutThis,
            state: CompanionState.listening,
            companionSize: 60,
            compact: true,
          ),
          const SizedBox(height: Insets.lg),
          BigButton(
            label: l.actionClose,
            color: AppColors.terracotta,
            outlined: true,
            height: 60,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
