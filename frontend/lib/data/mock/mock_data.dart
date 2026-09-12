import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/patient.dart';

/// Every piece of demo content in the prototype lives here.
///
/// Nothing is random at runtime and nothing hits a network: the whole product
/// is driven by this one file so the demo is reproducible, works offline, and
/// can later be swapped for a real repository implementation.
class MockData {
  const MockData._();

  // ── The demo patient ───────────────────────────────────────────────────

  static const List<FamilyMember> family = <FamilyMember>[
    FamilyMember(
      id: 'f_priya',
      name: 'Priya',
      relation: 'Daughter',
      sceneId: 'portrait_priya',
      note: 'Calls every evening at 7. Lives in Guwahati.',
      livesWithPatient: false,
    ),
    FamilyMember(
      id: 'f_aarav',
      name: 'Aarav',
      relation: 'Grandson',
      sceneId: 'portrait_aarav',
      note: 'Nine years old. Loves her stories about the loom.',
    ),
    FamilyMember(
      id: 'f_bhaskar',
      name: 'Bhaskar',
      relation: 'Son-in-law',
      sceneId: 'portrait_bhaskar',
      note: 'Drives her to the clinic on Thursdays.',
    ),
    FamilyMember(
      id: 'f_nirmali',
      name: 'Nirmali',
      relation: 'Neighbour & friend',
      sceneId: 'portrait_neighbour',
      note: 'They have shared morning tea for thirty years.',
      livesWithPatient: false,
    ),
  ];

  static const List<LifeMemory> memories = <LifeMemory>[
    LifeMemory(
      id: 'm_work',
      category: 'Work',
      prompt: 'What was her profession?',
      answer: 'Handloom weaver. She wove mekhela chador and gamosa for the whole village.',
    ),
    LifeMemory(
      id: 'm_activity',
      category: 'Activities',
      prompt: 'What activities did she enjoy?',
      answer: 'Weaving on the loom, tending her betel-nut trees, singing Bihu songs.',
    ),
    LifeMemory(
      id: 'm_places',
      category: 'Places',
      prompt: 'What places are important to her?',
      answer: 'Her village near Majuli, the Brahmaputra ghat, the Thursday market.',
    ),
    LifeMemory(
      id: 'm_stories',
      category: 'Stories',
      prompt: 'What stories does she remember?',
      answer:
          'Learning to weave from her mother at eleven. The year the river flooded and the whole village slept on the embankment.',
    ),
    LifeMemory(
      id: 'm_food',
      category: 'Food',
      prompt: 'What food does she love?',
      answer: 'Til pitha with black tea. She made pitha every Magh Bihu for fifty years.',
    ),
    LifeMemory(
      id: 'm_tradition',
      category: 'Traditions',
      prompt: 'What traditions are important to her?',
      answer: 'Magh Bihu, offering a gamosa in the xorai, and the first weave of the new year.',
    ),
  ];

  static const List<MemoryAsset> assets = <MemoryAsset>[
    MemoryAsset(
      id: 'a1',
      title: 'Priya',
      sceneId: 'portrait_priya',
      kind: MemoryAssetKind.person,
      caption: 'Her daughter, on the day she finished college.',
      year: '1998',
    ),
    MemoryAsset(
      id: 'a2',
      title: 'Aarav',
      sceneId: 'portrait_aarav',
      kind: MemoryAssetKind.person,
      caption: 'Her grandson at last year\'s Bihu.',
      year: '2025',
    ),
    MemoryAsset(
      id: 'a3',
      title: 'Her loom',
      sceneId: 'weaving',
      kind: MemoryAssetKind.hobby,
      caption: 'The loom in the front room, still threaded.',
    ),
    MemoryAsset(
      id: 'a4',
      title: 'The village home',
      sceneId: 'village_home',
      kind: MemoryAssetKind.place,
      caption: 'The house with the betel-nut trees.',
      year: '1976',
    ),
    MemoryAsset(
      id: 'a5',
      title: 'Magh Bihu',
      sceneId: 'bihu',
      kind: MemoryAssetKind.event,
      caption: 'Dancing in the courtyard with the neighbours.',
    ),
    MemoryAsset(
      id: 'a6',
      title: 'Til pitha',
      sceneId: 'pitha',
      kind: MemoryAssetKind.object,
      caption: 'Her pitha, rolled thin, on a banana leaf.',
    ),
    MemoryAsset(
      id: 'a7',
      title: 'The Brahmaputra',
      sceneId: 'river',
      kind: MemoryAssetKind.place,
      caption: 'The ghat where the ferry leaves for Majuli.',
    ),
    MemoryAsset(
      id: 'a8',
      title: 'Thursday market',
      sceneId: 'market',
      kind: MemoryAssetKind.place,
      caption: 'Rice, vegetables and a chat with Nirmali.',
    ),
    MemoryAsset(
      id: 'a9',
      title: 'Her gamosa',
      sceneId: 'gamosa',
      kind: MemoryAssetKind.object,
      caption: 'The first one she ever wove.',
    ),
    MemoryAsset(
      id: 'a10',
      title: 'The xorai',
      sceneId: 'xorai',
      kind: MemoryAssetKind.object,
      caption: 'Brought out for every festival.',
    ),
    MemoryAsset(
      id: 'a11',
      title: 'Tea gardens',
      sceneId: 'tea_garden',
      kind: MemoryAssetKind.place,
      caption: 'The road she walked to her sister\'s house.',
    ),
    MemoryAsset(
      id: 'a12',
      title: 'Her japi',
      sceneId: 'japi',
      kind: MemoryAssetKind.object,
      caption: 'Worn in the fields, hung by the door.',
    ),
  ];

  static const List<RoutineItem> routine = <RoutineItem>[
    RoutineItem(time: '8:00 AM', title: 'Breakfast', kind: RoutineKind.meal, detail: 'Tea and roti'),
    RoutineItem(
        time: '10:00 AM',
        title: 'Activity',
        kind: RoutineKind.activity,
        detail: 'Sitting at the loom, or the courtyard'),
    RoutineItem(time: '1:00 PM', title: 'Lunch', kind: RoutineKind.meal, detail: 'Rice, dal, fish'),
    RoutineItem(time: '4:00 PM', title: 'Rest', kind: RoutineKind.rest, detail: 'Nap and radio'),
    RoutineItem(
        time: '6:00 PM',
        title: 'Cognitive game',
        kind: RoutineKind.cognitive,
        detail: 'With Saathi'),
    RoutineItem(
        time: '7:00 PM',
        title: 'Call with Priya',
        kind: RoutineKind.social,
        detail: 'Every evening'),
    RoutineItem(
        time: '8:00 PM', title: 'Medicine', kind: RoutineKind.medicine, detail: 'Evening dose'),
  ];

  static const Patient aama = Patient(
    id: 'p_aama',
    name: 'Aama Devi',
    shortName: 'Aama',
    age: 72,
    location: 'Jorhat, Assam',
    language: 'Assamese',
    occupation: 'Weaver',
    favouriteActivity: 'Traditional weaving',
    favouriteFood: 'Pitha',
    tradition: 'Magh Bihu',
    portraitScene: 'portrait_aama',
    family: family,
    memories: memories,
    assets: assets,
    routine: routine,
    stageNote: 'Early-stage memory changes',
    joinedOn: 'On SmaranSaathi since March 2026',
  );

  static const Patient ramesh = Patient(
    id: 'p_ramesh',
    name: 'Ramesh Sharma',
    shortName: 'Ramesh',
    age: 78,
    location: 'Guwahati, Assam',
    language: 'Assamese',
    occupation: 'Teacher',
    favouriteActivity: 'Reading history books',
    favouriteFood: 'Kheer',
    tradition: 'Durga Puja',
    portraitScene: 'portrait_bhaskar',
    family: family,
    memories: memories,
    assets: assets,
    routine: routine,
    stageNote: 'Mild cognitive impairment',
    joinedOn: 'On SmaranSaathi since June 2026',
  );

  static const Patient kamla = Patient(
    id: 'p_kamla',
    name: 'Kamla Patel',
    shortName: 'Kamla',
    age: 74,
    location: 'Dibrugarh, Assam',
    language: 'Hindi',
    occupation: 'Homemaker',
    favouriteActivity: 'Gardening & Flowers',
    favouriteFood: 'Dhokla',
    tradition: 'Diwali',
    portraitScene: 'portrait_neighbour',
    family: family,
    memories: memories,
    assets: assets,
    routine: routine,
    stageNote: 'Memory care & daily assistance',
    joinedOn: 'On SmaranSaathi since January 2026',
  );

  static const List<Patient> caregiverPatients = <Patient>[
    aama,
    ramesh,
    kamla,
  ];

  /// A blank profile the caregiver fills in during onboarding.
  static const Patient emptyPatient = Patient(
    id: 'p_new',
    name: '',
    shortName: '',
    age: 72,
    location: '',
    language: 'Assamese',
    occupation: '',
    favouriteActivity: '',
    favouriteFood: '',
    tradition: '',
    portraitScene: 'portrait_aama',
    family: <FamilyMember>[],
    memories: <LifeMemory>[],
    assets: <MemoryAsset>[],
    routine: <RoutineItem>[],
  );

  static const String caregiverName = 'Priya';
  static const String doctorName = 'Dr. Neha Sharma';
  static const String clinicName = 'Jorhat Medical College — Memory Clinic';

  // ── Activities ─────────────────────────────────────────────────────────

  static const List<GameDefinition> games = <GameDefinition>[
    GameDefinition(
      id: GameId.procedure,
      name: 'Procedure Reconstruction',
      tagline: 'Remember the steps of something familiar.',
      description:
          'Put the steps of an everyday task back in the right order — making tea, cooking pitha, dressing the loom.',
      domain: CognitiveDomain.procedural,
      sceneId: 'pitha',
      accent: AppColors.terracotta,
      tint: AppColors.terracottaTint,
      estimatedMinutes: 4,
    ),
    GameDefinition(
      id: GameId.story,
      name: 'Finish the Story',
      tagline: 'What do you think happened next?',
      description:
          'Short stories from everyday life, everyday decisions, and pictures from your own memories.',
      domain: CognitiveDomain.reasoning,
      sceneId: 'festival',
      accent: AppColors.plum,
      tint: AppColors.plumTint,
      estimatedMinutes: 5,
    ),
    GameDefinition(
      id: GameId.familiarPlace,
      name: 'Familiar Place Explorer',
      tagline: 'Find the things you were asked to remember.',
      description: 'Walk through the rooms of a familiar house and find the objects you were shown.',
      domain: CognitiveDomain.spatial,
      sceneId: 'village_home',
      accent: AppColors.secondary,
      tint: AppColors.secondaryTint,
      estimatedMinutes: 6,
    ),
    GameDefinition(
      id: GameId.melody,
      name: 'Melody of the Valleys',
      tagline: 'Listen, then play the tune back.',
      description: 'Repeat short patterns played on the dhol, pepa and gogona.',
      domain: CognitiveDomain.auditory,
      sceneId: 'dhol',
      accent: AppColors.accent,
      tint: AppColors.accentTint,
      estimatedMinutes: 4,
    ),
    GameDefinition(
      id: GameId.weaves,
      name: 'Weaves of the Hills',
      tagline: 'Complete the missing part of the pattern.',
      description: 'Rebuild woven motifs drawn from gamosa, phanek and hill textiles.',
      domain: CognitiveDomain.attention,
      sceneId: 'gamosa',
      accent: AppColors.primary,
      tint: AppColors.primaryTint,
      estimatedMinutes: 5,
    ),
    GameDefinition(
      id: GameId.memoryCards,
      name: 'NER Memory Cards',
      tagline: 'Find the matching pairs.',
      description: 'A gentle matching game using images from around the North East.',
      domain: CognitiveDomain.memory,
      sceneId: 'rhino',
      accent: AppColors.indigo,
      tint: AppColors.indigoTint,
      estimatedMinutes: 4,
    ),
    GameDefinition(
      id: GameId.villageMarket,
      name: 'The Village Market Adventure',
      tagline: 'See what we can find at the market today.',
      description:
          'Wander the market stalls with a basket, and see what catches your eye — '
          'there are a few things for dinner worth remembering.',
      domain: CognitiveDomain.procedural,
      sceneId: 'market',
      accent: AppColors.olive,
      tint: AppColors.oliveTint,
      estimatedMinutes: 6,
    ),
    GameDefinition(
      id: GameId.moodCanvas,
      name: 'Mood Canvas',
      tagline: 'Draw whatever you like.',
      description:
          'A blank space to draw anything at all — no prompt, no right answer. '
          'Your doctor may look at it later.',
      domain: null,
      hasLevels: false,
      sceneId: 'orchid',
      accent: AppColors.rose,
      tint: AppColors.roseTint,
      estimatedMinutes: 5,
    ),
  ];

  static GameDefinition game(GameId id) => games.firstWhere((GameDefinition g) => g.id == id);

  /// Starting difficulty per activity, as if carried over from earlier weeks.
  static const Map<GameId, int> startingLevels = <GameId, int>{
    GameId.procedure: 2,
    GameId.story: 2,
    GameId.familiarPlace: 1,
    GameId.melody: 2,
    GameId.weaves: 3,
    GameId.memoryCards: 2,
    GameId.villageMarket: 1,
  };

  // ── Seven days of history so the charts look real ──────────────────────

  static const List<String> weekLabels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Daily cognitive engagement, oldest → newest.
  static const List<double> weeklyEngagement = <double>[64, 71, 68, 76, 73, 81, 78];

  /// Games completed per day out of four.
  static const List<double> weeklyGames = <double>[2, 3, 2, 4, 3, 4, 3];

  /// Reminder adherence per day (%).
  static const List<double> weeklyAdherence = <double>[100, 75, 100, 100, 75, 100, 100];

  /// Memory activity — journal answers remembered per day.
  static const List<double> weeklyMemoryActivity = <double>[3, 4, 3, 5, 4, 5, 4];

  static List<SeriesPoint> series(List<double> values, {List<String> labels = weekLabels}) {
    return <SeriesPoint>[
      for (int i = 0; i < values.length; i++)
        SeriesPoint(i < labels.length ? labels[i] : '', values[i]),
    ];
  }

  static List<GameSession> history() {
    return <GameSession>[
      _s(GameId.procedure, 6, 2, 74, 70, 72, 2, 3, 58, '6:10 PM'),
      _s(GameId.memoryCards, 6, 1, 80, 74, 82, 1, 2, 96, '6:32 PM'),
      _s(GameId.weaves, 5, 2, 68, 66, 70, 3, 4, 132, '5:45 PM'),
      _s(GameId.melody, 5, 1, 77, 80, 74, 1, 2, 74, '6:04 PM'),
      _s(GameId.story, 4, 2, 82, 78, 80, 1, 2, 148, '6:20 PM'),
      _s(GameId.procedure, 4, 2, 79, 76, 78, 1, 2, 51, '6:41 PM'),
      _s(GameId.familiarPlace, 3, 1, 71, 68, 74, 2, 3, 164, '5:58 PM'),
      _s(GameId.weaves, 3, 3, 86, 82, 84, 0, 1, 118, '6:22 PM'),
      _s(GameId.memoryCards, 2, 2, 84, 80, 88, 1, 2, 88, '6:15 PM'),
      _s(GameId.melody, 2, 2, 79, 83, 76, 1, 2, 82, '6:36 PM'),
      _s(GameId.procedure, 1, 2, 88, 85, 86, 1, 1, 46, '6:08 PM'),
      _s(GameId.story, 1, 2, 84, 80, 82, 0, 2, 140, '6:28 PM'),
      _s(GameId.weaves, 1, 3, 81, 79, 80, 1, 2, 124, '6:50 PM'),
      _s(GameId.villageMarket, 2, 1, 78, 72, 85, 1, 0, 96, '6:18 PM'),
      _s(GameId.villageMarket, 6, 1, 70, 65, 80, 2, 0, 112, '6:02 PM'),
    ];
  }

  static GameSession _s(GameId id, int day, int level, double acc, double focus, double mem,
      int hints, int mistakes, int secs, String time) {
    return GameSession(
      gameId: id,
      dayOffset: day,
      level: level,
      timeLabel: time,
      performance: GamePerformance(
        accuracy: acc,
        focus: focus,
        memory: mem,
        hintsUsed: hints,
        mistakes: mistakes,
        seconds: secs,
        completed: true,
      ),
    );
  }

  // ── Reminders ──────────────────────────────────────────────────────────

  static List<Reminder> reminders() => <Reminder>[
        const Reminder(
          id: 'r1',
          time: '8:00 AM',
          minutesFromMidnight: 480,
          title: 'Morning medicine',
          kind: ReminderKind.medicine,
          detail: 'One tablet after breakfast',
          done: true,
        ),
        const Reminder(
          id: 'r2',
          time: '10:30 AM',
          minutesFromMidnight: 630,
          title: 'Drink water',
          kind: ReminderKind.hydration,
          detail: 'A full glass',
          done: true,
        ),
        const Reminder(
          id: 'r3',
          time: '12:30 PM',
          minutesFromMidnight: 750,
          title: 'Drink water',
          kind: ReminderKind.hydration,
          detail: 'With lunch',
          done: true,
        ),
        const Reminder(
          id: 'r4',
          time: '4:00 PM',
          minutesFromMidnight: 960,
          title: 'Rest and radio',
          kind: ReminderKind.routine,
          detail: 'The afternoon Bihu programme',
          done: true,
        ),
        const Reminder(
          id: 'r5',
          time: '5:00 PM',
          minutesFromMidnight: 1020,
          title: 'Cognitive activity',
          kind: ReminderKind.cognitive,
          detail: 'Saathi has something ready',
        ),
        const Reminder(
          id: 'r6',
          time: '8:00 PM',
          minutesFromMidnight: 1200,
          title: 'Evening medicine',
          kind: ReminderKind.medicine,
          detail: 'Two tablets after dinner',
        ),
        const Reminder(
          id: 'r7',
          time: 'Thursday, 11:00 AM',
          minutesFromMidnight: 660,
          title: 'Memory clinic — Dr. Sharma',
          kind: ReminderKind.appointment,
          detail: 'Bhaskar will drive',
        ),
      ];

  // ── Clinician caseload ─────────────────────────────────────────────────

  static CognitiveProfile aamaProfile() => const CognitiveProfile(
        scores: <CognitiveDomain, int>{
          CognitiveDomain.memory: 82,
          CognitiveDomain.attention: 76,
          CognitiveDomain.reasoning: 71,
          CognitiveDomain.spatial: 84,
          CognitiveDomain.auditory: 79,
          CognitiveDomain.procedural: 77,
        },
        overall: 78,
        updated: 'Updated after this evening\'s session',
      );

  static List<double> _trend(int seed, double start, double slope, {double noise = 4}) {
    final math.Random r = math.Random(seed);
    return List<double>.generate(30, (int i) {
      final double v = start + slope * i + (r.nextDouble() - 0.5) * noise * 2;
      return v.clamp(28, 96);
    });
  }

  static List<ClinicPatient> caseload() => <ClinicPatient>[
        ClinicPatient(
          id: 'p_aama',
          name: 'Aama Devi',
          age: 72,
          district: 'Jorhat, Assam',
          score: 78,
          trend: TrendDirection.up,
          status: ClinicalStatus.stable,
          sceneId: 'portrait_aama',
          language: 'Assamese',
          lastSession: 'Today, 6:08 PM',
          profile: aamaProfile(),
          thirtyDay: _trend(11, 68, 0.34),
          adherence: 94,
          engagement: 78,
        ),
        ClinicPatient(
          id: 'p_kamala',
          name: 'Kamala Bora',
          age: 69,
          district: 'Sivasagar, Assam',
          score: 64,
          trend: TrendDirection.flat,
          status: ClinicalStatus.stable,
          sceneId: 'portrait_neighbour',
          language: 'Assamese',
          lastSession: 'Yesterday, 5:20 PM',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 61,
              CognitiveDomain.attention: 66,
              CognitiveDomain.reasoning: 63,
              CognitiveDomain.spatial: 70,
              CognitiveDomain.auditory: 62,
              CognitiveDomain.procedural: 64,
            },
            overall: 64,
            updated: 'Updated yesterday',
          ),
          thirtyDay: _trend(22, 64, 0.01),
          adherence: 88,
          engagement: 61,
        ),
        ClinicPatient(
          id: 'p_ramesh',
          name: 'Ramesh Deka',
          age: 77,
          district: 'Kamrup, Assam',
          score: 52,
          trend: TrendDirection.down,
          status: ClinicalStatus.needsAttention,
          sceneId: 'portrait_bhaskar',
          language: 'Assamese',
          lastSession: '3 days ago',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 47,
              CognitiveDomain.attention: 51,
              CognitiveDomain.reasoning: 49,
              CognitiveDomain.spatial: 58,
              CognitiveDomain.auditory: 55,
              CognitiveDomain.procedural: 52,
            },
            overall: 52,
            updated: 'Updated 3 days ago',
          ),
          thirtyDay: _trend(33, 63, -0.38),
          adherence: 62,
          engagement: 44,
        ),
        ClinicPatient(
          id: 'p_bimala',
          name: 'Bimala Sonowal',
          age: 74,
          district: 'Dibrugarh, Assam',
          score: 71,
          trend: TrendDirection.up,
          status: ClinicalStatus.stable,
          sceneId: 'portrait_priya',
          language: 'Assamese',
          lastSession: 'Today, 4:40 PM',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 70,
              CognitiveDomain.attention: 73,
              CognitiveDomain.reasoning: 68,
              CognitiveDomain.spatial: 75,
              CognitiveDomain.auditory: 69,
              CognitiveDomain.procedural: 71,
            },
            overall: 71,
            updated: 'Updated today',
          ),
          thirtyDay: _trend(44, 64, 0.24),
          adherence: 91,
          engagement: 72,
        ),
        ClinicPatient(
          id: 'p_thangjam',
          name: 'Thangjam Ibemhal',
          age: 70,
          district: 'Imphal East, Manipur',
          score: 68,
          trend: TrendDirection.flat,
          status: ClinicalStatus.followUp,
          sceneId: 'portrait_neighbour',
          language: 'Meiteilon',
          lastSession: '2 days ago',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 66,
              CognitiveDomain.attention: 70,
              CognitiveDomain.reasoning: 65,
              CognitiveDomain.spatial: 71,
              CognitiveDomain.auditory: 68,
              CognitiveDomain.procedural: 67,
            },
            overall: 68,
            updated: 'Updated 2 days ago',
          ),
          thirtyDay: _trend(55, 68, 0.02),
          adherence: 84,
          engagement: 66,
        ),
        ClinicPatient(
          id: 'p_wanhun',
          name: 'Wanhun Kharkongor',
          age: 75,
          district: 'East Khasi Hills, Meghalaya',
          score: 59,
          trend: TrendDirection.down,
          status: ClinicalStatus.needsAttention,
          sceneId: 'portrait_aama',
          language: 'Khasi',
          lastSession: '4 days ago',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 54,
              CognitiveDomain.attention: 58,
              CognitiveDomain.reasoning: 57,
              CognitiveDomain.spatial: 64,
              CognitiveDomain.auditory: 61,
              CognitiveDomain.procedural: 59,
            },
            overall: 59,
            updated: 'Updated 4 days ago',
          ),
          thirtyDay: _trend(66, 67, -0.26),
          adherence: 70,
          engagement: 51,
        ),
        ClinicPatient(
          id: 'p_lalrin',
          name: 'Lalrinmawia',
          age: 68,
          district: 'Aizawl, Mizoram',
          score: 81,
          trend: TrendDirection.up,
          status: ClinicalStatus.stable,
          sceneId: 'portrait_bhaskar',
          language: 'Mizo',
          lastSession: 'Today, 3:15 PM',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 80,
              CognitiveDomain.attention: 83,
              CognitiveDomain.reasoning: 78,
              CognitiveDomain.spatial: 85,
              CognitiveDomain.auditory: 80,
              CognitiveDomain.procedural: 80,
            },
            overall: 81,
            updated: 'Updated today',
          ),
          thirtyDay: _trend(77, 72, 0.28),
          adherence: 97,
          engagement: 85,
        ),
        ClinicPatient(
          id: 'p_atsu',
          name: 'Atsuho Zhimomi',
          age: 73,
          district: 'Dimapur, Nagaland',
          score: 66,
          trend: TrendDirection.flat,
          status: ClinicalStatus.followUp,
          sceneId: 'portrait_priya',
          language: 'Nagamese',
          lastSession: 'Yesterday, 6:50 PM',
          profile: const CognitiveProfile(
            scores: <CognitiveDomain, int>{
              CognitiveDomain.memory: 64,
              CognitiveDomain.attention: 67,
              CognitiveDomain.reasoning: 64,
              CognitiveDomain.spatial: 70,
              CognitiveDomain.auditory: 66,
              CognitiveDomain.procedural: 65,
            },
            overall: 66,
            updated: 'Updated yesterday',
          ),
          thirtyDay: _trend(88, 66, 0.0),
          adherence: 86,
          engagement: 64,
        ),
      ];

  static const int caseloadTotal = 24;
  static const int caseloadStable = 18;
  static const int caseloadAttention = 4;
  static const int caseloadFollowUp = 2;

  static List<DoctorAlert> alerts() => <DoctorAlert>[
        const DoctorAlert(
          id: 'al1',
          patientName: 'Ramesh Deka',
          title: 'Activity performance decreased over the last 7 days',
          detail:
              'Average session score fell from 61 to 52. Attention and memory activities show the largest change. Consider further clinical assessment.',
          severity: AlertSeverity.urgent,
          age: '2 days ago',
          domain: CognitiveDomain.memory,
        ),
        const DoctorAlert(
          id: 'al2',
          patientName: 'Wanhun Kharkongor',
          title: 'Reduced engagement — 3 sessions missed',
          detail:
              'No completed activity since Tuesday. Reminder adherence dropped to 70%. Caregiver contact suggested.',
          severity: AlertSeverity.watch,
          age: '1 day ago',
        ),
        const DoctorAlert(
          id: 'al3',
          patientName: 'Kamala Bora',
          title: 'Reasoning activity plateau across 14 days',
          detail:
              'Performance is stable but has not responded to two difficulty increases. Content variety may need review.',
          severity: AlertSeverity.watch,
          age: '4 days ago',
          domain: CognitiveDomain.reasoning,
        ),
        const DoctorAlert(
          id: 'al4',
          patientName: 'Aama Devi',
          title: 'Sustained improvement in procedural activities',
          detail:
              'Accuracy rose from 74% to 88% across six sessions. Adaptive difficulty increased twice this week.',
          severity: AlertSeverity.info,
          age: 'Today',
          domain: CognitiveDomain.procedural,
        ),
        const DoctorAlert(
          id: 'al5',
          patientName: 'Atsuho Zhimomi',
          title: 'Follow-up due this week',
          detail: 'Scheduled six-week review. Last in-person visit was 12 May 2026.',
          severity: AlertSeverity.info,
          age: 'Today',
        ),
      ];

  // ── Daily conversation ─────────────────────────────────────────────────

  static List<DailyQuestion> dailyQuestions(Patient p) {
    final String daughter = p.family
        .firstWhere((FamilyMember f) => f.relation.toLowerCase().contains('daughter'),
            orElse: () => p.family.isEmpty
                ? const FamilyMember(
                    id: 'x', name: 'your family', relation: '', sceneId: 'portrait_priya')
                : p.family.first)
        .name;
    final String grandchild = p.family
        .firstWhere((FamilyMember f) => f.relation.toLowerCase().contains('grand'),
            orElse: () => p.family.isEmpty
                ? const FamilyMember(
                    id: 'x', name: 'your grandchild', relation: '', sceneId: 'portrait_aarav')
                : p.family.last)
        .name;

    return <DailyQuestion>[
      DailyQuestion(
        id: 'q_sleep',
        text: 'Good morning, ${p.shortName}. Did you sleep well?',
        journalLabel: 'Morning check-in',
        options: const <QuestionOption>[
          QuestionOption(label: 'Yes, well', emoji: '😊', response: 'Wonderful. A good night helps everything.'),
          QuestionOption(label: 'A little', emoji: '😐', response: 'That happens. We will take today gently.'),
          QuestionOption(
              label: 'Not really',
              emoji: '😔',
              positive: false,
              response: 'I am sorry. Let us do something calm and familiar today.'),
        ],
      ),
      DailyQuestion(
        id: 'q_breakfast',
        text: 'Do you remember what you had for breakfast?',
        subtitle: 'Take your time. There is no hurry.',
        journalLabel: 'Breakfast remembered',
        options: const <QuestionOption>[
          QuestionOption(label: 'Yes, I remember', emoji: '🍵', response: 'Lovely. Tea and roti, just as always.'),
          QuestionOption(
              label: 'Not sure',
              emoji: '🤔',
              positive: false,
              response: 'That is alright. It was tea and roti this morning.'),
        ],
      ),
      DailyQuestion(
        id: 'q_daughter',
        text: 'Did you speak with $daughter today?',
        sceneId: p.family.isEmpty ? null : p.family.first.sceneId,
        journalLabel: 'Recognised $daughter',
        options: <QuestionOption>[
          QuestionOption(
              label: 'Yes, we spoke',
              emoji: '📞',
              response: '$daughter always calls in the evening. That is a good habit.'),
          const QuestionOption(
              label: 'Not yet',
              emoji: '🕐',
              response: 'She will call at seven, as she always does.'),
        ],
      ),
      DailyQuestion(
        id: 'q_weave',
        text: 'Do you remember the weaving pattern you used to make?',
        subtitle: 'The one with the red diamonds along the border.',
        journalLabel: 'Recalled her weaving',
        options: const <QuestionOption>[
          QuestionOption(
              label: 'Yes, I remember',
              emoji: '🧵',
              response: 'The red diamonds on white. Everyone in the village knew your border.'),
          QuestionOption(
              label: 'Show me',
              emoji: '👀',
              positive: false,
              response: 'Here it is — the gamosa border you wove for fifty years.'),
        ],
      ),
      DailyQuestion(
        id: 'q_grandchild',
        text: 'Would you like to hear about $grandchild today?',
        sceneId: p.family.length > 1 ? p.family[1].sceneId : null,
        journalLabel: 'Talked about $grandchild',
        options: <QuestionOption>[
          QuestionOption(
              label: 'Yes, please',
              emoji: '❤️',
              response: '$grandchild is nine now. He asked about your loom again yesterday.'),
          const QuestionOption(
              label: 'Later', emoji: '🌤️', positive: false, response: 'Of course. Whenever you like.'),
        ],
      ),
    ];
  }

  static const List<JourneyStep> journey = <JourneyStep>[
    JourneyStep(id: 'checkin', label: 'Morning check-in', icon: Icons.wb_sunny_rounded),
    JourneyStep(id: 'memory', label: 'Memory activity', icon: Icons.favorite_rounded),
    JourneyStep(id: 'game', label: 'Cognitive game', icon: Icons.extension_rounded),
    JourneyStep(id: 'reflection', label: 'Evening reflection', icon: Icons.nightlight_round),
  ];
}
