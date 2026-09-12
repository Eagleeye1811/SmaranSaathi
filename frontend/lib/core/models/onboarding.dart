import 'package:flutter/foundation.dart';

import 'assessment.dart';

/// The onboarding conversation — what the app asks before it measures anything.
///
/// The shape is deliberately **not** a symptom checklist. It follows the order
/// a psychologist would take a first history in: who the person is, what the
/// medical picture already is, what has actually changed in everyday life,
/// which of those changes matters most, one concrete recent example of it,
/// how much help is needed, what has changed in mood and safety — and only
/// then, what the person still enjoys and can still do.
///
/// Two structural choices carry most of the clinical weight:
///
///  - **Broad first, deep second.** One "what have you noticed?" question
///    replaces fifteen individual symptom questions. The caregiver then names
///    the three that matter most, and only *those* are explored in depth by
///    [ProbeCatalogue]. A caregiver answers at most three follow-up sets, not
///    seventeen, and the depth lands where it is informative.
///  - **Strengths are asked for explicitly.** A profile built only from
///    deficits is both clinically incomplete and demoralising to the family
///    reading it back. Part B exists so the record says what the person can
///    still do, not only what they have lost.
///
/// Nothing here diagnoses anything. Every field records what was *reported*.
///
/// The legacy structures in `assessment.dart` — [SymptomAssessment],
/// [FunctionalAssessment], [MedicalHistory], [ReasonForVisit],
/// [CaregiverObservation] — are derived from this record rather than collected
/// separately, so the clinician report, the AI context and the care plan keep
/// reading one representation while the questions asked on screen change.

// ─────────────────────────────────────────────────────────────────────────
// Part A · Q1 — about the person
// ─────────────────────────────────────────────────────────────────────────

/// Who is filling this in. Asked first because it changes how every later
/// answer should be read: "I forget things" and "she forgets things" are
/// different kinds of evidence, and people with cognitive change frequently
/// under-report it while the person living with them does not.
enum HelperRole { myself, spouse, child, otherFamily, professionalCaregiver, other }

extension HelperRoleX on HelperRole {
  /// How the report should attribute the answers.
  CompletedBy get completedBy => switch (this) {
        HelperRole.myself => CompletedBy.patient,
        HelperRole.spouse || HelperRole.child || HelperRole.otherFamily =>
          CompletedBy.familyMember,
        HelperRole.professionalCaregiver || HelperRole.other => CompletedBy.caregiver,
      };

  bool get isSomeoneElse => this != HelperRole.myself;

  /// Plain English for the clinician report, which is not localised — it is
  /// written to be handed to a doctor, and the enum name ("otherFamily") is
  /// not something anyone should have to read.
  String get reportLabel => switch (this) {
        HelperRole.myself => 'Self',
        HelperRole.spouse => 'Spouse',
        HelperRole.child => 'Son or daughter',
        HelperRole.otherFamily => 'Family member',
        HelperRole.professionalCaregiver => 'Professional caregiver',
        HelperRole.other => 'Other',
      };
}

/// Years of schooling, banded. Not a social detail: education is the single
/// largest confounder in cognitive testing — it shifts expected performance on
/// every timed and language-loaded task — so the report prints it beside the
/// scores rather than the app silently adjusting anything.
enum EducationLevel {
  noFormalSchooling,
  primary,
  middle,
  secondary,
  higherSecondary,
  graduate,
  postgraduate,
  preferNotToSay,
}

// ─────────────────────────────────────────────────────────────────────────
// Part A · Q2–Q5 — health and care background
// ─────────────────────────────────────────────────────────────────────────

enum DiagnosisStatus { yes, no, notSure }

/// What a doctor has already said, in the family's words. Recorded as
/// *reported* — the app never infers, confirms or contradicts it.
enum DiagnosedCondition {
  alzheimers,
  vascular,
  lewyBody,
  frontotemporal,
  mixedOther,
  dontKnow,
  preferNotToSay,
}

extension DiagnosedConditionX on DiagnosedCondition {
  /// Conditions where visual hallucinations and marked day-to-day fluctuation
  /// are core features rather than incidental. Used only to decide whether the
  /// onboarding asks about them explicitly — never to suggest a diagnosis.
  bool get expectsPerceptualSymptoms => this == DiagnosedCondition.lewyBody;
}

enum CareProfessional {
  neurologist,
  psychiatrist,
  psychologist,
  physician,
  otherSpecialist,
  familyCaregiver,
  noRegularSupport,
}

enum TreatmentStatus { yes, no, notSure }

/// Medicine groups with a recognised anticholinergic or sedative load.
///
/// Asked in plain language rather than by drug name, because the person
/// answering knows "the tablet for sleep", not its molecule. Anticholinergic
/// burden is one of the few genuinely reversible contributors to poor
/// cognitive performance, so it is worth one question — and worth showing the
/// caregiver that it is a question for their doctor, not a reason to stop
/// anything.
enum SedatingMedicineClass {
  sleepOrAnxiety,
  allergyOrCold,
  bladder,
  olderAntidepressants,
  nauseaOrVertigo,
  noneOfThese,
}

extension SedatingMedicineClassX on SedatingMedicineClass {
  bool get countsTowardBurden => this != SedatingMedicineClass.noneOfThese;
}

// ─────────────────────────────────────────────────────────────────────────
// Part A · Q6–Q7 — what has changed in everyday life
// ─────────────────────────────────────────────────────────────────────────

/// The one broad question that replaces a symptom checklist.
///
/// Worded as things a family notices — "repeating questions", "getting lost" —
/// rather than as symptoms, because that is how the change is actually
/// experienced and described at home.
enum DailyDifficulty {
  recentConversations,
  repeatingQuestions,
  appointments,
  misplacingThings,
  timeOrPlace,
  gettingLost,
  findingWords,
  followingConversations,
  decisionsProblems,
  familiarTasks,
  managingMedicines,
  managingMoney,
  moodOrBehaviour,
  lostInterest,
  sleepChanges,
  nothingNoticed,
  somethingElse,
}

extension DailyDifficultyX on DailyDifficulty {
  /// The two answers that mean "no difficulty to explore" — selecting either
  /// suppresses the follow-ups and the "which matters most" question.
  bool get isDifficulty =>
      this != DailyDifficulty.nothingNoticed && this != DailyDifficulty.somethingElse;

  /// The symptom-catalogue item this difficulty reports into, if any.
  /// `null` means the difficulty is functional rather than symptomatic and is
  /// carried by [FunctionalAssessment] instead.
  String? get symptomItemId => switch (this) {
        DailyDifficulty.recentConversations => 'mem_conv',
        DailyDifficulty.repeatingQuestions => 'mem_repeat',
        DailyDifficulty.appointments => 'mem_appt',
        DailyDifficulty.misplacingThings => 'mem_misplace',
        DailyDifficulty.timeOrPlace => 'mem_orientation',
        DailyDifficulty.gettingLost => 'mov_wayfinding',
        DailyDifficulty.findingWords => 'lang_words',
        DailyDifficulty.followingConversations => 'att_follow',
        DailyDifficulty.decisionsProblems => 'att_solve',
        DailyDifficulty.familiarTasks => 'att_tasks',
        DailyDifficulty.managingMoney => 'att_money',
        DailyDifficulty.moodOrBehaviour => 'beh_mood',
        DailyDifficulty.lostInterest => 'beh_interest',
        DailyDifficulty.sleepChanges => 'beh_sleep',
        DailyDifficulty.managingMedicines ||
        DailyDifficulty.nothingNoticed ||
        DailyDifficulty.somethingElse =>
          null,
      };

  /// What this difficulty contributes to the presenting-concern summary.
  PresentingConcern? get presentingConcern => switch (this) {
        DailyDifficulty.recentConversations ||
        DailyDifficulty.repeatingQuestions ||
        DailyDifficulty.misplacingThings =>
          PresentingConcern.memoryProblems,
        DailyDifficulty.appointments => PresentingConcern.appointments,
        DailyDifficulty.timeOrPlace || DailyDifficulty.gettingLost =>
          PresentingConcern.confusion,
        DailyDifficulty.findingWords => PresentingConcern.wordFinding,
        DailyDifficulty.followingConversations => PresentingConcern.concentration,
        DailyDifficulty.decisionsProblems ||
        DailyDifficulty.familiarTasks ||
        DailyDifficulty.managingMedicines ||
        DailyDifficulty.managingMoney =>
          PresentingConcern.dailyTasks,
        DailyDifficulty.moodOrBehaviour ||
        DailyDifficulty.lostInterest ||
        DailyDifficulty.sleepChanges ||
        DailyDifficulty.nothingNoticed ||
        DailyDifficulty.somethingElse =>
          null,
      };

  /// Plain English for the clinician report, which is handed to a doctor and
  /// so is not localised. Phrased as an observation rather than as a symptom,
  /// because that is what it is — a family's account, not an examination.
  String get reportLabel => switch (this) {
        DailyDifficulty.recentConversations => 'Forgets recent conversations',
        DailyDifficulty.repeatingQuestions => 'Repeats questions or stories',
        DailyDifficulty.appointments => 'Forgets appointments or plans',
        DailyDifficulty.misplacingThings => 'Misplaces things',
        DailyDifficulty.timeOrPlace => 'Confused about time or place',
        DailyDifficulty.gettingLost => 'Gets lost or cannot find the way',
        DailyDifficulty.findingWords => 'Difficulty finding words',
        DailyDifficulty.followingConversations => 'Difficulty following conversations',
        DailyDifficulty.decisionsProblems => 'Difficulty with decisions and everyday problems',
        DailyDifficulty.familiarTasks => 'Difficulty completing familiar tasks',
        DailyDifficulty.managingMedicines => 'Difficulty managing medicines',
        DailyDifficulty.managingMoney => 'Difficulty managing money or bills',
        DailyDifficulty.moodOrBehaviour => 'Changes in mood or behaviour',
        DailyDifficulty.lostInterest => 'Loss of interest in usual activities',
        DailyDifficulty.sleepChanges => 'Changes in sleep',
        DailyDifficulty.nothingNoticed => 'No major difficulty noticed',
        DailyDifficulty.somethingElse => 'Something else',
      };

  /// The caregiver-corroboration item this difficulty answers, if any.
  String? get caregiverObservationId => switch (this) {
        DailyDifficulty.repeatingQuestions => 'cg_repeat',
        DailyDifficulty.appointments => 'cg_appointments',
        DailyDifficulty.managingMoney => 'cg_bills',
        DailyDifficulty.findingWords => 'cg_words',
        DailyDifficulty.gettingLost => 'cg_lost',
        DailyDifficulty.moodOrBehaviour => 'cg_personality',
        DailyDifficulty.lostInterest => 'cg_withdrawn',
        _ => null,
      };
}

// ─────────────────────────────────────────────────────────────────────────
// Part A · adaptive follow-ups
// ─────────────────────────────────────────────────────────────────────────

enum ProbeKind { single, multi }

/// One follow-up question. Ids are permanent — a stored answer is keyed by id,
/// so the wording can be improved without invalidating a record.
@immutable
class ProbeQuestion {
  const ProbeQuestion(this.id, this.kind, this.optionIds);

  final String id;
  final ProbeKind kind;
  final List<String> optionIds;

  /// Follow-ups that pin down how often something happens map straight onto
  /// the symptom scale, which is better evidence than "it was ticked".
  bool get isFrequency => id.endsWith('_often');
}

/// Which follow-ups open up for which difficulty.
///
/// Only the difficulties named in [OnboardingRecord.topDifficulties] are
/// probed, so the deepest a caregiver ever goes is three sets. The catalogue
/// covers the changes that are most often chosen as the biggest one, and a
/// difficulty with no entry here simply has no follow-up — that is a normal
/// state, not a gap to fill.
class ProbeCatalogue {
  const ProbeCatalogue._();

  static const List<String> _frequency =
      <String>['occasionally', 'sometimes', 'often', 'veryOften'];

  /// Memory probes are shared: "forgets conversations" and "repeats
  /// questions" are the same underlying observation described from two sides,
  /// and asking the same two follow-ups twice would only annoy.
  static const List<ProbeQuestion> _memory = <ProbeQuestion>[
    // How quickly something is lost separates normal ageing from the pattern
    // worth a clinical conversation far better than whether it happens at all.
    ProbeQuestion('probe_memory_span', ProbeKind.single,
        <String>['withinMinutes', 'laterSameDay', 'afterFewDays', 'varies', 'notSure']),
    // Awareness of the difficulty. Reduced insight is itself a finding, and it
    // also changes how every other answer in this record should be weighted.
    ProbeQuestion('probe_memory_awareness', ProbeKind.single,
        <String>['awareOfIt', 'partlyAware', 'notAware', 'becomesUpset', 'notSure']),
  ];

  static const Map<DailyDifficulty, List<ProbeQuestion>> byDifficulty =
      <DailyDifficulty, List<ProbeQuestion>>{
    DailyDifficulty.recentConversations: _memory,
    DailyDifficulty.repeatingQuestions: _memory,
    DailyDifficulty.misplacingThings: <ProbeQuestion>[
      ProbeQuestion('probe_misplace_what', ProbeKind.multi, <String>[
        'keys',
        'phone',
        'wallet',
        'glasses',
        'medicines',
        'documents',
        'other',
      ]),
      ProbeQuestion('probe_misplace_often', ProbeKind.single, _frequency),
      // What happens afterwards is the part that matters at home: an item
      // found calmly and an accusation of theft are the same event with very
      // different consequences for the family.
      ProbeQuestion('probe_misplace_after', ProbeKind.single, <String>[
        'findsItThemselves',
        'someoneHelps',
        'becomesWorried',
        'accusesSomeone',
        'other',
      ]),
    ],
    DailyDifficulty.gettingLost: <ProbeQuestion>[
      ProbeQuestion('probe_lost_where', ProbeKind.multi, <String>[
        'familiarRoutes',
        'unfamiliarPlaces',
        'nearHome',
        'insideTheHouse',
      ]),
      ProbeQuestion('probe_lost_often', ProbeKind.single, _frequency),
      ProbeQuestion('probe_lost_company', ProbeKind.single, <String>[
        'goesOutAlone',
        'needsSomeone',
        'noLongerGoesOut',
        'notSure',
      ]),
    ],
    DailyDifficulty.managingMedicines: <ProbeQuestion>[
      ProbeQuestion('probe_meds_what', ProbeKind.multi, <String>[
        'forgetsDoses',
        'wrongTime',
        'takesTwice',
        'refuses',
        'someoneManages',
      ]),
      ProbeQuestion('probe_meds_often', ProbeKind.single, _frequency),
    ],
    DailyDifficulty.moodOrBehaviour: <ProbeQuestion>[
      // Time-of-day pattern. Confusion and agitation that cluster in the late
      // afternoon are a recognised pattern with practical answers — light,
      // routine, activity timing — so it is worth one question.
      ProbeQuestion('probe_mood_when', ProbeKind.single, <String>[
        'lateAfternoonEvening',
        'morning',
        'whenTiredOrCrowded',
        'noPattern',
        'notSure',
      ]),
      ProbeQuestion('probe_mood_often', ProbeKind.single, _frequency),
    ],
    DailyDifficulty.familiarTasks: <ProbeQuestion>[
      ProbeQuestion('probe_tasks_which', ProbeKind.multi, <String>[
        'cooking',
        'householdAppliances',
        'dressing',
        'usingThePhone',
        'personalCare',
      ]),
      // Where the task breaks down says which part of the sequence is
      // affected, which is what the Procedure activity is later built around.
      ProbeQuestion('probe_tasks_stage', ProbeKind.single, <String>[
        'cannotStart',
        'startsThenStops',
        'stepsOutOfOrder',
        'needsPrompting',
        'notSure',
      ]),
    ],
  };

  static List<ProbeQuestion> forDifficulty(DailyDifficulty d) =>
      byDifficulty[d] ?? const <ProbeQuestion>[];

  /// Every follow-up triggered by the chosen top difficulties, de-duplicated
  /// and in the order the difficulties were chosen.
  static List<ProbeQuestion> forAll(List<DailyDifficulty> top) {
    final List<ProbeQuestion> out = <ProbeQuestion>[];
    final Set<String> seen = <String>{};
    for (final DailyDifficulty d in top) {
      for (final ProbeQuestion q in forDifficulty(d)) {
        if (seen.add(q.id)) out.add(q);
      }
    }
    return List<ProbeQuestion>.unmodifiable(out);
  }

  /// Maps a `*_often` answer onto the symptom scale.
  static SymptomFrequency? frequencyFor(String? optionId) => switch (optionId) {
        'occasionally' => SymptomFrequency.sometimes,
        'sometimes' => SymptomFrequency.sometimes,
        'often' => SymptomFrequency.often,
        'veryOften' => SymptomFrequency.veryOften,
        _ => null,
      };
}

// ─────────────────────────────────────────────────────────────────────────
// Part A · Q9 — independence and support
// ─────────────────────────────────────────────────────────────────────────

/// One screen instead of eight separate questions.
enum DailyActivity {
  eating,
  dressing,
  bathing,
  toilet,
  medicines,
  household,
  money,
  goingOut,
}

extension DailyActivityX on DailyActivity {
  /// Instrumental activities decline before basic self-care does, which is why
  /// a clinician asks about them first.
  bool get isInstrumental => switch (this) {
        DailyActivity.medicines ||
        DailyActivity.household ||
        DailyActivity.money ||
        DailyActivity.goingOut =>
          true,
        _ => false,
      };

  String get reportLabel => switch (this) {
        DailyActivity.eating => 'Eating',
        DailyActivity.dressing => 'Dressing',
        DailyActivity.bathing => 'Bathing and hygiene',
        DailyActivity.toilet => 'Using the toilet',
        DailyActivity.medicines => 'Taking medicines',
        DailyActivity.household => 'Cooking and household tasks',
        DailyActivity.money => 'Managing money and bills',
        DailyActivity.goingOut => 'Going outside and travelling',
      };

  /// The legacy [FunctionCatalogue] item this activity reports into.
  ///
  /// `eating` has no legacy equivalent and the legacy `fn_shopping` and
  /// `fn_phone` have no equivalent here — deriving them from neighbouring
  /// answers would be inventing data, so they are left unanswered and the full
  /// eight-row picture stays in this record.
  String? get functionalItemId => switch (this) {
        DailyActivity.medicines => 'fn_meds',
        DailyActivity.household => 'fn_cooking',
        DailyActivity.money => 'fn_money',
        DailyActivity.goingOut => 'fn_transport',
        DailyActivity.dressing || DailyActivity.bathing || DailyActivity.toilet =>
          'fn_bathing',
        DailyActivity.eating => null,
      };
}

/// Four levels rather than three, because "needs reminders" is the level most
/// people with early change actually sit at and collapsing it into either
/// neighbour loses the earliest functional signal there is.
enum SupportLevel { independent, needsReminders, needsSomeHelp, needsFullHelp }

extension SupportLevelX on SupportLevel {
  /// Collapsed onto the legacy three-point scale. Needing a reminder is a loss
  /// of independence, so it maps to "needs some help" rather than to
  /// "independent" — erring towards reporting a change rather than hiding one.
  FunctionLevel get functionLevel => switch (this) {
        SupportLevel.independent => FunctionLevel.independent,
        SupportLevel.needsReminders || SupportLevel.needsSomeHelp => FunctionLevel.needsHelp,
        SupportLevel.needsFullHelp => FunctionLevel.dependent,
      };

  String get reportLabel => switch (this) {
        SupportLevel.independent => 'independent',
        SupportLevel.needsReminders => 'needs reminders',
        SupportLevel.needsSomeHelp => 'needs some help',
        SupportLevel.needsFullHelp => 'needs full help',
      };

  int get score => index; // 0–3
}

// ─────────────────────────────────────────────────────────────────────────
// Part A · Q10–Q11 — mood, behaviour and safety
// ─────────────────────────────────────────────────────────────────────────

enum BehaviourChange {
  moreIrritable,
  moreWithdrawn,
  lessInterested,
  restlessAgitated,
  suspicious,
  repetitive,
  sleepChanges,
  eatingChanges,
  seeingOrHearingThings,
  noMajorChanges,
  other,
}

extension BehaviourChangeX on BehaviourChange {
  String? get symptomItemId => switch (this) {
        BehaviourChange.moreIrritable => 'beh_mood',
        BehaviourChange.moreWithdrawn || BehaviourChange.lessInterested => 'beh_interest',
        BehaviourChange.restlessAgitated => 'beh_agitation',
        BehaviourChange.suspicious => 'beh_suspicion',
        BehaviourChange.repetitive => 'mem_repeat',
        BehaviourChange.sleepChanges => 'beh_sleep',
        BehaviourChange.eatingChanges => 'beh_eating',
        BehaviourChange.seeingOrHearingThings => 'mov_halluc',
        BehaviourChange.noMajorChanges || BehaviourChange.other => null,
      };

  /// Changes that describe withdrawal or loss of interest — read together as
  /// context for a low score, never as a finding of depression.
  bool get suggestsLowMood =>
      this == BehaviourChange.moreWithdrawn || this == BehaviourChange.lessInterested;
}

enum SafetyConcern {
  gettingLostOutside,
  leavingHomeUnannounced,
  fallsOrBalance,
  forgettingMedicines,
  stoveOrAppliances,
  handlingMoney,
  travellingAlone,
  noMajorConcerns,
  other,
}

extension SafetyConcernX on SafetyConcern {
  /// The two concerns that open the "has this happened before?" follow-up and
  /// that the location and alert features are built around.
  bool get isWandering =>
      this == SafetyConcern.gettingLostOutside ||
      this == SafetyConcern.leavingHomeUnannounced;
}

enum IncidentFrequency { never, once, moreThanOnce, regularly }

// ─────────────────────────────────────────────────────────────────────────
// Part B · Q12–Q15 — knowing the person
// ─────────────────────────────────────────────────────────────────────────

enum EnjoyedActivity {
  music,
  talkingWithFamily,
  walking,
  cooking,
  gardening,
  religious,
  television,
  reading,
  puzzles,
  meetingFriends,
  householdWork,
  other,
}

extension EnjoyedActivityX on EnjoyedActivity {
  String get reportLabel => switch (this) {
        EnjoyedActivity.music => 'music',
        EnjoyedActivity.talkingWithFamily => 'talking with family',
        EnjoyedActivity.walking => 'walking',
        EnjoyedActivity.cooking => 'cooking',
        EnjoyedActivity.gardening => 'gardening',
        EnjoyedActivity.religious => 'prayer and religious activities',
        EnjoyedActivity.television => 'television or the radio',
        EnjoyedActivity.reading => 'reading',
        EnjoyedActivity.puzzles => 'puzzles and games',
        EnjoyedActivity.meetingFriends => 'meeting friends and neighbours',
        EnjoyedActivity.householdWork => 'housework and daily chores',
        EnjoyedActivity.other => 'something else',
      };
}

enum SupportGoal {
  rememberingThings,
  dailyRoutines,
  stayingMentallyActive,
  everydayDifficulties,
  confidenceIndependence,
  caregiverUnderstanding,
  trackingProgress,
  sharingWithDoctor,
  safety,
  other,
}

extension SupportGoalX on SupportGoal {
  String get reportLabel => switch (this) {
        SupportGoal.rememberingThings => 'remembering important things',
        SupportGoal.dailyRoutines => 'keeping daily routines going',
        SupportGoal.stayingMentallyActive => 'staying mentally active',
        SupportGoal.everydayDifficulties => 'managing everyday difficulties',
        SupportGoal.confidenceIndependence => 'confidence and independence',
        SupportGoal.caregiverUnderstanding => 'helping the family understand the changes',
        SupportGoal.trackingProgress => 'keeping track of change',
        SupportGoal.sharingWithDoctor => 'taking something useful to the doctor',
        SupportGoal.safety => 'safety',
        SupportGoal.other => 'something else',
      };
}

// ─────────────────────────────────────────────────────────────────────────
// The record
// ─────────────────────────────────────────────────────────────────────────

@immutable
class OnboardingRecord {
  const OnboardingRecord({
    this.helper,
    this.education,
    this.diagnosisStatus,
    this.diagnosedConditions = const <DiagnosedCondition>{},
    this.professionals = const <CareProfessional>{},
    this.treatmentStatus,
    this.medicines = const <String>[],
    this.sedatingMedicines = const <SedatingMedicineClass>{},
    this.healthConditions = const <MedicalCondition>{},
    this.difficulties = const <DailyDifficulty>{},
    this.topDifficulties = const <DailyDifficulty>[],
    this.onset,
    this.course,
    this.recentExample = '',
    this.probeAnswers = const <String, Set<String>>{},
    this.support = const <DailyActivity, SupportLevel>{},
    this.behaviourChanges = const <BehaviourChange>{},
    this.safetyConcerns = const <SafetyConcern>{},
    this.wanderingHistory,
    this.enjoys = const <EnjoyedActivity>{},
    this.stillDoesWell = '',
    this.goals = const <SupportGoal>[],
    this.anythingElse = '',
  });

  static const OnboardingRecord empty = OnboardingRecord();

  /// The most a caregiver may name as "affects daily life the most", and the
  /// most that are explored in depth. Three is the number a person can rank
  /// honestly; past that the ranking stops meaning anything.
  static const int maxTopDifficulties = 3;

  /// The most goals that can be chosen, for the same reason.
  static const int maxGoals = 3;

  // Q1
  final HelperRole? helper;
  final EducationLevel? education;

  // Q2–Q5
  final DiagnosisStatus? diagnosisStatus;
  final Set<DiagnosedCondition> diagnosedConditions;
  final Set<CareProfessional> professionals;
  final TreatmentStatus? treatmentStatus;
  final List<String> medicines;
  final Set<SedatingMedicineClass> sedatingMedicines;

  /// Other health conditions. Reuses the existing [MedicalCondition] list so
  /// the vascular-risk line already printed on the clinician report keeps
  /// having something to report.
  final Set<MedicalCondition> healthConditions;

  // Q6–Q8
  final Set<DailyDifficulty> difficulties;

  /// Ordered, at most [maxTopDifficulties]. Order is the caregiver's own
  /// ranking and is preserved — the first one named is the one to act on.
  final List<DailyDifficulty> topDifficulties;

  /// When the change was first noticed and what it has done since.
  ///
  /// Not in the fifteen questions as drafted, but a first history that cannot
  /// say *how long* and *getting worse or not* cannot be read at all: the same
  /// symptoms over three weeks and over three years are different situations
  /// with different urgencies. Two taps, on the screen where the biggest
  /// difficulties are already being named.
  final OnsetWindow? onset;
  final ProgressionPattern? course;

  /// Q8 — one concrete recent situation, in the caregiver's own words.
  /// The most informative free-text field in the whole record: a real episode
  /// carries severity, context and consequence that no checkbox does.
  final String recentExample;

  /// Follow-up question id → chosen option ids. Single-choice questions hold
  /// exactly one. Kept as ids rather than enums so a new probe needs no model
  /// change and an old stored answer never fails to parse.
  final Map<String, Set<String>> probeAnswers;

  // Q9
  final Map<DailyActivity, SupportLevel> support;

  // Q10–Q11
  final Set<BehaviourChange> behaviourChanges;
  final Set<SafetyConcern> safetyConcerns;
  final IncidentFrequency? wanderingHistory;

  // Q12–Q15
  final Set<EnjoyedActivity> enjoys;
  final String stillDoesWell;
  final List<SupportGoal> goals;
  final String anythingElse;

  // ── completeness, per screen ───────────────────────────────────────────

  bool get personDone => helper != null && education != null;

  bool get healthDone => diagnosisStatus != null && treatmentStatus != null;

  /// "Nothing noticed" is a complete answer on its own and skips the ranking.
  bool get reportsNoDifficulty =>
      difficulties.contains(DailyDifficulty.nothingNoticed) ||
      difficulties.where((DailyDifficulty d) => d.isDifficulty).isEmpty;

  bool get everydayDone {
    if (difficulties.isEmpty) return false;
    if (onset == null || course == null) return false;
    return reportsNoDifficulty || topDifficulties.isNotEmpty;
  }

  /// The follow-ups actually triggered by the chosen top difficulties.
  List<ProbeQuestion> get activeProbes => ProbeCatalogue.forAll(topDifficulties);

  bool get probesDone => activeProbes
      .every((ProbeQuestion q) => (probeAnswers[q.id] ?? const <String>{}).isNotEmpty);

  /// Q8 is offered, never demanded: a caregiver with no words to spare should
  /// not be blocked from finishing, and an example extracted under protest is
  /// not worth having.
  bool get exampleDone => true;

  bool get independenceDone => DailyActivity.values
      .every((DailyActivity a) => support.containsKey(a));

  bool get behaviourDone => behaviourChanges.isNotEmpty;

  bool get safetyDone {
    if (safetyConcerns.isEmpty) return false;
    if (safetyConcerns.any((SafetyConcern c) => c.isWandering)) {
      return wanderingHistory != null;
    }
    return true;
  }

  bool get strengthsDone => enjoys.isNotEmpty;

  bool get goalsDone => goals.isNotEmpty;

  bool get isComplete =>
      personDone &&
      healthDone &&
      everydayDone &&
      probesDone &&
      independenceDone &&
      behaviourDone &&
      safetyDone &&
      strengthsDone &&
      goalsDone;

  // ── small readers the UI and the report share ──────────────────────────

  /// Single-choice probes hold one option; this is the convenience reader.
  String? probeChoice(String questionId) {
    final Set<String> answer = probeAnswers[questionId] ?? const <String>{};
    return answer.isEmpty ? null : answer.first;
  }

  int get anticholinergicBurden =>
      sedatingMedicines.where((SedatingMedicineClass c) => c.countsTowardBurden).length;

  bool get hasWanderingRisk =>
      safetyConcerns.any((SafetyConcern c) => c.isWandering) &&
      (wanderingHistory ?? IncidentFrequency.never) != IncidentFrequency.never;

  /// Whether the onboarding should ask about hallucinations and fluctuating
  /// alertness explicitly, because a reported diagnosis makes them expected
  /// rather than incidental.
  bool get asksPerceptualSymptoms =>
      diagnosedConditions.any((DiagnosedCondition c) => c.expectsPerceptualSymptoms);

  // ── projections onto the structures the rest of the app already reads ──

  /// Reported difficulties as a symptom assessment.
  ///
  /// The mapping is deliberately coarse and stated here rather than hidden:
  /// a difficulty that was *offered and not chosen* is recorded as "never",
  /// one that was chosen as "often", and one named among the three that
  /// matter most as "very often" — unless a follow-up asked how often it
  /// actually happens, in which case that answer wins, because it is the
  /// better evidence.
  SymptomAssessment toSymptomAssessment() {
    if (difficulties.isEmpty) return const SymptomAssessment();

    final Map<String, SymptomFrequency> out = <String, SymptomFrequency>{};

    for (final DailyDifficulty d in DailyDifficulty.values.where(
        (DailyDifficulty d) => d.isDifficulty)) {
      final String? id = d.symptomItemId;
      if (id == null) continue;
      if (!difficulties.contains(d)) {
        out[id] = SymptomFrequency.never;
      } else {
        out[id] = topDifficulties.contains(d)
            ? SymptomFrequency.veryOften
            : SymptomFrequency.often;
      }
    }

    // Behaviour answers are a second pass: only ever raise a frequency, never
    // lower one already reported as a difficulty.
    if (behaviourChanges.isNotEmpty) {
      for (final BehaviourChange b in BehaviourChange.values) {
        final String? id = b.symptomItemId;
        if (id == null) continue;
        if (behaviourChanges.contains(b)) {
          final SymptomFrequency existing = out[id] ?? SymptomFrequency.never;
          if (existing.score < SymptomFrequency.often.score) {
            out[id] = SymptomFrequency.often;
          }
        } else {
          out.putIfAbsent(id, () => SymptomFrequency.never);
        }
      }
    }

    // A follow-up that pinned down a real frequency replaces the estimate.
    for (final MapEntry<DailyDifficulty, List<ProbeQuestion>> entry
        in ProbeCatalogue.byDifficulty.entries) {
      final String? id = entry.key.symptomItemId;
      if (id == null || !difficulties.contains(entry.key)) continue;
      for (final ProbeQuestion q in entry.value) {
        if (!q.isFrequency) continue;
        final SymptomFrequency? measured =
            ProbeCatalogue.frequencyFor(probeChoice(q.id));
        if (measured != null) out[id] = measured;
      }
    }

    return SymptomAssessment(responses: out);
  }

  /// Reported support needs as a functional assessment.
  ///
  /// Where several activities collapse onto one legacy item — dressing,
  /// bathing and using the toilet all report into "bathing and dressing" —
  /// the *most* help needed wins, so combining answers can never make the
  /// picture look better than any single answer did.
  FunctionalAssessment toFunctionalAssessment() {
    final Map<String, FunctionLevel> out = <String, FunctionLevel>{};

    for (final MapEntry<DailyActivity, SupportLevel> e in support.entries) {
      final String? id = e.key.functionalItemId;
      if (id == null) continue;
      final FunctionLevel mapped = e.value.functionLevel;
      final FunctionLevel? existing = out[id];
      if (existing == null || mapped.score > existing.score) out[id] = mapped;
    }

    // Keeping appointments is asked as a difficulty rather than as a support
    // level, so it is filled from there — the same observation, one screen up.
    if (difficulties.isNotEmpty) {
      out['fn_appointments'] = difficulties.contains(DailyDifficulty.appointments)
          ? FunctionLevel.needsHelp
          : FunctionLevel.independent;
    }

    return FunctionalAssessment(levels: out);
  }

  /// Reported medical context.
  ///
  /// Sleep duration is not asked, so it is left at the model's default and no
  /// number is invented; sleep *quality* is reported as poor only when a sleep
  /// change was actually named.
  MedicalHistory toMedicalHistory() {
    final bool sleepChanged = difficulties.contains(DailyDifficulty.sleepChanges) ||
        behaviourChanges.contains(BehaviourChange.sleepChanges);
    final bool withdrawn = behaviourChanges.any((BehaviourChange b) => b.suggestsLowMood) ||
        difficulties.contains(DailyDifficulty.lostInterest);

    return MedicalHistory(
      conditions: healthConditions,
      sleepQuality: sleepChanged
          ? SleepQuality.poor
          : (behaviourChanges.isEmpty ? null : SleepQuality.fair),
      lowMood: withdrawn
          ? MoodFrequency.often
          : (behaviourChanges.isEmpty
              ? null
              : (behaviourChanges.contains(BehaviourChange.moreIrritable)
                  ? MoodFrequency.sometimes
                  : MoodFrequency.never)),
      medications: medicines,
      anticholinergicBurden: anticholinergicBurden,
    );
  }

  ReasonForVisit toReasonForVisit() {
    return ReasonForVisit(
      concerns: <PresentingConcern>{
        for (final DailyDifficulty d in difficulties)
          if (d.presentingConcern != null) d.presentingConcern!,
      },
      onset: onset,
      progression: course,
    );
  }

  /// What someone else observed, when someone else answered.
  ///
  /// Returns null when the person filled it in themselves — the report's
  /// "caregiver observations" section then correctly says none was given,
  /// rather than presenting self-report as corroboration.
  CaregiverObservation? toCaregiverObservation({String caregiverName = ''}) {
    final HelperRole? role = helper;
    if (role == null || !role.isSomeoneElse) return null;
    if (difficulties.isEmpty && behaviourChanges.isEmpty) return null;

    final Map<String, bool> observed = <String, bool>{};
    if (difficulties.isNotEmpty) {
      for (final DailyDifficulty d in DailyDifficulty.values) {
        final String? id = d.caregiverObservationId;
        if (id != null) observed[id] = difficulties.contains(d);
      }
    }
    if (behaviourChanges.isNotEmpty) {
      observed['cg_halluc'] =
          behaviourChanges.contains(BehaviourChange.seeingOrHearingThings);
      if (behaviourChanges.contains(BehaviourChange.moreWithdrawn)) {
        observed['cg_withdrawn'] = true;
      }
      if (behaviourChanges.contains(BehaviourChange.suspicious) ||
          behaviourChanges.contains(BehaviourChange.moreIrritable)) {
        observed['cg_personality'] = true;
      }
    }

    return CaregiverObservation(
      caregiverName: caregiverName,
      relation: role.reportLabel,
      observations: observed,
      note: recentExample.trim(),
    );
  }

  // ── copy / json ────────────────────────────────────────────────────────

  OnboardingRecord copyWith({
    HelperRole? helper,
    EducationLevel? education,
    DiagnosisStatus? diagnosisStatus,
    Set<DiagnosedCondition>? diagnosedConditions,
    Set<CareProfessional>? professionals,
    TreatmentStatus? treatmentStatus,
    List<String>? medicines,
    Set<SedatingMedicineClass>? sedatingMedicines,
    Set<MedicalCondition>? healthConditions,
    Set<DailyDifficulty>? difficulties,
    List<DailyDifficulty>? topDifficulties,
    OnsetWindow? onset,
    ProgressionPattern? course,
    String? recentExample,
    Map<String, Set<String>>? probeAnswers,
    Map<DailyActivity, SupportLevel>? support,
    Set<BehaviourChange>? behaviourChanges,
    Set<SafetyConcern>? safetyConcerns,
    IncidentFrequency? wanderingHistory,
    Set<EnjoyedActivity>? enjoys,
    String? stillDoesWell,
    List<SupportGoal>? goals,
    String? anythingElse,
  }) {
    return OnboardingRecord(
      helper: helper ?? this.helper,
      education: education ?? this.education,
      diagnosisStatus: diagnosisStatus ?? this.diagnosisStatus,
      diagnosedConditions: diagnosedConditions ?? this.diagnosedConditions,
      professionals: professionals ?? this.professionals,
      treatmentStatus: treatmentStatus ?? this.treatmentStatus,
      medicines: medicines ?? this.medicines,
      sedatingMedicines: sedatingMedicines ?? this.sedatingMedicines,
      healthConditions: healthConditions ?? this.healthConditions,
      difficulties: difficulties ?? this.difficulties,
      topDifficulties: topDifficulties ?? this.topDifficulties,
      onset: onset ?? this.onset,
      course: course ?? this.course,
      recentExample: recentExample ?? this.recentExample,
      probeAnswers: probeAnswers ?? this.probeAnswers,
      support: support ?? this.support,
      behaviourChanges: behaviourChanges ?? this.behaviourChanges,
      safetyConcerns: safetyConcerns ?? this.safetyConcerns,
      wanderingHistory: wanderingHistory ?? this.wanderingHistory,
      enjoys: enjoys ?? this.enjoys,
      stillDoesWell: stillDoesWell ?? this.stillDoesWell,
      goals: goals ?? this.goals,
      anythingElse: anythingElse ?? this.anythingElse,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'helper': helper?.name,
        'education': education?.name,
        'diagnosisStatus': diagnosisStatus?.name,
        'diagnosedConditions':
            diagnosedConditions.map((DiagnosedCondition c) => c.name).toList(growable: false),
        'professionals':
            professionals.map((CareProfessional p) => p.name).toList(growable: false),
        'treatmentStatus': treatmentStatus?.name,
        'medicines': medicines,
        'sedatingMedicines':
            sedatingMedicines.map((SedatingMedicineClass c) => c.name).toList(growable: false),
        'healthConditions':
            healthConditions.map((MedicalCondition c) => c.name).toList(growable: false),
        'difficulties':
            difficulties.map((DailyDifficulty d) => d.name).toList(growable: false),
        'topDifficulties':
            topDifficulties.map((DailyDifficulty d) => d.name).toList(growable: false),
        'onset': onset?.name,
        'course': course?.name,
        'recentExample': recentExample,
        'probeAnswers': <String, List<String>>{
          for (final MapEntry<String, Set<String>> e in probeAnswers.entries)
            e.key: e.value.toList(growable: false),
        },
        'support': <String, String>{
          for (final MapEntry<DailyActivity, SupportLevel> e in support.entries)
            e.key.name: e.value.name,
        },
        'behaviourChanges':
            behaviourChanges.map((BehaviourChange b) => b.name).toList(growable: false),
        'safetyConcerns':
            safetyConcerns.map((SafetyConcern c) => c.name).toList(growable: false),
        'wanderingHistory': wanderingHistory?.name,
        'enjoys': enjoys.map((EnjoyedActivity e) => e.name).toList(growable: false),
        'stillDoesWell': stillDoesWell,
        'goals': goals.map((SupportGoal g) => g.name).toList(growable: false),
        'anythingElse': anythingElse,
      };

  static OnboardingRecord fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return empty;

    final Map<dynamic, dynamic> probes =
        (json['probeAnswers'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> supportRaw =
        (json['support'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};

    return OnboardingRecord(
      helper: _byName(json['helper'] as String?, HelperRole.values),
      education: _byName(json['education'] as String?, EducationLevel.values),
      diagnosisStatus: _byName(json['diagnosisStatus'] as String?, DiagnosisStatus.values),
      diagnosedConditions: _setOf(json['diagnosedConditions'], DiagnosedCondition.values),
      professionals: _setOf(json['professionals'], CareProfessional.values),
      treatmentStatus: _byName(json['treatmentStatus'] as String?, TreatmentStatus.values),
      medicines: <String>[
        for (final Object? m in (json['medicines'] as List<dynamic>?) ?? const <dynamic>[])
          m.toString(),
      ],
      sedatingMedicines: _setOf(json['sedatingMedicines'], SedatingMedicineClass.values),
      healthConditions: _setOf(json['healthConditions'], MedicalCondition.values),
      difficulties: _setOf(json['difficulties'], DailyDifficulty.values),
      topDifficulties: _listOf(json['topDifficulties'], DailyDifficulty.values),
      onset: _byName(json['onset'] as String?, OnsetWindow.values),
      course: _byName(json['course'] as String?, ProgressionPattern.values),
      recentExample: json['recentExample'] as String? ?? '',
      probeAnswers: <String, Set<String>>{
        for (final MapEntry<dynamic, dynamic> e in probes.entries)
          e.key.toString(): <String>{
            for (final Object? v in (e.value as List<dynamic>?) ?? const <dynamic>[])
              v.toString(),
          },
      },
      support: <DailyActivity, SupportLevel>{
        for (final MapEntry<dynamic, dynamic> e in supportRaw.entries)
          if (_byName(e.key.toString(), DailyActivity.values) != null &&
              _byName(e.value as String?, SupportLevel.values) != null)
            _byName(e.key.toString(), DailyActivity.values)!:
                _byName(e.value as String?, SupportLevel.values)!,
      },
      behaviourChanges: _setOf(json['behaviourChanges'], BehaviourChange.values),
      safetyConcerns: _setOf(json['safetyConcerns'], SafetyConcern.values),
      wanderingHistory:
          _byName(json['wanderingHistory'] as String?, IncidentFrequency.values),
      enjoys: _setOf(json['enjoys'], EnjoyedActivity.values),
      stillDoesWell: json['stillDoesWell'] as String? ?? '',
      goals: _listOf(json['goals'], SupportGoal.values),
      anythingElse: json['anythingElse'] as String? ?? '',
    );
  }
}

T? _byName<T extends Enum>(String? name, List<T> values) {
  if (name == null) return null;
  for (final T v in values) {
    if (v.name == name) return v;
  }
  return null;
}

Set<T> _setOf<T extends Enum>(Object? raw, List<T> values) =>
    _listOf(raw, values).toSet();

List<T> _listOf<T extends Enum>(Object? raw, List<T> values) {
  if (raw is! List<dynamic>) return <T>[];
  return <T>[
    for (final Object? item in raw)
      if (_byName(item?.toString(), values) != null) _byName(item!.toString(), values)!,
  ];
}
