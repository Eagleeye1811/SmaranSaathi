import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:smaran_saathi/core/ai/health_assistant.dart';
import 'package:smaran_saathi/core/models/assessment.dart';
import 'package:smaran_saathi/core/models/clinical.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/models/monitoring.dart';
import 'package:smaran_saathi/core/models/report.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/services/cognitive_monitoring_service.dart';
import 'package:smaran_saathi/data/local/hive_store.dart';
import 'package:smaran_saathi/data/mock/demo_journey.dart';
import 'package:smaran_saathi/data/repositories/hive_repositories.dart';

/// The intake, the longitudinal maths, the report and the assistant's safety
/// rule — the four things that decide whether this is a monitoring product or
/// a set of games with a chart on top.

const CognitiveMonitoringService monitor = CognitiveMonitoringService();

GameSession session(GameId id, {required int dayOffset, required double score}) {
  return GameSession(
    gameId: id,
    dayOffset: dayOffset,
    level: 2,
    timeLabel: '10:00 AM',
    performance: GamePerformance(
      // `overall` is 50% accuracy + 25% focus + 25% memory, so equal values
      // make the composite exactly `score`.
      accuracy: score,
      focus: score,
      memory: score,
      hintsUsed: 0,
      mistakes: 1,
      seconds: 120,
      completed: true,
      attempts: 10,
      correct: 8,
      responseMillis: 12000,
    ),
  );
}

void main() {
  accountTests();

  TestWidgetsFlutterBinding.ensureInitialized();

  group('symptom assessment', () {
    test('severity is the mean of the answered items, scaled to 0–100', () {
      // Memory has five items. "Very often" is 3 of 3, "never" is 0.
      const SymptomAssessment all3 = SymptomAssessment(responses: <String, SymptomFrequency>{
        'mem_repeat': SymptomFrequency.veryOften,
        'mem_conv': SymptomFrequency.veryOften,
        'mem_appt': SymptomFrequency.veryOften,
        'mem_misplace': SymptomFrequency.veryOften,
        'mem_new': SymptomFrequency.veryOften,
      });
      expect(all3.severity(SymptomDomain.memory), 100);

      const SymptomAssessment none = SymptomAssessment(responses: <String, SymptomFrequency>{
        'mem_repeat': SymptomFrequency.never,
      });
      expect(none.severity(SymptomDomain.memory), 0);
      // An unanswered group scores zero rather than throwing.
      expect(none.severity(SymptomDomain.language), 0);
    });

    test('only items at "often" or above count as prominent', () {
      const SymptomAssessment a = SymptomAssessment(responses: <String, SymptomFrequency>{
        'mem_repeat': SymptomFrequency.often,
        'mem_conv': SymptomFrequency.sometimes,
        'lang_words': SymptomFrequency.veryOften,
      });
      expect(a.prominent.map((SymptomItem i) => i.id),
          containsAll(<String>['mem_repeat', 'lang_words']));
      expect(a.prominent.map((SymptomItem i) => i.id), isNot(contains('mem_conv')));
    });
  });

  group('functional assessment', () {
    test('independence falls as help is needed', () {
      const FunctionalAssessment independent = FunctionalAssessment(
        levels: <String, FunctionLevel>{'fn_money': FunctionLevel.independent},
      );
      expect(independent.independencePercent, 100);

      const FunctionalAssessment dependent = FunctionalAssessment(
        levels: <String, FunctionLevel>{'fn_money': FunctionLevel.dependent},
      );
      expect(dependent.independencePercent, 0);
    });

    test('instrumental impairment is banded by how many activities are affected', () {
      FunctionalAssessment withHelp(int count) => FunctionalAssessment(
            levels: <String, FunctionLevel>{
              for (final FunctionalItem i
                  in FunctionCatalogue.items.where((FunctionalItem i) => i.instrumental).take(count))
                i.id: FunctionLevel.needsHelp,
            },
          );

      expect(withHelp(0).iadlImpairment, ImpairmentBand.none);
      expect(withHelp(2).iadlImpairment, ImpairmentBand.mild);
      expect(withHelp(4).iadlImpairment, ImpairmentBand.moderate);
      expect(withHelp(6).iadlImpairment, ImpairmentBand.severe);
    });

    test('bathing is not counted as an instrumental activity', () {
      const FunctionalAssessment onlyBathing = FunctionalAssessment(
        levels: <String, FunctionLevel>{'fn_bathing': FunctionLevel.needsHelp},
      );
      expect(onlyBathing.iadlImpairment, ImpairmentBand.none);
      expect(onlyBathing.needingHelp, hasLength(1));
    });
  });

  group('intake record', () {
    test('resumes at the first unanswered step', () {
      const IntakeRecord empty = IntakeRecord.empty;
      expect(empty.nextStep, IntakeStep.consent);

      final IntakeRecord consented = empty.copyWith(
        consent: const ConsentRecord(understood: true, atIso: '2026-08-01'),
      );
      expect(consented.nextStep, IntakeStep.person);

      final IntakeRecord withPerson = consented.withOnboarding(
        const OnboardingRecord(
          helper: HelperRole.myself,
          education: EducationLevel.secondary,
        ),
      );
      expect(withPerson.nextStep, IntakeStep.health);

      final IntakeRecord withHealth = withPerson.withOnboarding(
        withPerson.onboarding.copyWith(
          diagnosisStatus: DiagnosisStatus.no,
          treatmentStatus: TreatmentStatus.no,
        ),
      );
      expect(withHealth.nextStep, IntakeStep.everyday);
    });

    test('the follow-up screen is skipped when nothing triggered it', () {
      const IntakeRecord base = IntakeRecord.empty;

      // "Nothing noticed" is a complete answer to the everyday screen and
      // ranks nothing, so there is no follow-up to ask.
      final IntakeRecord quiet = base
          .copyWith(consent: const ConsentRecord(understood: true, atIso: 'x'))
          .withOnboarding(const OnboardingRecord(
            helper: HelperRole.myself,
            education: EducationLevel.graduate,
            diagnosisStatus: DiagnosisStatus.no,
            treatmentStatus: TreatmentStatus.no,
            difficulties: <DailyDifficulty>{DailyDifficulty.nothingNoticed},
            onset: OnsetWindow.unsure,
            course: ProgressionPattern.noChange,
          ));
      expect(quiet.onboarding.activeProbes, isEmpty);
      expect(quiet.nextStep, IntakeStep.independence);

      // A difficulty the catalogue has follow-ups for stops there instead.
      final IntakeRecord probed = quiet.withOnboarding(
        quiet.onboarding.copyWith(
          difficulties: <DailyDifficulty>{DailyDifficulty.misplacingThings},
          topDifficulties: <DailyDifficulty>[DailyDifficulty.misplacingThings],
        ),
      );
      expect(probed.onboarding.activeProbes, hasLength(3));
      expect(probed.nextStep, IntakeStep.probes);
    });

    test('answers project onto the structures the report reads', () {
      final IntakeRecord record = IntakeRecord.empty.withOnboarding(
        const OnboardingRecord(
          helper: HelperRole.child,
          difficulties: <DailyDifficulty>{
            DailyDifficulty.recentConversations,
            DailyDifficulty.managingMoney,
          },
          topDifficulties: <DailyDifficulty>[DailyDifficulty.recentConversations],
          support: <DailyActivity, SupportLevel>{
            DailyActivity.money: SupportLevel.needsFullHelp,
            DailyActivity.bathing: SupportLevel.independent,
            // Three activities collapse onto one legacy item, and the most
            // help needed has to win — otherwise combining answers could make
            // the picture look better than any single answer did.
            DailyActivity.dressing: SupportLevel.needsSomeHelp,
            DailyActivity.toilet: SupportLevel.independent,
          },
        ),
      );

      // The one named as biggest is reported more often than the other.
      expect(record.symptoms.responses['mem_conv'], SymptomFrequency.veryOften);
      expect(record.symptoms.responses['att_money'], SymptomFrequency.often);
      // Offered and not chosen is "never", not missing — an unanswered item
      // and a denied one are different things.
      expect(record.symptoms.responses['mem_repeat'], SymptomFrequency.never);

      expect(record.function.levels['fn_money'], FunctionLevel.dependent);
      expect(record.function.levels['fn_bathing'], FunctionLevel.needsHelp);

      // A daughter answering means the report has corroboration to separate
      // from self-report; the person answering for themselves means it does
      // not, and must not pretend otherwise.
      expect(record.caregiver, isNotNull);
      expect(record.completedBy, CompletedBy.familyMember);

      final IntakeRecord selfAnswered =
          record.withOnboarding(record.onboarding.copyWith(helper: HelperRole.myself));
      expect(selfAnswered.caregiver, isNull);
      expect(selfAnswered.completedBy, CompletedBy.patient);
    });

    test('a follow-up that pins down a frequency beats the estimate', () {
      const OnboardingRecord answers = OnboardingRecord(
        difficulties: <DailyDifficulty>{DailyDifficulty.misplacingThings},
        topDifficulties: <DailyDifficulty>[DailyDifficulty.misplacingThings],
        probeAnswers: <String, Set<String>>{
          'probe_misplace_often': <String>{'occasionally'},
        },
      );

      // Being named the biggest difficulty would read as "very often"; the
      // caregiver actually said it happens occasionally, and that wins.
      expect(answers.toSymptomAssessment().responses['mem_misplace'],
          SymptomFrequency.sometimes);
    });

    test('survives a JSON round trip', () {
      final IntakeRecord original = DemoJourney.intake(now: DateTime(2026, 8, 28));
      final IntakeRecord restored = IntakeRecord.fromJson(original.toJson());

      expect(restored.consentGiven, isTrue);
      expect(restored.completedBy, original.completedBy);
      expect(restored.reason.concerns, original.reason.concerns);
      expect(restored.reason.onset, original.reason.onset);
      expect(restored.symptoms.responses.length, original.symptoms.responses.length);
      expect(restored.symptoms.severity(SymptomDomain.memory),
          original.symptoms.severity(SymptomDomain.memory));
      expect(restored.function.independencePercent, original.function.independencePercent);
      expect(restored.medical.conditions, original.medical.conditions);
      expect(restored.caregiver!.present, original.caregiver!.present);
      expect(restored.baselineActivities, original.baselineActivities);
      expect(restored.isComplete, isTrue);
    });
  });

  group('longitudinal monitoring', () {
    test('the baseline is taken from the earliest sessions, not the latest', () {
      final List<GameSession> sessions = <GameSession>[
        session(GameId.memoryCards, dayOffset: 84, score: 80),
        session(GameId.memoryCards, dayOffset: 77, score: 80),
        session(GameId.memoryCards, dayOffset: 7, score: 60),
        session(GameId.memoryCards, dayOffset: 0, score: 60),
      ];

      final CognitiveBaseline baseline =
          monitor.buildBaseline(sessions, at: DateTime(2026, 6, 1));
      expect(baseline.scoreFor(CognitiveDomain.memory), 80);
    });

    test('a change smaller than the noise floor is not reported as a trend', () {
      final List<GameSession> sessions = <GameSession>[
        session(GameId.memoryCards, dayOffset: 84, score: 80),
        session(GameId.memoryCards, dayOffset: 0, score: 77),
      ];
      final CognitiveBaseline baseline =
          monitor.buildBaseline(sessions, at: DateTime(2026, 6, 1), perDomain: 1);

      final MonitoringSnapshot snapshot = monitor.snapshot(
        sessions: sessions,
        baseline: baseline,
        intake: IntakeRecord.empty,
      );
      final DomainReading memory = snapshot.reading(CognitiveDomain.memory)!;

      // 80 → 78.5 mean is a 1.5-point move: inside normal variation.
      expect(memory.trend, TrendDirection.flat);
      expect(memory.deltaLabel, 'Within normal variation');
      expect(snapshot.declining, isEmpty);
    });

    test('a sustained drop below baseline is reported as declining', () {
      final List<GameSession> sessions = <GameSession>[
        session(GameId.memoryCards, dayOffset: 84, score: 85),
        session(GameId.memoryCards, dayOffset: 77, score: 85),
        session(GameId.memoryCards, dayOffset: 7, score: 62),
        session(GameId.memoryCards, dayOffset: 0, score: 60),
      ];
      final CognitiveBaseline baseline =
          monitor.buildBaseline(sessions, at: DateTime(2026, 6, 1));

      final MonitoringSnapshot snapshot = monitor.snapshot(
        sessions: sessions,
        baseline: baseline,
        intake: IntakeRecord.empty,
      );
      expect(snapshot.reading(CognitiveDomain.memory)!.trend, TrendDirection.down);
      expect(snapshot.declining, hasLength(1));
      expect(snapshot.headline, contains('memory'));
    });

    test('a domain never played reads as "not yet assessed", never as zero', () {
      final MonitoringSnapshot snapshot = monitor.snapshot(
        sessions: <GameSession>[session(GameId.memoryCards, dayOffset: 0, score: 80)],
        baseline: null,
        intake: IntakeRecord.empty,
      );
      final DomainReading spatial = snapshot.reading(CognitiveDomain.spatial)!;
      expect(spatial.hasReading, isFalse);
      expect(spatial.current, isNull);
      expect(snapshot.overallCurrent, 80);
    });

    test('weeks with no sessions are skipped rather than plotted as zero', () {
      final List<GameSession> sessions = <GameSession>[
        session(GameId.memoryCards, dayOffset: 21, score: 80),
        session(GameId.memoryCards, dayOffset: 0, score: 70),
      ];
      final List<SeriesPoint> series = monitor.weeklySeries(sessions);

      expect(series, hasLength(2));
      expect(series.first.value, 80);
      expect(series.last.label, 'Now');
      expect(series.every((SeriesPoint p) => p.value > 0), isTrue);
    });

    test('vascular risk is reported from conditions, never inferred from scores', () {
      const IntakeRecord noRisk = IntakeRecord.empty;
      final List<ObservedPattern> without = monitor.patterns(
        intake: noRisk,
        snapshot: MonitoringSnapshot.empty,
      );
      expect(
        without.firstWhere((ObservedPattern p) => p.id == 'vascular').level,
        PatternLevel.notPresent,
      );

      const IntakeRecord withRisk = IntakeRecord(
        medical: MedicalHistory(conditions: <MedicalCondition>{
          MedicalCondition.hypertension,
          MedicalCondition.diabetes,
          MedicalCondition.strokeOrTia,
        }),
      );
      final List<ObservedPattern> with3 = monitor.patterns(
        intake: withRisk,
        snapshot: MonitoringSnapshot.empty,
      );
      expect(
        with3.firstWhere((ObservedPattern p) => p.id == 'vascular').level,
        PatternLevel.high,
      );
    });

    test('a clinical discussion is suggested only on more than one signal', () {
      MonitoringSnapshot snapshotWith({
        required List<DomainReading> readings,
        int independence = 100,
      }) {
        return MonitoringSnapshot(
          readings: readings,
          baseline: const CognitiveBaseline(
              scores: <CognitiveDomain, double>{CognitiveDomain.memory: 80},
              capturedAtIso: '',
              sessionCount: 2),
          patterns: const <ObservedPattern>[],
          assessmentsCompleted: 4,
          assessmentsExpected: 4,
          consistency: 90,
          functionalIndependence: independence,
          lastAssessmentDaysAgo: 0,
          totalSessions: 12,
        );
      }

      const DomainReading down = DomainReading(
        domain: CognitiveDomain.memory,
        current: 60,
        baseline: 80,
        sessionCount: 4,
        history: <double>[],
      );
      const DomainReading steady = DomainReading(
        domain: CognitiveDomain.attention,
        current: 80,
        baseline: 80,
        sessionCount: 4,
        history: <double>[],
      );

      // One declining domain and full independence is not enough.
      expect(
        snapshotWith(readings: <DomainReading>[down, steady]).suggestsClinicalDiscussion,
        isFalse,
      );
      // One declining domain plus reported functional difficulty is.
      expect(
        snapshotWith(readings: <DomainReading>[down, steady], independence: 75)
            .suggestsClinicalDiscussion,
        isTrue,
      );
      // Two declining domains is, on its own.
      expect(
        snapshotWith(readings: <DomainReading>[
          down,
          const DomainReading(
            domain: CognitiveDomain.procedural,
            current: 60,
            baseline: 80,
            sessionCount: 4,
            history: <double>[],
          ),
        ]).suggestsClinicalDiscussion,
        isTrue,
      );
    });
  });

  group('clinical report', () {
    late ClinicalReport report;

    setUp(() {
      final AppState state = AppState();
      addTearDown(state.dispose);
      report = ClinicalReport.build(
        patient: state.patient,
        intake: DemoJourney.intake(now: DateTime(2026, 8, 28)),
        snapshot: monitor.snapshot(
          sessions: DemoJourney.sessions(),
          baseline: monitor.buildBaseline(DemoJourney.sessions(), at: DateTime(2026, 6, 1)),
          intake: DemoJourney.intake(now: DateTime(2026, 8, 28)),
        ),
        now: DateTime(2026, 8, 28),
      );
    });

    test('covers every section a clinician reads, in order', () {
      expect(
        report.sections.map((ReportSection s) => s.title),
        containsAllInOrder(<String>[
          'Reason for assessment',
          'Patient-reported symptoms',
          'Caregiver observations',
          'Functional status',
          'Cognitive activity performance',
          'Medical & contextual factors',
        ]),
      );
    });

    test('carries the onboarding answers a checklist cannot', () {
      final ReportSection reason = report.sections
          .firstWhere((ReportSection s) => s.title == 'Reason for assessment');
      // The ranking the family gave, in their order.
      expect(reason.lines.any((String l) => l.startsWith('Reported as affecting')),
          isTrue);
      expect(reason.lines.firstWhere((String l) => l.startsWith('Reported as affecting')),
          contains('1. forgets recent conversations'));
      // And the concrete episode, verbatim.
      expect(reason.note, contains('electricity bill'));

      // The four-point support scale survives, including the level the legacy
      // three-point scale cannot express.
      final ReportSection function = report.sections
          .firstWhere((ReportSection s) => s.title == 'Functional status');
      expect(function.lines, contains('Taking medicines: needs reminders'));
      expect(function.lines, contains('Eating: independent'));

      // And the half of the record that is not about loss.
      final ReportSection strengths = report.sections.firstWhere(
          (ReportSection s) => s.title == 'Preserved abilities and priorities');
      expect(strengths.lines.any((String l) => l.contains('gardening')), isTrue);
      expect(strengths.lines.any((String l) => l.contains('tulsi')), isTrue);
      expect(strengths.lines.any((String l) => l.contains('taking something useful')),
          isTrue);
    });

    test('reported safety concerns reach the report as their own section', () {
      final ReportSection safety = report.sections
          .firstWhere((ReportSection s) => s.title == 'Reported safety concerns');
      expect(safety.lines, contains('Forgetting medicines'));
      expect(safety.lines, contains('Handling money'));
      // Nothing about wandering was reported, so nothing is claimed about it.
      expect(safety.lines.any((String l) => l.contains('lost')), isFalse);
    });

    test('separates what the patient reported from what the caregiver observed', () {
      final ReportSection caregiver =
          report.sections.firstWhere((ReportSection s) => s.title == 'Caregiver observations');
      expect(caregiver.lines.any((String l) => l.startsWith('Observed:')), isTrue);
      expect(caregiver.lines.any((String l) => l.startsWith('Not observed:')), isTrue);
    });

    test('names no condition and states that it is not a diagnosis', () {
      final String text = report.asPlainText().toLowerCase();
      expect(text, contains('not a diagnosis'));
      for (final String forbidden in <String>[
        'alzheimer',
        'likely dementia',
        'probability',
        'diagnosis of',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: 'the report must not claim $forbidden');
      }
    });

    test('reports change against the personal baseline, not a population norm', () {
      final ReportSection performance = report.sections
          .firstWhere((ReportSection s) => s.title == 'Cognitive activity performance');
      expect(performance.lines.any((String l) => l.contains('baseline')), isTrue);
      expect(performance.note, contains("person's own first"));
    });
  });

  group('the assistant refuses to diagnose', () {
    const HealthAssistant assistant = HealthAssistant();

    test('every phrasing of the diagnosis question is caught', () {
      for (final String question in <String>[
        'Do I have Alzheimer\'s?',
        'is it dementia',
        'Am I getting dementia doctor?',
        'Can you diagnose me',
        'what\'s wrong with me',
        'How long do I have',
      ]) {
        final HealthAnswer? answer =
            assistant.diagnosisGuard(question, snapshot: MonitoringSnapshot.empty);
        expect(answer, isNotNull, reason: 'not guarded: $question');
        expect(answer!.text.toLowerCase(), contains('cannot diagnose'));
        expect(answer.text.toLowerCase(), contains('professional assessment'));
      }
    });

    test('an ordinary question is not caught by the guard', () {
      expect(
        assistant.diagnosisGuard('what should I do today', snapshot: MonitoringSnapshot.empty),
        isNull,
      );
    });

    test('answers are grounded in the record and carry the monitoring caveat', () {
      final AppState state = AppState();
      addTearDown(state.dispose);
      final MonitoringSnapshot snapshot = monitor.snapshot(
        sessions: DemoJourney.sessions(),
        baseline: monitor.buildBaseline(DemoJourney.sessions(), at: DateTime(2026, 6, 1)),
        intake: DemoJourney.intake(now: DateTime(2026, 8, 28)),
      );

      final HealthAnswer explained = assistant.answer(
        HealthQuickAction.explainResults,
        patient: state.patient,
        intake: DemoJourney.intake(now: DateTime(2026, 8, 28)),
        snapshot: snapshot,
      );
      expect(explained.text.toLowerCase(), contains('not a diagnosis'));
      expect(explained.bullets, isNotEmpty);
      expect(explained.grounded, isTrue);

      final HealthAnswer doctor = assistant.answer(
        HealthQuickAction.prepareForDoctor,
        patient: state.patient,
        intake: DemoJourney.intake(now: DateTime(2026, 8, 28)),
        snapshot: snapshot,
      );
      expect(doctor.bullets.length, greaterThan(2));
    });
  });

  group('the assessment survives a restart', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mm_assessment_test');
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    Future<(HiveStore, AppState)> launch() async {
      final HiveStore store = await HiveStore.open(path: dir.path);
      final AppState state = AppState(
        patients: HivePatientRepository(store),
        games: HiveGameRepository(store),
        analytics: HiveAnalyticsRepository(store),
        reminders: HiveReminderRepository(store),
        daily: HiveDailyRepository(store),
        assessment: HiveAssessmentRepository(store),
        settings: HiveSettingsRepository(store),
        sync: HiveSyncRepository(store),
      );
      await state.hydrate();
      return (store, state);
    }

    test('a half-finished questionnaire resumes where it stopped', () async {
      var (HiveStore store, AppState state) = await launch();

      state.giveConsent();
      state.saveIntakeProfile(
        name: 'Rahul Sharma',
        age: 67,
        language: 'Hindi',
        occupation: 'Teacher',
        completedBy: CompletedBy.patient,
      );
      state.saveOnboarding(const OnboardingRecord(
        helper: HelperRole.myself,
        education: EducationLevel.graduate,
        diagnosisStatus: DiagnosisStatus.notSure,
        treatmentStatus: TreatmentStatus.no,
        difficulties: <DailyDifficulty>{DailyDifficulty.recentConversations},
        topDifficulties: <DailyDifficulty>[DailyDifficulty.recentConversations],
        onset: OnsetWindow.sixToTwelveMonths,
        course: ProgressionPattern.graduallyWorse,
      ));
      await state.flush();
      // Stopped in the middle: the memory difficulty has follow-ups and they
      // have not been answered.
      expect(state.nextIntakeStep, IntakeStep.probes);

      // ── the app is closed and reopened ────────────────────────────────
      state.dispose();
      await store.close();
      (store, state) = await launch();

      expect(state.intake.consentGiven, isTrue);
      expect(state.patient.occupation, 'Teacher');
      expect(state.intake.onboarding.education, EducationLevel.graduate);
      // The derived structures come back with the answers that built them.
      expect(state.intake.reason.onset, OnsetWindow.sixToTwelveMonths);
      expect(state.intake.symptoms.responses['mem_conv'], SymptomFrequency.veryOften);
      expect(state.patient.name, 'Rahul Sharma');
      expect(state.patient.age, 67);
      // And it resumes at the next unanswered question, not at the start.
      expect(state.nextIntakeStep, IntakeStep.probes);
      expect(state.intakeComplete, isFalse);

      state.dispose();
      await store.close();
    });

    test('a captured baseline survives a restart and anchors later readings', () async {
      var (HiveStore store, AppState state) = await launch();

      // Played, not just marked: a fresh install has no seeded history, so a
      // baseline can only come from activities that were actually done.
      for (final GameId id in GameId.values) {
        state.finishGame(
          id,
          const GamePerformance(
            accuracy: 70,
            focus: 68,
            memory: 72,
            hintsUsed: 1,
            mistakes: 2,
            seconds: 100,
            completed: true,
            attempts: 10,
            correct: 7,
            responseMillis: 12000,
          ),
        );
        state.markBaselineActivity(id);
      }
      await state.captureBaseline(now: DateTime(2026, 6, 1));
      await state.flush();

      final double? memoryBaseline =
          state.baseline?.scoreFor(CognitiveDomain.memory);
      expect(memoryBaseline, isNotNull);
      expect(state.intakeComplete, isTrue);

      state.dispose();
      await store.close();
      (store, state) = await launch();

      expect(state.baseline, isNotNull);
      expect(state.baseline!.scoreFor(CognitiveDomain.memory), memoryBaseline);
      expect(state.monitoring.hasBaseline, isTrue);

      state.dispose();
      await store.close();
    });

    test('richer session metrics round-trip through the box', () async {
      var (HiveStore store, AppState state) = await launch();

      state.finishGame(
        GameId.procedure,
        const GamePerformance(
          accuracy: 88,
          focus: 84,
          memory: 86,
          hintsUsed: 1,
          mistakes: 2,
          seconds: 96,
          completed: true,
          attempts: 12,
          correct: 10,
          responseMillis: 8000,
        ),
      );
      await state.flush();

      state.dispose();
      await store.close();
      (store, state) = await launch();

      final GameSession restored = state.sessionsFor(GameId.procedure).first;
      expect(restored.performance.attempts, 12);
      expect(restored.performance.correct, 10);
      expect(restored.performance.responseMillis, 8000);
      expect(restored.performance.responseLabel, '8.0s');

      state.dispose();
      await store.close();
    });
  });

  group('the demonstration history', () {
    test('produces a stable twelve-week record with a real decline pattern', () {
      final List<GameSession> first = DemoJourney.sessions();
      final List<GameSession> second = DemoJourney.sessions();

      // Seeded: identical between runs, so a rehearsed number is the number
      // shown on the day.
      expect(first.length, second.length);
      expect(first.first.performance.accuracy, second.first.performance.accuracy);
      // One session per scored activity per week — Mood Canvas has no domain
      // and no score, so `DemoJourney.sessions()` deliberately skips it.
      final int scoredGames =
          GameId.values.where((GameId id) => GameDomains.of(id) != null).length;
      expect(first.length, DemoJourney.weeks * scoredGames);

      final MonitoringSnapshot snapshot = monitor.snapshot(
        sessions: first,
        baseline: monitor.buildBaseline(first, at: DateTime(2026, 6, 1)),
        intake: DemoJourney.intake(now: DateTime(2026, 8, 28)),
      );

      final Set<CognitiveDomain> declining =
          snapshot.declining.map((DomainReading r) => r.domain).toSet();
      expect(declining, contains(CognitiveDomain.memory));
      expect(declining, contains(CognitiveDomain.procedural));
      // Auditory was authored as stable — a uniform decline would look fake.
      expect(declining, isNot(contains(CognitiveDomain.auditory)));
      expect(snapshot.suggestsClinicalDiscussion, isTrue);
    });
  });

  group('the assessment belongs to an account', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mm_account_test');
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    Future<(HiveStore, AppState)> launch() async {
      final HiveStore store = await HiveStore.open(path: dir.path);
      final AppState state = AppState(
        patients: HivePatientRepository(store),
        games: HiveGameRepository(store),
        analytics: HiveAnalyticsRepository(store),
        reminders: HiveReminderRepository(store),
        daily: HiveDailyRepository(store),
        assessment: HiveAssessmentRepository(store),
        settings: HiveSettingsRepository(store),
        sync: HiveSyncRepository(store),
      );
      await state.hydrate();
      return (store, state);
    }

    test('answers given after signing in are filed under the uid', () async {
      var (HiveStore store, AppState state) = await launch();

      await state.signInAccount('uid-priya');
      state.giveConsent();
      state.saveReason(const ReasonForVisit(
        concerns: <PresentingConcern>{PresentingConcern.memoryProblems},
        onset: OnsetWindow.recent,
        progression: ProgressionPattern.slightlyWorse,
      ));
      await state.flush();

      expect(state.accountId, 'uid-priya');
      expect(state.intake.accountId, 'uid-priya');

      // The account is remembered, so a restart reopens the same record
      // without waiting for the network or a fresh sign-in.
      state.dispose();
      await store.close();
      (store, state) = await launch();

      expect(state.accountId, 'uid-priya');
      expect(state.intake.reason.onset, OnsetWindow.recent);

      state.dispose();
      await store.close();
    });

    test('a second person on the same device gets their own record', () async {
      final (HiveStore store, AppState state) = await launch();

      await state.signInAccount('uid-priya');
      state.giveConsent();
      state.saveReason(const ReasonForVisit(
        concerns: <PresentingConcern>{PresentingConcern.memoryProblems},
        onset: OnsetWindow.recent,
        progression: ProgressionPattern.slightlyWorse,
      ));
      await state.flush();

      // Someone else signs in: they must not inherit those answers.
      await state.signInAccount('uid-bhaskar');
      expect(state.intake.consentGiven, isFalse);
      expect(state.intake.reason.concerns, isEmpty);
      expect(state.nextIntakeStep, IntakeStep.consent);

      state.giveConsent();
      await state.flush();

      // And the first person's record is still intact underneath.
      await state.signInAccount('uid-priya');
      expect(state.intake.reason.onset, OnsetWindow.recent);

      state.dispose();
      await store.close();
    });

    test('answers given before signing in are adopted, not discarded', () async {
      final (HiveStore store, AppState state) = await launch();

      // Someone starts the questionnaire, then creates an account partway.
      state.giveConsent();
      state.saveReason(const ReasonForVisit(
        concerns: <PresentingConcern>{PresentingConcern.familyNoticed},
        onset: OnsetWindow.oneToTwoYears,
        progression: ProgressionPattern.graduallyWorse,
      ));
      await state.flush();
      expect(state.accountId, isNull);

      await state.signInAccount('uid-late');
      await state.flush();

      expect(state.intake.reason.onset, OnsetWindow.oneToTwoYears);
      expect(state.intake.accountId, 'uid-late');

      state.dispose();
      await store.close();
    });

    test('signing out unbinds the account without deleting the record', () async {
      final (HiveStore store, AppState state) = await launch();

      await state.signInAccount('uid-priya');
      state.giveConsent();
      await state.flush();

      await state.signOutAccount();
      expect(state.accountId, isNull);

      await state.signInAccount('uid-priya');
      expect(state.intake.consentGiven, isTrue);

      state.dispose();
      await store.close();
    });
  });
}

/// Signing in, out and back in — the lifecycle a real person actually has.
///
/// All of it against real Hive storage, because the point of every assertion
/// here is what survives a restart and what must not cross between accounts.
void accountTests() {
  group('accounts', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mm_accounts_test');
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    Future<(HiveStore, AppState)> launch() async {
      final HiveStore store = await HiveStore.open(path: dir.path);
      final AppState state = AppState(
        patients: HivePatientRepository(store),
        games: HiveGameRepository(store),
        analytics: HiveAnalyticsRepository(store),
        reminders: HiveReminderRepository(store),
        daily: HiveDailyRepository(store),
        assessment: HiveAssessmentRepository(store),
        settings: HiveSettingsRepository(store),
        sync: HiveSyncRepository(store),
      );
      await state.hydrate();
      return (store, state);
    }

    Future<void> answerEverything(AppState state, {required String name}) async {
      state.giveConsent();
      state.saveIntakeProfile(
        name: name,
        age: 70,
        language: 'English',
        occupation: 'Teacher',
        completedBy: CompletedBy.patient,
      );
      state.saveOnboarding(OnboardingRecord(
        helper: HelperRole.myself,
        education: EducationLevel.graduate,
        diagnosisStatus: DiagnosisStatus.no,
        treatmentStatus: TreatmentStatus.no,
        difficulties: const <DailyDifficulty>{DailyDifficulty.nothingNoticed},
        onset: OnsetWindow.unsure,
        course: ProgressionPattern.noChange,
        support: <DailyActivity, SupportLevel>{
          for (final DailyActivity a in DailyActivity.values)
            a: SupportLevel.independent,
        },
        behaviourChanges: const <BehaviourChange>{BehaviourChange.noMajorChanges},
        safetyConcerns: const <SafetyConcern>{SafetyConcern.noMajorConcerns},
        enjoys: const <EnjoyedActivity>{EnjoyedActivity.music},
        goals: const <SupportGoal>[SupportGoal.stayingMentallyActive],
      ));
      state.completeIntakeQuestionnaire(now: DateTime(2026, 6, 1));
      await state.flush();
    }

    test('a returning account is not asked to do the onboarding again',
        () async {
      var (HiveStore store, AppState state) = await launch();

      await state.signInAccount('uid-anita');
      state.setRole(AppRole.patient);
      await answerEverything(state, name: 'Anita Das');
      await state.flush();

      state.dispose();
      await store.close();

      // A relaunch: `main` restores the Firebase session and binds it before
      // the first frame, which is exactly this call.
      (store, state) = await launch();
      await state.signInAccount('uid-anita');

      expect(state.intake.isComplete, isTrue,
          reason: 'the questionnaire must not be asked twice');
      expect(state.patient.name, 'Anita Das');
      expect(state.role, AppRole.patient,
          reason: 'the role is restored, so no role picker either');
      expect(state.accountId, 'uid-anita');

      state.dispose();
      await store.close();
    });

    test('a second account on the same phone gets its own blank record',
        () async {
      final (HiveStore store, AppState state) = await launch();

      await state.signInAccount('uid-anita');
      await answerEverything(state, name: 'Anita Das');

      // Someone else picks up the same phone.
      await state.signOutAccount();
      expect(state.intake.isComplete, isFalse);
      expect(state.patient.name, isNot('Anita Das'));

      await state.signInAccount('uid-rahul');
      expect(state.intake.isComplete, isFalse,
          reason: "one person's answers must never appear under another's account");
      expect(state.role, AppRole.none,
          reason: 'a new account picks its own role rather than inheriting one');
      expect(state.patient.name, isNot('Anita Das'));
      expect(state.sessions, isEmpty);

      // And the first account still has everything when it comes back.
      await state.signOutAccount();
      await state.signInAccount('uid-anita');
      expect(state.intake.isComplete, isTrue);
      expect(state.patient.name, 'Anita Das');

      state.dispose();
      await store.close();
    });

    test('activities are filed under the account that played them', () async {
      final (HiveStore store, AppState state) = await launch();

      await state.signInAccount('uid-anita');
      state.finishGame(
        GameId.memoryCards,
        const GamePerformance(
          accuracy: 80,
          focus: 78,
          memory: 82,
          hintsUsed: 0,
          mistakes: 1,
          seconds: 90,
          completed: true,
          attempts: 10,
          correct: 8,
          responseMillis: 11000,
        ),
      );
      await state.flush();
      expect(state.sessions, hasLength(1));

      await state.signInAccount('uid-rahul');
      expect(state.sessions, isEmpty,
          reason: 'a new account starts with no history of its own');

      await state.signOutAccount();
      await state.signInAccount('uid-anita');
      expect(state.sessions, hasLength(1),
          reason: 'and the original account gets its history back');

      state.dispose();
      await store.close();
    });
  });
}
