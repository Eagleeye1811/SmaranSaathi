import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../models/learning_models.dart';

/// Categorized, filterable FAQ section widget for generalized caregiver questions.
class FaqSectionWidget extends StatefulWidget {
  const FaqSectionWidget({
    super.key,
    required this.faqs,
  });

  final List<FaqItem> faqs;

  @override
  State<FaqSectionWidget> createState() => _FaqSectionWidgetState();
}

class _FaqSectionWidgetState extends State<FaqSectionWidget> {
  LearningCategory? _selectedCategory;
  String _searchQuery = '';

  List<FaqItem> get _filteredFaqs {
    return widget.faqs.where((FaqItem item) {
      final bool matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;
      final bool matchesSearch = _searchQuery.isEmpty ||
          item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<FaqItem> displayList = _filteredFaqs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Search Field ──────────────────────────────────────────────
        TextField(
          onChanged: (String val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search caregiver FAQs...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Category Filter Chips ──────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              FilterChip(
                selected: _selectedCategory == null,
                label: const Text('All Topics'),
                onSelected: (_) => setState(() => _selectedCategory = null),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _selectedCategory == null ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ...LearningCategory.values.map((LearningCategory cat) {
                final bool isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Icon(cat.icon,
                        size: 16, color: isSelected ? Colors.white : AppColors.primary),
                    label: Text(cat.displayName),
                    onSelected: (_) => setState(() => _selectedCategory = isSelected ? null : cat),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── FAQ List Accordions ───────────────────────────────────────
        if (displayList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: <Widget>[
                Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No FAQs found matching your filter.',
                  style: AppText.body.wght(700).copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayList.length,
            itemBuilder: (BuildContext context, int index) {
              final FaqItem item = displayList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.category.icon, size: 18, color: AppColors.primary),
                    ),
                    title: Text(
                      item.question,
                      style: AppText.body.wght(700).copyWith(fontWeight: FontWeight.bold),
                    ),
                    children: <Widget>[
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        item.answer,
                        style: AppText.body.copyWith(height: 1.5, color: AppColors.ink),
                      ),
                      if (item.keyTakeaways.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Key Actionable Takeaways:',
                                style: AppText.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...item.keyTakeaways.map(
                                (String t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Icon(Icons.check_circle_rounded,
                                          size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(t, style: AppText.bodySmall),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
