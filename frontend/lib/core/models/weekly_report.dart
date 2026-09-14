/// The doctor-only weekly clinical report — full evaluation metrics across
/// all 7 scored games, plus the caregiver's concern check-ins and freeform
/// notes for the same cycle. Mirrors `backend/app/schemas/weekly_report.py`.
///
/// Neither the patient nor the caregiver ever renders this model — it is
/// fetched and displayed only on the doctor's side (`WeeklyReportService`,
/// `weekly_report_card.dart`). That is the entire access-control mechanism:
/// there is no patient/caregiver-facing route that returns one.
library;

import '../../data/mock/mock_data.dart';
import 'caregiver_note.dart';
import 'game.dart';
import 'onboarding.dart';
import 'patient.dart';

/// English-only label for a caregiver-flagged concern, independent of the
/// patient's own UI language — clinician-facing text in this app (SOAP
/// notes, this report) is always plain English, same as the telehealth
/// pipeline's clinical notes.
String difficultyClinicalLabel(DailyDifficulty d) => switch (d) {
      DailyDifficulty.recentConversations => 'Recalling recent conversations',
      DailyDifficulty.repeatingQuestions => 'Repeating questions',
      DailyDifficulty.appointments => 'Keeping track of appointments',
      DailyDifficulty.misplacingThings => 'Misplacing everyday items',
      DailyDifficulty.timeOrPlace => 'Orientation to time or place',
      DailyDifficulty.gettingLost => 'Getting lost in familiar places',
      DailyDifficulty.findingWords => 'Finding the right words',
      DailyDifficulty.followingConversations => 'Following conversations',
      DailyDifficulty.decisionsProblems => 'Decisions and problem-solving',
      DailyDifficulty.familiarTasks => 'Familiar everyday tasks',
      DailyDifficulty.managingMedicines => 'Managing medicines',
      DailyDifficulty.managingMoney => 'Managing money',
      DailyDifficulty.moodOrBehaviour => 'Mood or behaviour',
      DailyDifficulty.lostInterest => 'Interest in usual activities',
      DailyDifficulty.sleepChanges => 'Sleep pattern',
      DailyDifficulty.nothingNoticed => 'No difficulty reported',
      DailyDifficulty.somethingElse => 'Other, caregiver-described',
    };

class GameDomainSummary {
  const GameDomainSummary({
    required this.gameId,
    required this.gameName,
    required this.sessionsPlayed,
    required this.avgAccuracy,
    required this.avgFocus,
    required this.avgMemory,
    required this.avgHintsUsed,
    required this.avgMistakes,
  });

  final GameId gameId;
  final String gameName;
  final int sessionsPlayed;
  final double avgAccuracy;
  final double avgFocus;
  final double avgMemory;
  final double avgHintsUsed;
  final double avgMistakes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'game_id': gameId.name,
        'game_name': gameName,
        'sessions_played': sessionsPlayed,
        'avg_accuracy': avgAccuracy,
        'avg_focus': avgFocus,
        'avg_memory': avgMemory,
        'avg_hints_used': avgHintsUsed,
        'avg_mistakes': avgMistakes,
      };

  factory GameDomainSummary.fromJson(Map<String, dynamic> json) => GameDomainSummary(
        gameId: GameId.values.firstWhere(
          (GameId g) => g.name == json['game_id'],
          orElse: () => GameId.procedure,
        ),
        gameName: json['game_name'] as String? ?? '',
        sessionsPlayed: json['sessions_played'] as int? ?? 0,
        avgAccuracy: (json['avg_accuracy'] as num?)?.toDouble() ?? 0,
        avgFocus: (json['avg_focus'] as num?)?.toDouble() ?? 0,
        avgMemory: (json['avg_memory'] as num?)?.toDouble() ?? 0,
        avgHintsUsed: (json['avg_hints_used'] as num?)?.toDouble() ?? 0,
        avgMistakes: (json['avg_mistakes'] as num?)?.toDouble() ?? 0,
      );
}

class ConcernUpdateEntry {
  const ConcernUpdateEntry({
    required this.difficulty,
    required this.difficultyLabel,
    required this.trend,
    this.comment = '',
    required this.at,
  });

  final String difficulty;
  final String difficultyLabel;
  final ConcernTrend trend;
  final String comment;
  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'difficulty': difficulty,
        'difficulty_label': difficultyLabel,
        'trend': trend.name,
        'comment': comment,
        'at': at.toIso8601String(),
      };

  factory ConcernUpdateEntry.fromJson(Map<String, dynamic> json) => ConcernUpdateEntry(
        difficulty: json['difficulty'] as String? ?? '',
        difficultyLabel: json['difficulty_label'] as String? ?? '',
        trend: ConcernTrend.values.firstWhere(
          (ConcernTrend t) => t.name == json['trend'],
          orElse: () => ConcernTrend.same,
        ),
        comment: json['comment'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class CaregiverNoteRecord {
  const CaregiverNoteRecord({required this.text, required this.at});

  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'text': text, 'at': at.toIso8601String()};

  factory CaregiverNoteRecord.fromJson(Map<String, dynamic> json) => CaregiverNoteRecord(
        text: json['text'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// The full doctor-only weekly report.
class WeeklyClinicalReport {
  const WeeklyClinicalReport({
    required this.patientId,
    this.doctorId,
    required this.patientName,
    required this.cycleStart,
    required this.generatedAt,
    required this.daysActive,
    required this.activitiesCompleted,
    this.gameSummaries = const <GameDomainSummary>[],
    this.concernUpdates = const <ConcernUpdateEntry>[],
    this.notes = const <CaregiverNoteRecord>[],
    this.onboardingBaselineNote,
  });

  final String patientId;
  final String? doctorId;
  final String patientName;
  final DateTime cycleStart;
  final DateTime generatedAt;

  /// Distinct calendar days with any activity this cycle — an adherence
  /// stat, not the cycle boundary (see [activitiesCompleted] for that).
  final int daysActive;

  /// 0–7. How many of the 7 scored activities have been played at least once
  /// this cycle. The cycle — and this report — closes once this reaches 7.
  final int activitiesCompleted;
  final List<GameDomainSummary> gameSummaries;
  final List<ConcernUpdateEntry> concernUpdates;
  final List<CaregiverNoteRecord> notes;
  final String? onboardingBaselineNote;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'patient_id': patientId,
        'doctor_id': doctorId,
        'patient_name': patientName,
        'cycle_start': cycleStart.toIso8601String(),
        'generated_at': generatedAt.toIso8601String(),
        'days_active': daysActive,
        'activities_completed': activitiesCompleted,
        'game_summaries': gameSummaries.map((GameDomainSummary g) => g.toJson()).toList(),
        'caregiver_concern_updates':
            concernUpdates.map((ConcernUpdateEntry c) => c.toJson()).toList(),
        'caregiver_notes': notes.map((CaregiverNoteRecord n) => n.toJson()).toList(),
        'onboarding_baseline_note': onboardingBaselineNote,
      };

  factory WeeklyClinicalReport.fromJson(Map<String, dynamic> json) => WeeklyClinicalReport(
        patientId: json['patient_id'] as String? ?? '',
        doctorId: json['doctor_id'] as String?,
        patientName: json['patient_name'] as String? ?? '',
        cycleStart: DateTime.tryParse(json['cycle_start'] as String? ?? '') ?? DateTime.now(),
        generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ?? DateTime.now(),
        daysActive: json['days_active'] as int? ?? 0,
        activitiesCompleted: json['activities_completed'] as int? ?? 0,
        gameSummaries: (json['game_summaries'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => GameDomainSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        concernUpdates: (json['caregiver_concern_updates'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => ConcernUpdateEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: (json['caregiver_notes'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => CaregiverNoteRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        onboardingBaselineNote: json['onboarding_baseline_note'] as String?,
      );
}

/// Builds the report from exactly the data the caregiver's device already
/// holds — the same "never disagree with the dashboard" principle
/// `ClinicalReport.build` uses (`core/models/report.dart`).
///
/// Filters every input to `[cycleStart, now)` — a real rolling 7-day window,
/// not "everything ever recorded" — using each `GameSession`'s `playedAt`
/// and each caregiver entry's own timestamp.
class WeeklyReportBuilder {
  const WeeklyReportBuilder._();

  static WeeklyClinicalReport build({
    required Patient patient,
    required String? doctorId,
    required List<GameSession> sessions,
    required List<CaregiverConcernUpdate> concernUpdates,
    required List<CaregiverNoteEntry> notes,
    required OnboardingRecord onboarding,
    required DateTime cycleStart,
    required int activitiesCompleted,
  }) {
    final List<GameSession> inCycle =
        sessions.where((GameSession s) => !s.playedAt.isBefore(cycleStart)).toList();
    final int daysActive = inCycle
        .map((GameSession s) =>
            '${s.playedAt.year}-${s.playedAt.month}-${s.playedAt.day}')
        .toSet()
        .length;
    final List<CaregiverConcernUpdate> concernsInCycle =
        concernUpdates.where((CaregiverConcernUpdate c) => !c.at.isBefore(cycleStart)).toList();
    final List<CaregiverNoteEntry> notesInCycle =
        notes.where((CaregiverNoteEntry n) => !n.at.isBefore(cycleStart)).toList();

    final List<GameDomainSummary> summaries = <GameDomainSummary>[];
    for (final GameId id in GameId.values) {
      if (GameDomains.of(id) == null) continue; // unscored (Mood Canvas)
      final List<GameSession> forGame = inCycle.where((GameSession s) => s.gameId == id).toList();
      if (forGame.isEmpty) continue;
      double avg(double Function(GamePerformance) pick) =>
          forGame.fold<double>(0, (double a, GameSession s) => a + pick(s.performance)) /
          forGame.length;
      summaries.add(GameDomainSummary(
        gameId: id,
        gameName: MockData.game(id).name,
        sessionsPlayed: forGame.length,
        avgAccuracy: avg((GamePerformance p) => p.accuracy),
        avgFocus: avg((GamePerformance p) => p.focus),
        avgMemory: avg((GamePerformance p) => p.memory),
        avgHintsUsed: avg((GamePerformance p) => p.hintsUsed.toDouble()),
        avgMistakes: avg((GamePerformance p) => p.mistakes.toDouble()),
      ));
    }

    final String? baseline = onboarding.topDifficulties.isEmpty
        ? null
        : 'At onboarding, the caregiver flagged: '
            '${onboarding.topDifficulties.map(difficultyClinicalLabel).join('; ')}.';

    return WeeklyClinicalReport(
      patientId: patient.id,
      doctorId: doctorId,
      patientName: patient.name,
      cycleStart: cycleStart,
      generatedAt: DateTime.now(),
      daysActive: daysActive,
      activitiesCompleted: activitiesCompleted,
      gameSummaries: summaries,
      concernUpdates: concernsInCycle
          .map((CaregiverConcernUpdate c) => ConcernUpdateEntry(
                difficulty: c.difficulty.name,
                difficultyLabel: difficultyClinicalLabel(c.difficulty),
                trend: c.trend,
                comment: c.comment,
                at: c.at,
              ))
          .toList(),
      notes: notesInCycle
          .map((CaregiverNoteEntry n) => CaregiverNoteRecord(text: n.text, at: n.at))
          .toList(),
      onboardingBaselineNote: baseline,
    );
  }
}
