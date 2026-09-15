import 'package:flutter/material.dart';

/// Categories of caregiver educational & counselling content.
enum LearningCategory {
  dementiaBasics,
  behaviorManagement,
  dailyCareAndHygiene,
  communication,
  homeSafety,
  selfCareAndBurnout,
  legalAndFinancial,
}

extension LearningCategoryX on LearningCategory {
  String get displayName {
    switch (this) {
      case LearningCategory.dementiaBasics:
        return 'Dementia Basics';
      case LearningCategory.behaviorManagement:
        return 'Behavior Management';
      case LearningCategory.dailyCareAndHygiene:
        return 'Daily Care & Hygiene';
      case LearningCategory.communication:
        return 'Communication';
      case LearningCategory.homeSafety:
        return 'Home Safety';
      case LearningCategory.selfCareAndBurnout:
        return 'Self-Care & Burnout';
      case LearningCategory.legalAndFinancial:
        return 'Legal & Financial';
    }
  }

  IconData get icon {
    switch (this) {
      case LearningCategory.dementiaBasics:
        return Icons.psychology_rounded;
      case LearningCategory.behaviorManagement:
        return Icons.sentiment_satisfied_alt_rounded;
      case LearningCategory.dailyCareAndHygiene:
        return Icons.wash_rounded;
      case LearningCategory.communication:
        return Icons.forum_rounded;
      case LearningCategory.homeSafety:
        return Icons.security_rounded;
      case LearningCategory.selfCareAndBurnout:
        return Icons.favorite_rounded;
      case LearningCategory.legalAndFinancial:
        return Icons.gavel_rounded;
    }
  }
}

/// A single step in a photo-based visual guide.
class PhotoGuideStep {
  const PhotoGuideStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.imageUrl,
    this.icon = Icons.info_outline_rounded,
    this.proTip,
  });

  final int stepNumber;
  final String title;
  final String description;
  final String? imageUrl;
  final IconData icon;
  final String? proTip;
}

/// Photo-based step-by-step visual caregiving guide.
class VisualGuide {
  const VisualGuide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.estimatedMinutes,
    required this.steps,
    this.coverImageUrl,
    this.badgeText = 'Photo Guide',
  });

  final String id;
  final String title;
  final String subtitle;
  final LearningCategory category;
  final int estimatedMinutes;
  final List<PhotoGuideStep> steps;
  final String? coverImageUrl;
  final String badgeText;
}

/// Video-based tutorial for caregivers.
class VideoTutorial {
  const VideoTutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.instructorName,
    required this.instructorRole,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String description;
  final LearningCategory category;
  final int durationMinutes;
  final String instructorName;
  final String instructorRole;
  final String videoUrl;
  final String? thumbnailUrl;
}

/// Frequently asked question item for caregivers.
class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.keyTakeaways = const <String>[],
  });

  final String id;
  final String question;
  final String answer;
  final LearningCategory category;
  final List<String> keyTakeaways;
}

/// Personalized query & consultation item for a paired patient.
class PersonalizedQAQuery {
  PersonalizedQAQuery({
    required this.id,
    required this.question,
    required this.answer,
    required this.timestamp,
    this.patientName,
    this.suggestedActions = const <String>[],
  });

  final String id;
  final String question;
  final String answer;
  final DateTime timestamp;
  final String? patientName;
  final List<String> suggestedActions;
}

/// Caregiver stress assessment screening question.
class CaregiverQuizQuestion {
  const CaregiverQuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
  });

  final String id;
  final String questionText;
  final List<CaregiverQuizOption> options;
}

class CaregiverQuizOption {
  const CaregiverQuizOption({
    required this.text,
    required this.score,
  });

  final String text;
  final int score;
}

/// Caregiver stress screening result and counseling advice.
class StressLevelResult {
  const StressLevelResult({
    required this.title,
    required this.level,
    required this.description,
    required this.counselingTips,
    required this.color,
  });

  final String title;
  final String level; // Low, Moderate, High, Severe
  final String description;
  final List<String> counselingTips;
  final Color color;
}

/// Interactive caregiver checklist item.
class ChecklistItem {
  ChecklistItem({
    required this.title,
    required this.subtitle,
    this.isChecked = false,
  });

  final String title;
  final String subtitle;
  bool isChecked;
}

class CaregiverChecklist {
  CaregiverChecklist({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.items,
  });

  final String id;
  final String title;
  final String description;
  final LearningCategory category;
  final List<ChecklistItem> items;
}
