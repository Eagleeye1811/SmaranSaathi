import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wellness.dart';
import '../../../../core/widgets/ui_kit.dart';
import 'meditation_player_screen.dart';

/// Section component displaying Guided Meditations matching single solid color app theme.
class MeditationCornerSection extends StatefulWidget {
  const MeditationCornerSection({super.key});

  @override
  State<MeditationCornerSection> createState() => _MeditationCornerSectionState();
}

class _MeditationCornerSectionState extends State<MeditationCornerSection> {
  String _selectedFilter = 'All';

  static const List<String> _filters = <String>['All', 'Relax', 'Mindfulness', 'Sleep', 'Gratitude'];

  @override
  Widget build(BuildContext context) {
    final List<GuidedMeditation> meditations = WellnessRepositoryData.guidedMeditations.where((m) {
      if (_selectedFilter == 'All') return true;
      return m.category.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    final GuidedMeditation todaysPick = WellnessRepositoryData.guidedMeditations.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Afternoon pause. Find your center.',
          style: AppText.body.tint(AppColors.inkMuted),
        ),
        const SizedBox(height: Insets.md),

        // "Today's Pick" Hero card - single solid color design
        MmCard(
          onTap: () => Nav.open(context, MeditationPlayerScreen(meditation: todaysPick)),
          padding: const EdgeInsets.all(Insets.lg),
          border: Border.all(color: AppColors.hairline),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        PillTag(
                          label: todaysPick.category,
                          color: AppColors.primary,
                          dense: true,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: Corners.r(Corners.sm),
                          ),
                          child: Text(
                            "Today's Pick",
                            style: AppText.caption.tint(AppColors.primaryDeep).wght(800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      todaysPick.title,
                      style: AppText.h2.tint(AppColors.ink).wght(800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.access_time_rounded, size: 16, color: AppColors.inkMuted),
                        const SizedBox(width: 6),
                        Text(
                          '${todaysPick.durationMinutes} min',
                          style: AppText.caption.tint(AppColors.inkMuted).wght(600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        // Filter chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final String filter in _filters) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (bool selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedFilter == filter ? Colors.white : AppColors.inkSoft,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        // 2-Column Grid of Meditation cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.85,
          ),
          itemCount: meditations.length,
          itemBuilder: (BuildContext context, int index) {
            final GuidedMeditation item = meditations[index];
            return _MeditationGridCard(
              title: item.title,
              category: item.category,
              durationMinutes: item.durationMinutes,
              onTap: () => Nav.open(context, MeditationPlayerScreen(meditation: item)),
            );
          },
        ),
      ],
    );
  }
}

/// 2-Column Card matching single solid color app theme
class _MeditationGridCard extends StatefulWidget {
  const _MeditationGridCard({
    required this.title,
    required this.category,
    required this.durationMinutes,
    required this.onTap,
  });

  final String title;
  final String category;
  final int durationMinutes;
  final VoidCallback onTap;

  @override
  State<_MeditationGridCard> createState() => _MeditationGridCardState();
}

class _MeditationGridCardState extends State<_MeditationGridCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(Insets.md),
      border: Border.all(color: AppColors.hairline),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: PillTag(
                  label: widget.category,
                  color: AppColors.primary,
                  dense: true,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isFavorite = !_isFavorite),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: AppText.h3.sized(16).tint(AppColors.ink).wght(800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.durationMinutes} min',
                        style: AppText.caption.tint(AppColors.inkMuted).wght(700),
                      ),
                    ],
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
