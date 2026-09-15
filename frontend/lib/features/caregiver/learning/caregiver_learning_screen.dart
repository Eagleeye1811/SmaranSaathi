import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/motifs.dart';
import 'data/learning_repository.dart';
import 'models/learning_models.dart';
import 'widgets/faq_section.dart';
import 'widgets/personalized_qa_section.dart';
import 'widgets/video_tutorial_card.dart';

/// Caregiver Learning & Counseling Hub Screen.
///
/// Provides Caregiver Knowledge Hub (FAQs), expert video tutorials,
/// personalized patient AI consultation Q&A, and practical care checklists.
class CaregiverLearningScreen extends StatefulWidget {
  const CaregiverLearningScreen({super.key});

  @override
  State<CaregiverLearningScreen> createState() => _CaregiverLearningScreenState();
}

class _CaregiverLearningScreenState extends State<CaregiverLearningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Caregiver Learning & Counseling',
                style: AppText.h3.copyWith(fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppText.body.wght(700).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const <Tab>[
            Tab(text: 'Caregiver Knowledge Hub', icon: Icon(Icons.lightbulb_rounded, size: 18)),
            Tab(text: 'Video Tutorials', icon: Icon(Icons.ondemand_video_rounded, size: 18)),
            Tab(text: 'Personalized Q&A', icon: Icon(Icons.psychology_rounded, size: 18)),
            Tab(text: 'Care Toolkits', icon: Icon(Icons.fact_check_rounded, size: 18)),
          ],
        ),
      ),
      body: MotifBackground(
        opacity: 0.04,
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            // ── Tab 1: Caregiver Knowledge Hub (FAQs) ────────────────────
            _buildFaqTab(),

            // ── Tab 2: Expert Video Tutorials ────────────────────────────
            _buildVideoTutorialsTab(),

            // ── Tab 3: Personalized Patient Q&A ──────────────────────────
            _buildPersonalizedQATab(state),

            // ── Tab 4: Care Toolkits & Checklists ────────────────────────
            _buildToolkitsTab(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 1: Caregiver Knowledge Hub (Formerly FAQs)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFaqTab() {
    return ListView(
      padding: const EdgeInsets.all(Insets.gutter),
      children: <Widget>[
        FaqSectionWidget(faqs: LearningRepository.faqs),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 2: Expert Video Tutorials
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildVideoTutorialsTab() {
    final List<VideoTutorial> videos = LearningRepository.videoTutorials;

    return ListView(
      padding: const EdgeInsets.all(Insets.gutter),
      children: <Widget>[
        ...videos.map((VideoTutorial video) => VideoTutorialCard(video: video)),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 3: Personalized Patient Q&A
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPersonalizedQATab(AppState state) {
    return ListView(
      padding: const EdgeInsets.all(Insets.gutter),
      children: <Widget>[
        PersonalizedQASectionWidget(state: state),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 4: Toolkits & Interactive Checklists
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildToolkitsTab() {
    final List<CaregiverChecklist> checklists = LearningRepository.checklists;

    return ListView(
      padding: const EdgeInsets.all(Insets.gutter),
      children: <Widget>[
        ...checklists.map((CaregiverChecklist chk) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.hairline),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(chk.category.icon, color: AppColors.secondary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        chk.title,
                        style: AppText.h3.copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chk.description,
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                ...chk.items.map((ChecklistItem item) {
                  return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setStateItem) {
                      return CheckboxListTile(
                        value: item.isChecked,
                        onChanged: (bool? val) {
                          setStateItem(() => item.isChecked = val ?? false);
                        },
                        title: Text(
                          item.title,
                          style: AppText.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration:
                                item.isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: AppText.caption.copyWith(color: AppColors.inkMuted),
                        ),
                        activeColor: AppColors.secondary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    },
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
