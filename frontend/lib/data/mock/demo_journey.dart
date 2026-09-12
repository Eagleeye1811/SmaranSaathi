import 'dart:math' as math;

import '../../core/models/assessment.dart';
import '../../core/models/onboarding.dart';
import '../../core/models/game.dart';
import '../../core/models/monitoring.dart';

/// A complete, pre-populated monitoring history.
///
/// Longitudinal monitoring is the point of the product and it cannot be shown
/// live: three months of weekly assessments take three months. This builds a
/// consistent twelve-week history for one fictional person so the trend, the
/// baseline comparison, the patterns and the report can all be demonstrated
/// from real code paths rather than from screenshots — every figure on screen
/// is computed by the same services that process a real session.
///
/// It is loaded only on demand (Profile → "Load demonstration history", or
/// `--dart-define=MM_DEMO=true`) and never on a normal first run.
class DemoJourney {
  const DemoJourney._();

  /// Twelve weekly assessments, oldest 84 days ago.
  static const int weeks = 12;

  /// Domains that drift downward over the period, and those that hold. The
  /// pattern is deliberately partial — a uniform decline across everything
  /// looks synthetic and is not what early change usually looks like.
  ///
  /// The declining rates are set so the change clears [DomainReading]'s
  /// five-point noise floor with margin — a demo whose headline depends on
  /// which side of the threshold the random noise landed is a demo that fails
  /// on stage.
  static const Map<CognitiveDomain, double> _weeklyDrift = <CognitiveDomain, double>{
    CognitiveDomain.memory: -0.95,
    CognitiveDomain.procedural: -1.05,
    CognitiveDomain.attention: -0.14,
    CognitiveDomain.reasoning: -0.05,
    CognitiveDomain.spatial: -0.12,
    CognitiveDomain.auditory: 0.02,
  };

  static const Map<CognitiveDomain, double> _startingScore = <CognitiveDomain, double>{
    CognitiveDomain.memory: 83,
    CognitiveDomain.procedural: 79,
    CognitiveDomain.attention: 88,
    CognitiveDomain.reasoning: 87,
    CognitiveDomain.spatial: 82,
    CognitiveDomain.auditory: 80,
  };

  /// Seeded so every run of the demo produces identical numbers — a figure
  /// that changes between rehearsal and presentation is a figure you cannot
  /// talk about.
  static List<GameSession> sessions() {
    final math.Random random = math.Random(20260828);
    final List<GameSession> out = <GameSession>[];

    for (int week = weeks - 1; week >= 0; week--) {
      final int dayOffset = week * 7 + (week.isEven ? 1 : 0);
      for (final GameId id in GameId.values) {
        final CognitiveDomain domain = GameDomains.of(id);
        final double start = _startingScore[domain] ?? 80;
        final double drift = (_weeklyDrift[domain] ?? 0) * (weeks - 1 - week);
        // Session-to-session noise: real performance is never a clean line.
        // Kept under the five-point trend floor so a domain authored as stable
        // cannot drift across it by chance.
        final double noise = (random.nextDouble() - 0.5) * 4;
        final double score = (start + drift + noise).clamp(35, 99);

        final int level = 1 + ((weeks - 1 - week) ~/ 4).clamp(0, 2);
        final int expected = 150 + level * 30;
        final int seconds = (expected * (1 + (85 - score) / 160)).round();
        final int attempts = 8 + level * 2;
        final int correct = ((score / 100) * attempts).round().clamp(0, attempts);
        final int mistakes = attempts - correct;

        out.add(GameSession(
          gameId: id,
          dayOffset: dayOffset,
          level: level,
          timeLabel: week.isEven ? '10:20 AM' : '4:45 PM',
          performance: GamePerformance(
            accuracy: score,
            focus: (score - 2 + random.nextDouble() * 6).clamp(35, 99),
            memory: (score - 4 + random.nextDouble() * 8).clamp(35, 99),
            hintsUsed: score < 70 ? 2 : (score < 80 ? 1 : 0),
            mistakes: mistakes,
            seconds: seconds,
            completed: true,
            attempts: attempts,
            correct: correct,
            responseMillis: ((seconds / attempts) * 1000).round(),
          ),
        ));
      }
    }

    // Newest first, matching how `AppState` holds its history.
    out.sort((GameSession a, GameSession b) => a.dayOffset.compareTo(b.dayOffset));
    return out;
  }

  /// The onboarding that goes with the history: memory concerns noticed six
  /// to twelve months ago, a gradual course, early instrumental difficulty,
  /// vascular risk present, answered by a daughter.
  ///
  /// Seeded as an [OnboardingRecord] and passed through
  /// [IntakeRecord.withOnboarding] rather than as hand-written symptom and
  /// function maps: the demo then shows exactly what a real answer set
  /// projects into, so a projection that drifted would be visible in the demo
  /// rather than only in a report nobody looks at.
  static OnboardingRecord onboarding() {
    return const OnboardingRecord(
      helper: HelperRole.child,
      education: EducationLevel.secondary,
      // No diagnosis yet — the daughter is monitoring, which is the situation
      // most of these users are actually in.
      diagnosisStatus: DiagnosisStatus.notSure,
      professionals: <CareProfessional>{
        CareProfessional.physician,
        CareProfessional.familyCaregiver,
      },
      treatmentStatus: TreatmentStatus.yes,
      medicines: <String>['Amlodipine 5 mg', 'Metformin 500 mg'],
      sedatingMedicines: <SedatingMedicineClass>{SedatingMedicineClass.noneOfThese},
      healthConditions: <MedicalCondition>{
        MedicalCondition.hypertension,
        MedicalCondition.diabetes,
      },
      difficulties: <DailyDifficulty>{
        DailyDifficulty.recentConversations,
        DailyDifficulty.repeatingQuestions,
        DailyDifficulty.appointments,
        DailyDifficulty.misplacingThings,
        DailyDifficulty.managingMoney,
        DailyDifficulty.managingMedicines,
        DailyDifficulty.lostInterest,
      },
      topDifficulties: <DailyDifficulty>[
        DailyDifficulty.recentConversations,
        DailyDifficulty.appointments,
        DailyDifficulty.managingMoney,
      ],
      onset: OnsetWindow.sixToTwelveMonths,
      course: ProgressionPattern.graduallyWorse,
      recentExample:
          'Last Thursday she asked me three times whether the electricity bill '
          'had been paid, within about an hour. She had paid it herself that '
          'morning and had the receipt in her bag.',
      probeAnswers: <String, Set<String>>{
        'probe_memory_span': <String>{'laterSameDay'},
        'probe_memory_awareness': <String>{'partlyAware'},
      },
      support: <DailyActivity, SupportLevel>{
        DailyActivity.eating: SupportLevel.independent,
        DailyActivity.dressing: SupportLevel.independent,
        DailyActivity.bathing: SupportLevel.independent,
        DailyActivity.toilet: SupportLevel.independent,
        DailyActivity.medicines: SupportLevel.needsReminders,
        DailyActivity.household: SupportLevel.independent,
        DailyActivity.money: SupportLevel.needsSomeHelp,
        DailyActivity.goingOut: SupportLevel.independent,
      },
      behaviourChanges: <BehaviourChange>{BehaviourChange.lessInterested},
      safetyConcerns: <SafetyConcern>{
        SafetyConcern.forgettingMedicines,
        SafetyConcern.handlingMoney,
      },
      enjoys: <EnjoyedActivity>{
        EnjoyedActivity.music,
        EnjoyedActivity.talkingWithFamily,
        EnjoyedActivity.gardening,
        EnjoyedActivity.religious,
      },
      stillDoesWell:
          'She still makes the morning tea, waters the tulsi and talks to her '
          'grandchildren every evening.',
      goals: <SupportGoal>[
        SupportGoal.rememberingThings,
        SupportGoal.dailyRoutines,
        SupportGoal.sharingWithDoctor,
      ],
    );
  }

  static IntakeRecord intake({required DateTime now}) {
    final DateTime start = now.subtract(const Duration(days: weeks * 7));
    final IntakeRecord seeded = IntakeRecord(
      consent: ConsentRecord(understood: true, atIso: start.toIso8601String()),
      baselineActivities: <String>{for (final GameId g in GameId.values) g.name},
      startedAtIso: start.toIso8601String(),
      completedAtIso: start.add(const Duration(minutes: 22)).toIso8601String(),
    ).withOnboarding(onboarding(), caregiverName: 'Priya');

    return seeded.copyWith(
      // Sleep duration is not one of the fifteen questions, so the projection
      // leaves it at the model default. The demo sets it by hand because the
      // report's "factors that can affect performance" line is one of the
      // things the demo exists to show.
      medical: seeded.medical.copyWith(sleepHours: 6.5),
      caregiver: seeded.caregiver == null
          ? null
          : CaregiverObservation(
              caregiverName: seeded.caregiver!.caregiverName,
              relation: 'Daughter',
              observations: seeded.caregiver!.observations,
              note: seeded.caregiver!.note,
              receivedAtIso: now.subtract(const Duration(days: 3)).toIso8601String(),
            ),
    );
  }
}
