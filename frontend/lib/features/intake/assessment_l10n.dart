import '../../core/models/assessment.dart';
import '../../l10n/app_localizations.dart';

/// Localized display text for the [PresentingConcern], [OnsetWindow],
/// [ProgressionPattern], [SymptomFrequency], [SymptomDomain], [SymptomItem],
/// [FunctionalItem], [MedicalCondition], [SleepQuality], [MoodFrequency] and
/// [CompletedBy] values from `core/models/assessment.dart`.
///
/// The model file itself has no widget context to resolve [AppLocalizations],
/// so these mapping functions live here instead — call them with the current
/// [AppLocalizations] in place of the model's own `.label`/`.text` getters.

String presentingConcernLabel(AppLocalizations l, PresentingConcern c) => switch (c) {
      PresentingConcern.memoryProblems => l.assessmentConcernMemoryProblems,
      PresentingConcern.concentration => l.assessmentConcernConcentration,
      PresentingConcern.appointments => l.assessmentConcernAppointments,
      PresentingConcern.wordFinding => l.assessmentConcernWordFinding,
      PresentingConcern.confusion => l.assessmentConcernConfusion,
      PresentingConcern.dailyTasks => l.assessmentConcernDailyTasks,
      PresentingConcern.familyNoticed => l.assessmentConcernFamilyNoticed,
      PresentingConcern.selfMonitoring => l.assessmentConcernSelfMonitoring,
      PresentingConcern.doctorRecommended => l.assessmentConcernDoctorRecommended,
    };

String onsetWindowLabel(AppLocalizations l, OnsetWindow o) => switch (o) {
      OnsetWindow.recent => l.assessmentOnsetRecent,
      OnsetWindow.oneToSixMonths => l.assessmentOnset1to6Months,
      OnsetWindow.sixToTwelveMonths => l.assessmentOnset6to12Months,
      OnsetWindow.oneToTwoYears => l.assessmentOnset1to2Years,
      OnsetWindow.overTwoYears => l.assessmentOnsetOver2Years,
      OnsetWindow.unsure => l.assessmentOnsetUnsure,
    };

String progressionPatternLabel(AppLocalizations l, ProgressionPattern p) => switch (p) {
      ProgressionPattern.noChange => l.assessmentProgressionNoChange,
      ProgressionPattern.slightlyWorse => l.assessmentProgressionSlightlyWorse,
      ProgressionPattern.graduallyWorse => l.assessmentProgressionGraduallyWorse,
      ProgressionPattern.rapidlyWorse => l.assessmentProgressionRapidlyWorse,
      ProgressionPattern.fluctuating => l.assessmentProgressionFluctuating,
    };

String symptomFrequencyLabel(AppLocalizations l, SymptomFrequency f) => switch (f) {
      SymptomFrequency.never => l.assessmentFrequencyNever,
      SymptomFrequency.sometimes => l.assessmentFrequencySometimes,
      SymptomFrequency.often => l.assessmentFrequencyOften,
      SymptomFrequency.veryOften => l.assessmentFrequencyVeryOften,
    };

String symptomDomainLabel(AppLocalizations l, SymptomDomain d) => switch (d) {
      SymptomDomain.memory => l.assessmentDomainMemory,
      SymptomDomain.attentionThinking => l.assessmentDomainAttentionThinking,
      SymptomDomain.language => l.assessmentDomainLanguage,
      SymptomDomain.behaviour => l.assessmentDomainBehaviour,
      SymptomDomain.movementPerception => l.assessmentDomainMovementPerception,
    };

String symptomDomainPrompt(AppLocalizations l, SymptomDomain d) => switch (d) {
      SymptomDomain.memory => l.assessmentDomainPromptMemory,
      SymptomDomain.attentionThinking => l.assessmentDomainPromptAttentionThinking,
      SymptomDomain.language => l.assessmentDomainPromptLanguage,
      SymptomDomain.behaviour => l.assessmentDomainPromptBehaviour,
      SymptomDomain.movementPerception => l.assessmentDomainPromptMovementPerception,
    };

/// Keyed by [SymptomItem.id] — ids are the stable, permanent identity.
String symptomItemText(AppLocalizations l, SymptomItem item) => switch (item.id) {
      'mem_repeat' => l.assessmentSymptomMemRepeat,
      'mem_conv' => l.assessmentSymptomMemConv,
      'mem_appt' => l.assessmentSymptomMemAppt,
      'mem_misplace' => l.assessmentSymptomMemMisplace,
      'mem_new' => l.assessmentSymptomMemNew,
      'att_concentrate' => l.assessmentSymptomAttConcentrate,
      'att_follow' => l.assessmentSymptomAttFollow,
      'att_plan' => l.assessmentSymptomAttPlan,
      'att_money' => l.assessmentSymptomAttMoney,
      'att_solve' => l.assessmentSymptomAttSolve,
      'lang_words' => l.assessmentSymptomLangWords,
      'lang_naming' => l.assessmentSymptomLangNaming,
      'lang_understand' => l.assessmentSymptomLangUnderstand,
      'beh_interest' => l.assessmentSymptomBehInterest,
      'beh_impulsive' => l.assessmentSymptomBehImpulsive,
      'beh_social' => l.assessmentSymptomBehSocial,
      'beh_eating' => l.assessmentSymptomBehEating,
      'mov_tremor' => l.assessmentSymptomMovTremor,
      'mov_stiff' => l.assessmentSymptomMovStiff,
      'mov_balance' => l.assessmentSymptomMovBalance,
      'mov_halluc' => l.assessmentSymptomMovHalluc,
      'mov_alert' => l.assessmentSymptomMovAlert,
      'mov_dreams' => l.assessmentSymptomMovDreams,
      _ => item.text,
    };

/// Keyed by [FunctionalItem.id] — ids are the stable, permanent identity.
String functionalItemLabel(AppLocalizations l, FunctionalItem item) => switch (item.id) {
      'fn_money' => l.assessmentFunctionMoney,
      'fn_meds' => l.assessmentFunctionMeds,
      'fn_cooking' => l.assessmentFunctionCooking,
      'fn_shopping' => l.assessmentFunctionShopping,
      'fn_phone' => l.assessmentFunctionPhone,
      'fn_transport' => l.assessmentFunctionTransport,
      'fn_appointments' => l.assessmentFunctionAppointments,
      'fn_bathing' => l.assessmentFunctionBathing,
      _ => item.label,
    };

String medicalConditionLabel(AppLocalizations l, MedicalCondition c) => switch (c) {
      MedicalCondition.hypertension => l.assessmentConditionHypertension,
      MedicalCondition.diabetes => l.assessmentConditionDiabetes,
      MedicalCondition.highCholesterol => l.assessmentConditionHighCholesterol,
      MedicalCondition.strokeOrTia => l.assessmentConditionStrokeOrTia,
      MedicalCondition.parkinsons => l.assessmentConditionParkinsons,
      MedicalCondition.thyroid => l.assessmentConditionThyroid,
      MedicalCondition.headInjury => l.assessmentConditionHeadInjury,
      MedicalCondition.otherNeurological => l.assessmentConditionOtherNeurological,
    };

String sleepQualityLabel(AppLocalizations l, SleepQuality q) => switch (q) {
      SleepQuality.good => l.assessmentSleepGood,
      SleepQuality.fair => l.assessmentSleepFair,
      SleepQuality.poor => l.assessmentSleepPoor,
    };

/// Text is identical to [SymptomFrequency]'s never/sometimes/often, so this
/// reuses those three keys rather than duplicating the same English text.
String moodFrequencyLabel(AppLocalizations l, MoodFrequency m) => switch (m) {
      MoodFrequency.never => l.assessmentFrequencyNever,
      MoodFrequency.sometimes => l.assessmentFrequencySometimes,
      MoodFrequency.often => l.assessmentFrequencyOften,
    };

String completedByLabel(AppLocalizations l, CompletedBy c) => switch (c) {
      CompletedBy.patient => l.assessmentCompletedByPatient,
      CompletedBy.caregiver => l.assessmentCompletedByCaregiver,
      CompletedBy.familyMember => l.assessmentCompletedByFamilyMember,
      CompletedBy.clinician => l.assessmentCompletedByClinician,
    };

/// Keyed by the observation id from [CaregiverObservation.catalogue].
String caregiverObservationLabel(AppLocalizations l, String id, String fallback) => switch (id) {
      'cg_repeat' => l.assessmentCaregiverObsRepeat,
      'cg_appointments' => l.assessmentCaregiverObsAppointments,
      'cg_bills' => l.assessmentCaregiverObsBills,
      'cg_words' => l.assessmentCaregiverObsWords,
      'cg_lost' => l.assessmentCaregiverObsLost,
      'cg_personality' => l.assessmentCaregiverObsPersonality,
      'cg_halluc' => l.assessmentCaregiverObsHalluc,
      'cg_withdrawn' => l.assessmentCaregiverObsWithdrawn,
      _ => fallback,
    };
