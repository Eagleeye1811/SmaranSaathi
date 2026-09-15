import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:smaran_saathi/core/models/assessment.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/models/onboarding.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/data/local/hive_store.dart';
import 'package:smaran_saathi/data/repositories/hive_repositories.dart';

import 'persistence_test.dart' show bootstrapTests;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  bootstrapTests();

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mm_cold'));
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

  test('a cold start restores the session with no help from Firebase', () async {
    var (HiveStore store, AppState state) = await launch();

    await state.signInAccount('uid-x');
    state.setRole(AppRole.caregiver);
    state.giveConsent();
    state.saveIntakeProfile(
        name: 'Bhumik', age: 72, language: 'English', occupation: 'Teacher');
    state.saveOnboarding(const OnboardingRecord(
      helper: HelperRole.child,
      education: EducationLevel.graduate,
      diagnosisStatus: DiagnosisStatus.no,
      treatmentStatus: TreatmentStatus.no,
      difficulties: <DailyDifficulty>{DailyDifficulty.nothingNoticed},
      onset: OnsetWindow.unsure,
      course: ProgressionPattern.noChange,
      behaviourChanges: <BehaviourChange>{BehaviourChange.noMajorChanges},
      safetyConcerns: <SafetyConcern>{SafetyConcern.noMajorConcerns},
      enjoys: <EnjoyedActivity>{EnjoyedActivity.music},
      goals: <SupportGoal>[SupportGoal.stayingMentallyActive],
    ));
    state.completeIntakeQuestionnaire(now: DateTime(2026, 6, 1));
    await state.flush();

    expect(state.intake.isComplete, isTrue);

    state.dispose();
    await store.close();

    // The real cold start: Firebase's first authStateChanges event is null,
    // so main() never calls signInAccount. Everything must come from disk.
    (store, state) = await launch();

    expect(state.accountId, 'uid-x');
    expect(state.role, AppRole.caregiver);
    expect(state.intake.isComplete, isTrue);

    state.dispose();
    await store.close();
  });

  test('activities played from the list build the baseline too', () async {
    final (HiveStore store, AppState state) = await launch();
    await state.signInAccount('uid-y');

    expect(state.baselineReady, isFalse);

    // Every baseline activity, played the ordinary way — from the activities
    // list rather than through the guided session screen, which used to be
    // the only thing that recorded them.
    const GamePerformance run = GamePerformance(
      accuracy: 82,
      focus: 80,
      memory: 84,
      hintsUsed: 0,
      mistakes: 1,
      seconds: 60,
      completed: true,
    );
    for (final List<GameId> day in AppState.baselinePlan) {
      for (final GameId id in day) {
        state.finishGame(id, run);
      }
    }
    await state.flush();

    expect(state.baselineRunComplete, isTrue);
    expect(state.baselineReady, isTrue,
        reason: 'the profile is frozen once the run finishes, wherever it was played');

    state.dispose();
    await store.close();
  });
}
