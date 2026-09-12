import '../../core/models/onboarding.dart';
import '../../l10n/app_localizations.dart';

/// Localized display text for every value in `core/models/onboarding.dart`.
///
/// The model has no widget context to resolve [AppLocalizations], so the
/// labels live here — the same split `assessment_l10n.dart` already uses for
/// the structures the report reads.
///
/// Follow-up options are looked up by their *id* rather than by an enum,
/// because [ProbeCatalogue] is deliberately data-driven: adding a question
/// means adding a row there and a case here, and nothing else.

String helperRoleLabel(AppLocalizations l, HelperRole r) => switch (r) {
      HelperRole.myself => l.onbHelperMyself,
      HelperRole.spouse => l.onbHelperSpouse,
      HelperRole.child => l.onbHelperChild,
      HelperRole.otherFamily => l.onbHelperOtherFamily,
      HelperRole.professionalCaregiver => l.onbHelperProfessional,
      HelperRole.other => l.onbOptionOther,
    };

String educationLabel(AppLocalizations l, EducationLevel e) => switch (e) {
      EducationLevel.noFormalSchooling => l.onbEducationNone,
      EducationLevel.primary => l.onbEducationPrimary,
      EducationLevel.middle => l.onbEducationMiddle,
      EducationLevel.secondary => l.onbEducationSecondary,
      EducationLevel.higherSecondary => l.onbEducationHigherSecondary,
      EducationLevel.graduate => l.onbEducationGraduate,
      EducationLevel.postgraduate => l.onbEducationPostgraduate,
      EducationLevel.preferNotToSay => l.onbPreferNotToSay,
    };

String diagnosisStatusLabel(AppLocalizations l, DiagnosisStatus s) => switch (s) {
      DiagnosisStatus.yes => l.intakeYes,
      DiagnosisStatus.no => l.intakeNo,
      DiagnosisStatus.notSure => l.onbNotSure,
    };

String diagnosedConditionLabel(AppLocalizations l, DiagnosedCondition c) => switch (c) {
      DiagnosedCondition.alzheimers => l.onbConditionAlzheimers,
      DiagnosedCondition.vascular => l.onbConditionVascular,
      DiagnosedCondition.lewyBody => l.onbConditionLewy,
      DiagnosedCondition.frontotemporal => l.onbConditionFrontotemporal,
      DiagnosedCondition.mixedOther => l.onbConditionMixedOther,
      DiagnosedCondition.dontKnow => l.onbConditionDontKnow,
      DiagnosedCondition.preferNotToSay => l.onbPreferNotToSay,
    };

String careProfessionalLabel(AppLocalizations l, CareProfessional p) => switch (p) {
      CareProfessional.neurologist => l.onbProfNeurologist,
      CareProfessional.psychiatrist => l.onbProfPsychiatrist,
      CareProfessional.psychologist => l.onbProfPsychologist,
      CareProfessional.physician => l.onbProfPhysician,
      CareProfessional.otherSpecialist => l.onbProfOtherSpecialist,
      CareProfessional.familyCaregiver => l.onbProfFamilyCaregiver,
      CareProfessional.noRegularSupport => l.onbProfNoRegular,
    };

String treatmentStatusLabel(AppLocalizations l, TreatmentStatus s) => switch (s) {
      TreatmentStatus.yes => l.intakeYes,
      TreatmentStatus.no => l.intakeNo,
      TreatmentStatus.notSure => l.onbNotSure,
    };

String sedatingMedicineLabel(AppLocalizations l, SedatingMedicineClass c) => switch (c) {
      SedatingMedicineClass.sleepOrAnxiety => l.onbSedatingSleepAnxiety,
      SedatingMedicineClass.allergyOrCold => l.onbSedatingAllergyCold,
      SedatingMedicineClass.bladder => l.onbSedatingBladder,
      SedatingMedicineClass.olderAntidepressants => l.onbSedatingOlderAntidepressants,
      SedatingMedicineClass.nauseaOrVertigo => l.onbSedatingNauseaVertigo,
      SedatingMedicineClass.noneOfThese => l.onbSedatingNoneOfThese,
    };

String dailyDifficultyLabel(AppLocalizations l, DailyDifficulty d) => switch (d) {
      DailyDifficulty.recentConversations => l.onbDiffRecentConversations,
      DailyDifficulty.repeatingQuestions => l.onbDiffRepeatingQuestions,
      DailyDifficulty.appointments => l.onbDiffAppointments,
      DailyDifficulty.misplacingThings => l.onbDiffMisplacingThings,
      DailyDifficulty.timeOrPlace => l.onbDiffTimeOrPlace,
      DailyDifficulty.gettingLost => l.onbDiffGettingLost,
      DailyDifficulty.findingWords => l.onbDiffFindingWords,
      DailyDifficulty.followingConversations => l.onbDiffFollowingConversations,
      DailyDifficulty.decisionsProblems => l.onbDiffDecisionsProblems,
      DailyDifficulty.familiarTasks => l.onbDiffFamiliarTasks,
      DailyDifficulty.managingMedicines => l.onbDiffManagingMedicines,
      DailyDifficulty.managingMoney => l.onbDiffManagingMoney,
      DailyDifficulty.moodOrBehaviour => l.onbDiffMoodOrBehaviour,
      DailyDifficulty.lostInterest => l.onbDiffLostInterest,
      DailyDifficulty.sleepChanges => l.onbDiffSleepChanges,
      DailyDifficulty.nothingNoticed => l.onbDiffNothingNoticed,
      DailyDifficulty.somethingElse => l.onbOptionOther,
    };

String dailyActivityLabel(AppLocalizations l, DailyActivity a) => switch (a) {
      DailyActivity.eating => l.onbActivityEating,
      DailyActivity.dressing => l.onbActivityDressing,
      DailyActivity.bathing => l.onbActivityBathing,
      DailyActivity.toilet => l.onbActivityToilet,
      DailyActivity.medicines => l.onbActivityMedicines,
      DailyActivity.household => l.onbActivityHousehold,
      DailyActivity.money => l.onbActivityMoney,
      DailyActivity.goingOut => l.onbActivityGoingOut,
    };

String supportLevelLabel(AppLocalizations l, SupportLevel s) => switch (s) {
      SupportLevel.independent => l.onbSupportIndependent,
      SupportLevel.needsReminders => l.onbSupportNeedsReminders,
      SupportLevel.needsSomeHelp => l.onbSupportNeedsSomeHelp,
      SupportLevel.needsFullHelp => l.onbSupportNeedsFullHelp,
    };

String behaviourChangeLabel(AppLocalizations l, BehaviourChange b) => switch (b) {
      BehaviourChange.moreIrritable => l.onbBehaviourMoreIrritable,
      BehaviourChange.moreWithdrawn => l.onbBehaviourMoreWithdrawn,
      BehaviourChange.lessInterested => l.onbBehaviourLessInterested,
      BehaviourChange.restlessAgitated => l.onbBehaviourRestlessAgitated,
      BehaviourChange.suspicious => l.onbBehaviourSuspicious,
      BehaviourChange.repetitive => l.onbBehaviourRepetitive,
      BehaviourChange.sleepChanges => l.onbBehaviourSleepChanges,
      BehaviourChange.eatingChanges => l.onbBehaviourEatingChanges,
      BehaviourChange.seeingOrHearingThings => l.onbBehaviourSeeingOrHearingThings,
      BehaviourChange.noMajorChanges => l.onbBehaviourNoMajorChanges,
      BehaviourChange.other => l.onbOptionOther,
    };

String safetyConcernLabel(AppLocalizations l, SafetyConcern c) => switch (c) {
      SafetyConcern.gettingLostOutside => l.onbSafetyGettingLostOutside,
      SafetyConcern.leavingHomeUnannounced => l.onbSafetyLeavingHome,
      SafetyConcern.fallsOrBalance => l.onbSafetyFallsOrBalance,
      SafetyConcern.forgettingMedicines => l.onbSafetyForgettingMedicines,
      SafetyConcern.stoveOrAppliances => l.onbSafetyStoveOrAppliances,
      SafetyConcern.handlingMoney => l.onbSafetyHandlingMoney,
      SafetyConcern.travellingAlone => l.onbSafetyTravellingAlone,
      SafetyConcern.noMajorConcerns => l.onbSafetyNoMajorConcerns,
      SafetyConcern.other => l.onbOptionOther,
    };

String incidentFrequencyLabel(AppLocalizations l, IncidentFrequency f) => switch (f) {
      IncidentFrequency.never => l.onbWanderingNever,
      IncidentFrequency.once => l.onbWanderingOnce,
      IncidentFrequency.moreThanOnce => l.onbWanderingMoreThanOnce,
      IncidentFrequency.regularly => l.onbWanderingRegularly,
    };

String enjoyedActivityLabel(AppLocalizations l, EnjoyedActivity e) => switch (e) {
      EnjoyedActivity.music => l.onbEnjoyMusic,
      EnjoyedActivity.talkingWithFamily => l.onbEnjoyTalkingWithFamily,
      EnjoyedActivity.walking => l.onbEnjoyWalking,
      EnjoyedActivity.cooking => l.onbEnjoyCooking,
      EnjoyedActivity.gardening => l.onbEnjoyGardening,
      EnjoyedActivity.religious => l.onbEnjoyReligious,
      EnjoyedActivity.television => l.onbEnjoyTelevision,
      EnjoyedActivity.reading => l.onbEnjoyReading,
      EnjoyedActivity.puzzles => l.onbEnjoyPuzzles,
      EnjoyedActivity.meetingFriends => l.onbEnjoyMeetingFriends,
      EnjoyedActivity.householdWork => l.onbEnjoyHouseholdWork,
      EnjoyedActivity.other => l.onbOptionOther,
    };

String supportGoalLabel(AppLocalizations l, SupportGoal g) => switch (g) {
      SupportGoal.rememberingThings => l.onbGoalRememberingThings,
      SupportGoal.dailyRoutines => l.onbGoalDailyRoutines,
      SupportGoal.stayingMentallyActive => l.onbGoalStayingMentallyActive,
      SupportGoal.everydayDifficulties => l.onbGoalEverydayDifficulties,
      SupportGoal.confidenceIndependence => l.onbGoalConfidenceIndependence,
      SupportGoal.caregiverUnderstanding => l.onbGoalCaregiverUnderstanding,
      SupportGoal.trackingProgress => l.onbGoalTrackingProgress,
      SupportGoal.sharingWithDoctor => l.onbGoalSharingWithDoctor,
      SupportGoal.safety => l.onbGoalSafety,
      SupportGoal.other => l.onbOptionOther,
    };

/// The prompt above a follow-up question, keyed by [ProbeQuestion.id].
String probePrompt(AppLocalizations l, String questionId) => switch (questionId) {
      'probe_memory_span' => l.onbProbeMemorySpan,
      'probe_memory_awareness' => l.onbProbeMemoryAwareness,
      'probe_misplace_what' => l.onbProbeMisplaceWhat,
      'probe_misplace_after' => l.onbProbeMisplaceAfter,
      'probe_lost_where' => l.onbProbeLostWhere,
      'probe_lost_company' => l.onbProbeLostCompany,
      'probe_meds_what' => l.onbProbeMedsWhat,
      'probe_mood_when' => l.onbProbeMoodWhen,
      'probe_tasks_which' => l.onbProbeTasksWhich,
      'probe_tasks_stage' => l.onbProbeTasksStage,
      // Every "how often" question asks the same thing, so it shares one
      // string rather than four near-identical translations.
      _ => l.onbProbeHowOften,
    };

/// One follow-up answer, keyed by its option id.
///
/// Option ids are unique across the catalogue on purpose — a single lookup
/// keeps the call sites from having to know which question an option came
/// from, and a collision would be caught the first time the wrong label
/// appeared on screen.
String probeOptionLabel(AppLocalizations l, String optionId) => switch (optionId) {
      // frequencies, shared by every "_often" question
      'occasionally' => l.onbFreqOccasionally,
      'sometimes' => l.assessmentFrequencySometimes,
      'often' => l.assessmentFrequencyOften,
      'veryOften' => l.assessmentFrequencyVeryOften,
      // memory
      'withinMinutes' => l.onbProbeSpanWithinMinutes,
      'laterSameDay' => l.onbProbeSpanLaterSameDay,
      'afterFewDays' => l.onbProbeSpanAfterFewDays,
      'varies' => l.onbProbeSpanVaries,
      'awareOfIt' => l.onbProbeAwareOfIt,
      'partlyAware' => l.onbProbeAwarePartly,
      'notAware' => l.onbProbeAwareNot,
      'becomesUpset' => l.onbProbeAwareUpset,
      // misplacing
      'keys' => l.onbProbeItemKeys,
      'phone' => l.onbProbeItemPhone,
      'wallet' => l.onbProbeItemWallet,
      'glasses' => l.onbProbeItemGlasses,
      'medicines' => l.onbProbeItemMedicines,
      'documents' => l.onbProbeItemDocuments,
      'findsItThemselves' => l.onbProbeAfterFindsThemselves,
      'someoneHelps' => l.onbProbeAfterSomeoneHelps,
      'becomesWorried' => l.onbProbeAfterBecomesWorried,
      'accusesSomeone' => l.onbProbeAfterAccusesSomeone,
      // getting lost
      'familiarRoutes' => l.onbProbeLostFamiliarRoutes,
      'unfamiliarPlaces' => l.onbProbeLostUnfamiliarPlaces,
      'nearHome' => l.onbProbeLostNearHome,
      'insideTheHouse' => l.onbProbeLostInsideTheHouse,
      'goesOutAlone' => l.onbProbeLostGoesAlone,
      'needsSomeone' => l.onbProbeLostNeedsSomeone,
      'noLongerGoesOut' => l.onbProbeLostNoLongerGoesOut,
      // medicines
      'forgetsDoses' => l.onbProbeMedsForgets,
      'wrongTime' => l.onbProbeMedsWrongTime,
      'takesTwice' => l.onbProbeMedsTakesTwice,
      'refuses' => l.onbProbeMedsRefuses,
      'someoneManages' => l.onbProbeMedsSomeoneManages,
      // mood
      'lateAfternoonEvening' => l.onbProbeMoodLateAfternoon,
      'morning' => l.onbProbeMoodMorning,
      'whenTiredOrCrowded' => l.onbProbeMoodTiredOrCrowded,
      'noPattern' => l.onbProbeMoodNoPattern,
      // familiar tasks
      'cooking' => l.onbProbeTaskCooking,
      'householdAppliances' => l.onbProbeTaskAppliances,
      'dressing' => l.onbProbeTaskDressing,
      'usingThePhone' => l.onbProbeTaskPhone,
      'personalCare' => l.onbProbeTaskPersonalCare,
      'cannotStart' => l.onbProbeStageCannotStart,
      'startsThenStops' => l.onbProbeStageStartsThenStops,
      'stepsOutOfOrder' => l.onbProbeStageOutOfOrder,
      'needsPrompting' => l.onbProbeStageNeedsPrompting,
      // shared
      'notSure' => l.onbNotSure,
      'other' => l.onbOptionOther,
      _ => optionId,
    };
