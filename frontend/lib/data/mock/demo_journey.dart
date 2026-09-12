import 'dart:math' as math;

import '../../core/models/assessment.dart';
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
        // Mood Canvas has no domain and no score to fabricate — it never
        // gets a GameSession, synthetic history included.
        final CognitiveDomain? domain = GameDomains.of(id);
        if (domain == null) continue;
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

  /// The intake that goes with the history: memory concerns noticed six to
  /// twelve months ago, gradual course, early instrumental difficulty,
  /// vascular risk present, corroborated by a daughter.
  static IntakeRecord intake({required DateTime now}) {
    final DateTime start = now.subtract(const Duration(days: weeks * 7));
    return IntakeRecord(
      consent: ConsentRecord(understood: true, atIso: start.toIso8601String()),
      completedBy: CompletedBy.caregiver,
      reason: const ReasonForVisit(
        concerns: <PresentingConcern>{
          PresentingConcern.memoryProblems,
          PresentingConcern.appointments,
          PresentingConcern.familyNoticed,
        },
        onset: OnsetWindow.sixToTwelveMonths,
        progression: ProgressionPattern.graduallyWorse,
      ),
      safety: const SafetyCheck(
        suddenOnset: false,
        fluctuatingAlertness: false,
        neurologicalRedFlag: false,
      ),
      symptoms: const SymptomAssessment(responses: <String, SymptomFrequency>{
        'mem_repeat': SymptomFrequency.often,
        'mem_conv': SymptomFrequency.often,
        'mem_appt': SymptomFrequency.often,
        'mem_misplace': SymptomFrequency.sometimes,
        'mem_new': SymptomFrequency.often,
        'att_concentrate': SymptomFrequency.sometimes,
        'att_follow': SymptomFrequency.sometimes,
        'att_plan': SymptomFrequency.often,
        'att_money': SymptomFrequency.often,
        'att_solve': SymptomFrequency.sometimes,
        'lang_words': SymptomFrequency.sometimes,
        'lang_naming': SymptomFrequency.never,
        'lang_understand': SymptomFrequency.never,
        'beh_interest': SymptomFrequency.sometimes,
        'beh_impulsive': SymptomFrequency.never,
        'beh_social': SymptomFrequency.never,
        'beh_eating': SymptomFrequency.never,
        'mov_tremor': SymptomFrequency.never,
        'mov_stiff': SymptomFrequency.never,
        'mov_balance': SymptomFrequency.sometimes,
        'mov_halluc': SymptomFrequency.never,
        'mov_alert': SymptomFrequency.never,
        'mov_dreams': SymptomFrequency.never,
      }),
      function: const FunctionalAssessment(levels: <String, FunctionLevel>{
        'fn_money': FunctionLevel.needsHelp,
        'fn_meds': FunctionLevel.needsHelp,
        'fn_cooking': FunctionLevel.independent,
        'fn_shopping': FunctionLevel.independent,
        'fn_phone': FunctionLevel.independent,
        'fn_transport': FunctionLevel.independent,
        'fn_appointments': FunctionLevel.needsHelp,
        'fn_bathing': FunctionLevel.independent,
      }),
      medical: const MedicalHistory(
        conditions: <MedicalCondition>{
          MedicalCondition.hypertension,
          MedicalCondition.diabetes,
        },
        sleepHours: 6.5,
        sleepQuality: SleepQuality.fair,
        lowMood: MoodFrequency.sometimes,
        medications: <String>['Amlodipine 5 mg', 'Metformin 500 mg'],
      ),
      caregiver: CaregiverObservation(
        caregiverName: 'Priya',
        relation: 'Daughter',
        observations: const <String, bool>{
          'cg_repeat': true,
          'cg_appointments': true,
          'cg_bills': true,
          'cg_words': false,
          'cg_lost': false,
          'cg_personality': false,
          'cg_halluc': false,
          'cg_withdrawn': true,
        },
        note: 'Manages at home, but I now check the bills and the tablets each week.',
        receivedAtIso: now.subtract(const Duration(days: 3)).toIso8601String(),
      ),
      baselineActivities: <String>{for (final GameId g in GameId.values) g.name},
      startedAtIso: start.toIso8601String(),
      completedAtIso: start.add(const Duration(minutes: 22)).toIso8601String(),
    );
  }
}
