import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The type of wellness activity.
enum WellnessType { yoga, meditation, sound, breathing }

extension WellnessTypeX on WellnessType {
  String get label => switch (this) {
        WellnessType.yoga => 'Yoga & Stretch',
        WellnessType.meditation => 'Guided Meditation',
        WellnessType.sound => 'Calming Sounds',
        WellnessType.breathing => 'Controlled Breathing',
      };

  IconData get icon => switch (this) {
        WellnessType.yoga => Icons.self_improvement_rounded,
        WellnessType.meditation => Icons.spa_rounded,
        WellnessType.sound => Icons.graphic_eq_rounded,
        WellnessType.breathing => Icons.air_rounded,
      };

  Color get color => switch (this) {
        WellnessType.yoga => AppColors.primary,
        WellnessType.meditation => AppColors.plum,
        WellnessType.sound => AppColors.secondary,
        WellnessType.breathing => AppColors.terracotta,
      };
}

/// A gentle yoga pose suitable for elderly patients.
class YogaPose {
  const YogaPose({
    required this.id,
    required this.name,
    required this.sanskritName,
    required this.description,
    required this.benefits,
    required this.steps,
    required this.durationMinutes,
    required this.icon,
    required this.color,
    this.keyPointGuide = 'Keep your back straight and shoulders relaxed',
    this.videoAssetPath,
  });

  final String id;
  final String name;
  final String sanskritName;
  final String description;
  final List<String> benefits;
  final List<String> steps;
  final int durationMinutes;
  final IconData icon;
  final Color color;
  final String keyPointGuide;
  final String? videoAssetPath;
}

/// Guided mental relaxation exercise.
class GuidedMeditation {
  const GuidedMeditation({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.durationMinutes,
    required this.icon,
    required this.color,
    required this.audioGuidance,
    this.audioAssetPath,
  });

  final String id;
  final String title;
  final String category; // e.g. 'Mindfulness', 'Sleep', 'Gratitude'
  final String description;
  final int durationMinutes;
  final IconData icon;
  final Color color;
  final List<String> audioGuidance;
  final String? audioAssetPath;
}

/// Nature or ambient calming audio sound.
class CalmingSound {
  const CalmingSound({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.soundTheme,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String soundTheme;
}

/// Controlled breathing technique.
class BreathingTechnique {
  const BreathingTechnique({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
    required this.holdAfterExhaleSeconds,
    required this.recommendedCycles,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;
  final int holdAfterExhaleSeconds;
  final int recommendedCycles;
  final IconData icon;
  final Color color;
}

/// Record of a completed wellness session.
class WellnessSession {
  const WellnessSession({
    required this.id,
    required this.type,
    required this.title,
    required this.durationSeconds,
    required this.timestamp,
    this.caregiverNote,
    this.postureScore = 1.0,
  });

  final String id;
  final WellnessType type;
  final String title;
  final int durationSeconds;
  final DateTime timestamp;
  final String? caregiverNote;
  final double postureScore;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'durationSeconds': durationSeconds,
        'timestamp': timestamp.toIso8601String(),
        'caregiverNote': caregiverNote,
        'postureScore': postureScore,
      };

  factory WellnessSession.fromJson(Map<String, dynamic> json) {
    return WellnessSession(
      id: json['id'] as String,
      type: WellnessType.values.firstWhere(
        (WellnessType t) => t.name == json['type'],
        orElse: () => WellnessType.breathing,
      ),
      title: json['title'] as String,
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      caregiverNote: json['caregiverNote'] as String?,
      postureScore: (json['postureScore'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Pre-seeded library of elderly-friendly wellness activities.
abstract class WellnessRepositoryData {
  static const List<YogaPose> yogaPoses = <YogaPose>[
    YogaPose(
      id: 'cat_cow',
      name: 'Seated Cat-Cow',
      sanskritName: 'Upavistha Bitilasana Marjaryasana',
      description: 'Inhale to arch the back and open the chest; exhale to round the spine and tuck the chin. Releases physical tension and promotes relaxation.',
      benefits: <String>[
        'Releases physical tension',
        'Improves spinal flexibility',
        'Promotes deep relaxation'
      ],
      steps: <String>[
        'Sit upright in a comfortable chair with feet flat on the floor',
        'Inhale: Arch your back gently, open your chest, and look softly upward',
        'Exhale: Round your spine, drop your shoulders, and tuck your chin toward your chest',
        'Repeat rhythmically with steady breaths for 3-5 cycles'
      ],
      durationMinutes: 3,
      icon: Icons.repeat_rounded,
      color: AppColors.primary,
      keyPointGuide: 'Inhale to arch back and open chest; exhale to round spine',
      videoAssetPath: 'assets/videos/yoga/cat_cow.mp4',
    ),
    YogaPose(
      id: 'spinal_twist',
      name: 'Seated Spinal Twist',
      sanskritName: 'Parivrtta Sukhasana',
      description: 'Gently twist the torso to each side while holding a chair backrest to improve spinal mobility and body awareness.',
      benefits: <String>[
        'Improves spinal mobility',
        'Enhances body awareness',
        'Relieves lower back stiffness'
      ],
      steps: <String>[
        'Sit tall in your chair with feet firmly grounded',
        'Place your right hand on the back or side of the chair',
        'Inhale to lengthen your spine, then exhale to twist gently to the right',
        'Hold for 3 calm breaths, return to center, and repeat on the left side'
      ],
      durationMinutes: 4,
      icon: Icons.swap_horiz_rounded,
      color: AppColors.plum,
      keyPointGuide: 'Gently twist torso to each side while holding chair backrest',
      videoAssetPath: 'assets/videos/yoga/spinal_twist.mp4',
    ),
    YogaPose(
      id: 'seated_mountain',
      name: 'Seated Mountain Pose',
      sanskritName: 'Urdhva Hastasana in Tadasana',
      description: 'Sit tall with grounded feet and deep breathing to calm the nervous system, reduce anxiety, and sharpen attention.',
      benefits: <String>[
        'Calms nervous system',
        'Reduces anxiety',
        'Sharpens attention and focus'
      ],
      steps: <String>[
        'Sit erect on the front edge of a sturdy chair with feet flat',
        'Reach arms gently upward toward the ceiling with soft shoulders',
        'Inhale deeply expanding your ribs, then exhale slowly',
        'Hold calmly for 4-5 breaths while maintaining focus'
      ],
      durationMinutes: 3,
      icon: Icons.accessibility_new_rounded,
      color: AppColors.secondary,
      keyPointGuide: 'Sit tall with grounded feet and deep calm breathing',
      videoAssetPath: 'assets/videos/yoga/seated_mountain.mp4',
    ),
    YogaPose(
      id: 'forward_fold',
      name: 'Seated Forward Fold',
      sanskritName: 'Upavistha Paschimottanasana',
      description: 'Hinge forward from the hips over the thighs to soothe restlessness and calm the brain.',
      benefits: <String>[
        'Soothes restlessness',
        'Calms the brain',
        'Gently stretches back & hips'
      ],
      steps: <String>[
        'Sit upright with legs slightly open and feet flat',
        'Inhale deeply, then exhale as you hinge forward from your hips',
        'Rest your hands or forearms softly on your thighs or knees',
        'Allow your head and neck to relax downward for 3-5 gentle breaths'
      ],
      durationMinutes: 4,
      icon: Icons.airline_seat_recline_extra_rounded,
      color: AppColors.terracotta,
      keyPointGuide: 'Hinge forward from hips over thighs to soothe restlessness',
    ),
    YogaPose(
      id: 'eagle_arms',
      name: 'Seated Eagle Arms',
      sanskritName: 'Garudasana in Upavistha',
      description: 'Cross arms at the elbows to stretch the upper back while engaging focus and coordination.',
      benefits: <String>[
        'Stretches upper back & shoulders',
        'Engages mental focus',
        'Improves joint coordination'
      ],
      steps: <String>[
        'Sit tall and bring arms out in front at shoulder height',
        'Cross your right arm over your left arm at the elbows',
        'Bend elbows and bring palms or backs of hands together',
        'Lift elbows gently, breathe deeply into shoulder blades, then switch arms'
      ],
      durationMinutes: 3,
      icon: Icons.self_improvement_rounded,
      color: AppColors.seriesTeal,
      keyPointGuide: 'Cross arms at elbows to stretch upper back and shoulders',
    ),
    YogaPose(
      id: 'legs_up_chair',
      name: 'Modified Legs-Up-The-Chair',
      sanskritName: 'Viparita Karani',
      description: 'Elevate the legs while resting to promote deep nervous system restoration and improve sleep quality.',
      benefits: <String>[
        'Deep nervous system restoration',
        'Improves sleep quality',
        'Relieves leg and ankle fatigue'
      ],
      steps: <String>[
        'Lie comfortably on your back on a soft mat or bed near a chair',
        'Rest your lower legs gently on the seat of the chair',
        'Extend arms comfortably out to the sides with palms facing up',
        'Close your eyes and breathe peacefully for 5 minutes'
      ],
      durationMinutes: 5,
      icon: Icons.airline_seat_legroom_extra_rounded,
      color: Color(0xFF8E44AD),
      keyPointGuide: 'Elevate legs on chair while resting for restoration',
    ),
  ];

  static const List<GuidedMeditation> guidedMeditations = <GuidedMeditation>[
    GuidedMeditation(
      id: 'relaxation',
      title: 'Guided Morning Relaxation',
      category: 'Relaxation',
      description: 'A gentle 5-minute verbal guidance to start your day with calm energy.',
      durationMinutes: 5,
      icon: Icons.wb_twilight_rounded,
      color: AppColors.primary,
      audioAssetPath: 'assets/audio/meditation/morning_relaxation.mp3',
      audioGuidance: <String>[
        'Welcome. Find a comfortable seated position.',
        'Take a deep inhale through your nose... and exhale softly through your mouth.',
        'Feel the tension melt away from your neck and shoulders.',
        'You are safe, supported, and surrounded by care today.',
        'Notice the peaceful stillness in your body.',
        'Whenever you are ready, gently open your eyes feeling refreshed.'
      ],
    ),
    GuidedMeditation(
      id: 'mindfulness',
      title: 'Mindful Presence & Calm',
      category: 'Mindfulness',
      description: 'Focus your mind softly on the present moment and gentle breath sounds.',
      durationMinutes: 4,
      icon: Icons.filter_vintage_rounded,
      color: AppColors.plum,
      audioAssetPath: 'assets/audio/meditation/mindful_presence.mp3',
      audioGuidance: <String>[
        'Settle in comfortably. Let your breathing find its natural pace.',
        'If thoughts float in, simply acknowledge them like clouds passing in the sky.',
        'Bring your awareness back to the warm, steady touch of your hands.',
        'Each exhale carries away any worries or fatigue.',
        'Rest in this calm moment.'
      ],
    ),
    GuidedMeditation(
      id: 'sleep',
      title: 'Peaceful Rest & Sleep Preparation',
      category: 'Sleep',
      description: 'Soothing instructions designed to prepare your mind for quiet evening rest.',
      durationMinutes: 6,
      icon: Icons.bedtime_rounded,
      color: AppColors.secondary,
      audioAssetPath: 'assets/audio/meditation/sleep_preparation.mp3',
      audioGuidance: <String>[
        'Allow your body to rest completely into your chair or bed.',
        'Relax your forehead... soften your eyes... let your jaw relax.',
        'With each breath, your body grows lighter and more relaxed.',
        'Tomorrow will take care of itself. Right now, enjoy pure rest.',
        'Sleep deeply and peacefully.'
      ],
    ),
    GuidedMeditation(
      id: 'gratitude',
      title: 'Heartfelt Gratitude Reflection',
      category: 'Gratitude',
      description: 'Reflect warmly on pleasant memories, family, and simple daily joys.',
      durationMinutes: 3,
      icon: Icons.favorite_rounded,
      color: AppColors.terracotta,
      audioAssetPath: 'assets/audio/meditation/heartfelt_gratitude.mp3',
      audioGuidance: <String>[
        'Place a hand gently on your heart.',
        'Think of one person or pleasant memory that brings warmth to your smile.',
        'Feel the gratitude filling your chest like a warm morning sun.',
        'Carry this gentle warmth with you throughout the day.'
      ],
    ),
  ];

  static const List<CalmingSound> calmingSounds = <CalmingSound>[
    CalmingSound(
      id: 'rain',
      name: 'Monsoon Rain',
      description: 'Gentle raindrops falling softly on lush leaves.',
      icon: Icons.water_drop_rounded,
      color: AppColors.secondary,
      soundTheme: 'rain',
    ),
    CalmingSound(
      id: 'waves',
      name: 'Ocean Waves',
      description: 'Rhythmic, soothing sea waves washing along a peaceful shore.',
      icon: Icons.tsunami_rounded,
      color: AppColors.primary,
      soundTheme: 'waves',
    ),
    CalmingSound(
      id: 'forest',
      name: 'Valley Birdsong',
      description: 'Soft morning birds chirping in a serene mountain garden.',
      icon: Icons.park_rounded,
      color: AppColors.seriesTeal,
      soundTheme: 'forest',
    ),
    CalmingSound(
      id: 'fireplace',
      name: 'Warm Hearth',
      description: 'Gentle crackle of a warm fireplace on a cool evening.',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.terracotta,
      soundTheme: 'fireplace',
    ),
    CalmingSound(
      id: 'flute',
      name: 'Bansuri Flute Melodies',
      description: 'Soft, soulful Indian bamboo flute notes.',
      icon: Icons.music_note_rounded,
      color: AppColors.plum,
      soundTheme: 'flute',
    ),
  ];

  static const List<BreathingTechnique> breathingTechniques = <BreathingTechnique>[
    BreathingTechnique(
      id: 'deep_breathing',
      title: 'Deep Diaphragmatic Breathing',
      subtitle: 'Gentle 4-4-4 rhythm for instant relaxation',
      description: 'Inhale deeply to expand your belly, hold softly, and exhale slowly.',
      inhaleSeconds: 4,
      holdSeconds: 4,
      exhaleSeconds: 4,
      holdAfterExhaleSeconds: 0,
      recommendedCycles: 5,
      icon: Icons.air_rounded,
      color: AppColors.primary,
    ),
    BreathingTechnique(
      id: 'box_breathing',
      title: 'Box Breathing (Samavritti)',
      subtitle: 'Equal 4-4-4-4 square breathing for focus',
      description: 'Four equal phases of breathing to calm the nervous system and enhance mental clarity.',
      inhaleSeconds: 4,
      holdSeconds: 4,
      exhaleSeconds: 4,
      holdAfterExhaleSeconds: 4,
      recommendedCycles: 4,
      icon: Icons.crop_square_rounded,
      color: AppColors.plum,
    ),
    BreathingTechnique(
      id: 'relaxation_4_6',
      title: '4–6 Long Exhale Breathing',
      subtitle: 'Longer exhale to slow heart rate',
      description: 'Inhale for 4 counts and release slowly for 6 counts. Excellent for anxiety relief.',
      inhaleSeconds: 4,
      holdSeconds: 2,
      exhaleSeconds: 6,
      holdAfterExhaleSeconds: 0,
      recommendedCycles: 5,
      icon: Icons.spa_rounded,
      color: AppColors.terracotta,
    ),
    BreathingTechnique(
      id: 'pursed_lip',
      title: 'Pursed-Lip Calming Breath',
      subtitle: 'Easy lung expansion and steady rhythm',
      description: 'Inhale through nose, purse lips gently, and blow air out slowly like blowing a candle.',
      inhaleSeconds: 3,
      holdSeconds: 1,
      exhaleSeconds: 5,
      holdAfterExhaleSeconds: 0,
      recommendedCycles: 4,
      icon: Icons.bubble_chart_rounded,
      color: AppColors.secondary,
    ),
  ];
}
