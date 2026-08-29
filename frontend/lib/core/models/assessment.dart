import 'package:flutter/foundation.dart';

/// Structured intake — everything the app learns about a person *before* and
/// *around* the cognitive activities.
///
/// The activities alone are a performance sample. What makes the profile
/// clinically meaningful is the context around them: why the person came, how
/// long it has been going on, what daily life looks like now, what medical
/// history could explain a change, and what someone close to them has noticed.
///
/// Everything here serialises to plain JSON maps rather than a Hive adapter:
/// the same shape feeds local storage, the sync outbox, the AI context and the
/// clinician report, so there is exactly one representation to keep correct.
///
/// **Nothing in this file diagnoses anything.** Scores describe reported
/// symptoms and reported function, never a condition.

// ─────────────────────────────────────────────────────────────────────────
// Consent
// ─────────────────────────────────────────────────────────────────────────

@immutable
class ConsentRecord {
  const ConsentRecord({required this.understood, required this.atIso});

  /// The person confirmed they understand this is not a medical diagnosis.
  final bool understood;
  final String atIso;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'understood': understood, 'at': atIso};

  static ConsentRecord? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    return ConsentRecord(
      understood: json['understood'] as bool? ?? false,
      atIso: json['at'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Reason for using the app
// ─────────────────────────────────────────────────────────────────────────

enum PresentingConcern {
  memoryProblems,
  concentration,
  appointments,
  wordFinding,
  confusion,
  dailyTasks,
  familyNoticed,
  selfMonitoring,
  doctorRecommended,
}

extension PresentingConcernX on PresentingConcern {
  String get label => switch (this) {
        PresentingConcern.memoryProblems => 'Memory problems',
        PresentingConcern.concentration => 'Difficulty concentrating',
        PresentingConcern.appointments => 'Forgetting appointments',
        PresentingConcern.wordFinding => 'Difficulty finding words',
        PresentingConcern.confusion => 'Getting confused',
        PresentingConcern.dailyTasks => 'Difficulty managing daily tasks',
        PresentingConcern.familyNoticed => 'Family has noticed changes',
        PresentingConcern.selfMonitoring => 'I want to monitor my cognitive health',
        PresentingConcern.doctorRecommended => 'A doctor recommended monitoring',
      };

  /// Concerns that describe a *problem*, as opposed to routine monitoring.
  bool get isSymptomatic =>
      this != PresentingConcern.selfMonitoring && this != PresentingConcern.doctorRecommended;
}

enum OnsetWindow { recent, oneToSixMonths, sixToTwelveMonths, oneToTwoYears, overTwoYears, unsure }

extension OnsetWindowX on OnsetWindow {
  String get label => switch (this) {
        OnsetWindow.recent => 'Recently',
        OnsetWindow.oneToSixMonths => '1–6 months',
        OnsetWindow.sixToTwelveMonths => '6–12 months',
        OnsetWindow.oneToTwoYears => '1–2 years',
        OnsetWindow.overTwoYears => 'More than 2 years',
        OnsetWindow.unsure => "I'm not sure",
      };
}

enum ProgressionPattern { noChange, slightlyWorse, graduallyWorse, rapidlyWorse, fluctuating }

extension ProgressionPatternX on ProgressionPattern {
  String get label => switch (this) {
        ProgressionPattern.noChange => 'No change',
        ProgressionPattern.slightlyWorse => 'Slightly worse',
        ProgressionPattern.graduallyWorse => 'Gradually worse',
        ProgressionPattern.rapidlyWorse => 'Rapidly worse',
        ProgressionPattern.fluctuating => 'Comes and goes',
      };
}

@immutable
class ReasonForVisit {
  const ReasonForVisit({
    this.concerns = const <PresentingConcern>{},
    this.onset,
    this.progression,
  });

  final Set<PresentingConcern> concerns;
  final OnsetWindow? onset;
  final ProgressionPattern? progression;

  bool get isComplete => concerns.isNotEmpty && onset != null && progression != null;

  String get summary {
    if (concerns.isEmpty) return 'No concerns recorded';
    return concerns.map((PresentingConcern c) => c.label).join(', ');
  }

  ReasonForVisit copyWith({
    Set<PresentingConcern>? concerns,
    OnsetWindow? onset,
    ProgressionPattern? progression,
  }) {
    return ReasonForVisit(
      concerns: concerns ?? this.concerns,
      onset: onset ?? this.onset,
      progression: progression ?? this.progression,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'concerns': concerns.map((PresentingConcern c) => c.name).toList(growable: false),
        'onset': onset?.name,
        'progression': progression?.name,
      };

  static ReasonForVisit fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const ReasonForVisit();
    return ReasonForVisit(
      concerns: _enumSet(json['concerns'], PresentingConcern.values),
      onset: _enumByName(json['onset'] as String?, OnsetWindow.values),
      progression: _enumByName(json['progression'] as String?, ProgressionPattern.values),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Safety check — the one screen that can stop the flow
// ─────────────────────────────────────────────────────────────────────────

@immutable
class SafetyCheck {
  const SafetyCheck({this.suddenOnset, this.fluctuatingAlertness, this.neurologicalRedFlag});

  /// Started suddenly, within hours or days.
  final bool? suddenOnset;

  /// Alertness or confusion that comes and goes markedly through the day.
  final bool? fluctuatingAlertness;

  /// Sudden weakness, speech difficulty, fainting, seizure, severe headache.
  final bool? neurologicalRedFlag;

  bool get isComplete =>
      suddenOnset != null && fluctuatingAlertness != null && neurologicalRedFlag != null;

  /// Any "yes" routes to the urgent-care message rather than the assessment.
  /// This is triage framing, not a diagnosis: sudden change has many possible
  /// causes and several of them are time-critical.
  bool get requiresUrgentReview =>
      (suddenOnset ?? false) || (neurologicalRedFlag ?? false);

  bool get hasFluctuation => fluctuatingAlertness ?? false;

  SafetyCheck copyWith({bool? suddenOnset, bool? fluctuatingAlertness, bool? neurologicalRedFlag}) {
    return SafetyCheck(
      suddenOnset: suddenOnset ?? this.suddenOnset,
      fluctuatingAlertness: fluctuatingAlertness ?? this.fluctuatingAlertness,
      neurologicalRedFlag: neurologicalRedFlag ?? this.neurologicalRedFlag,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'suddenOnset': suddenOnset,
        'fluctuatingAlertness': fluctuatingAlertness,
        'neurologicalRedFlag': neurologicalRedFlag,
      };

  static SafetyCheck fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const SafetyCheck();
    return SafetyCheck(
      suddenOnset: json['suddenOnset'] as bool?,
      fluctuatingAlertness: json['fluctuatingAlertness'] as bool?,
      neurologicalRedFlag: json['neurologicalRedFlag'] as bool?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Symptom assessment
// ─────────────────────────────────────────────────────────────────────────

enum SymptomFrequency { never, sometimes, often, veryOften }

extension SymptomFrequencyX on SymptomFrequency {
  String get label => switch (this) {
        SymptomFrequency.never => 'Never',
        SymptomFrequency.sometimes => 'Sometimes',
        SymptomFrequency.often => 'Often',
        SymptomFrequency.veryOften => 'Very often',
      };

  int get score => index; // 0–3
}

/// The five symptom groups. Grouping matters: a pattern that sits mostly in
/// one group is a different picture from the same total spread evenly, and
/// clinicians read them separately.
enum SymptomDomain { memory, attentionThinking, language, behaviour, movementPerception }

extension SymptomDomainX on SymptomDomain {
  String get label => switch (this) {
        SymptomDomain.memory => 'Memory',
        SymptomDomain.attentionThinking => 'Attention & thinking',
        SymptomDomain.language => 'Language',
        SymptomDomain.behaviour => 'Behaviour & personality',
        SymptomDomain.movementPerception => 'Movement & perception',
      };

  String get prompt => switch (this) {
        SymptomDomain.memory => 'How often do you…',
        SymptomDomain.attentionThinking => 'Do you have difficulty…',
        SymptomDomain.language => 'Do you experience…',
        SymptomDomain.behaviour => 'Have you or your family noticed…',
        SymptomDomain.movementPerception => 'Have you experienced…',
      };
}

@immutable
class SymptomItem {
  const SymptomItem(this.id, this.domain, this.text);
  final String id;
  final SymptomDomain domain;
  final String text;
}

/// The item bank. Ids are permanent — a stored answer is keyed by id, so
/// wording can be improved without invalidating history.
class SymptomCatalogue {
  const SymptomCatalogue._();

  static const List<SymptomItem> items = <SymptomItem>[
    // Memory
    SymptomItem('mem_repeat', SymptomDomain.memory, 'Repeat the same questions'),
    SymptomItem('mem_conv', SymptomDomain.memory, 'Forget recent conversations'),
    SymptomItem('mem_appt', SymptomDomain.memory, 'Forget appointments'),
    SymptomItem('mem_misplace', SymptomDomain.memory, 'Misplace things'),
    SymptomItem('mem_new', SymptomDomain.memory, 'Forget newly learned information'),
    // Attention & thinking
    SymptomItem('att_concentrate', SymptomDomain.attentionThinking, 'Concentrating'),
    SymptomItem('att_follow', SymptomDomain.attentionThinking, 'Following conversations'),
    SymptomItem('att_plan', SymptomDomain.attentionThinking, 'Planning tasks'),
    SymptomItem('att_money', SymptomDomain.attentionThinking, 'Managing money'),
    SymptomItem('att_solve', SymptomDomain.attentionThinking, 'Solving familiar problems'),
    // Language
    SymptomItem('lang_words', SymptomDomain.language, 'Difficulty finding words'),
    SymptomItem('lang_naming', SymptomDomain.language, 'Difficulty naming objects'),
    SymptomItem('lang_understand', SymptomDomain.language, 'Difficulty understanding conversations'),
    // Behaviour & personality
    SymptomItem('beh_interest', SymptomDomain.behaviour, 'Loss of interest in usual activities'),
    SymptomItem('beh_impulsive', SymptomDomain.behaviour, 'Impulsive behaviour'),
    SymptomItem('beh_social', SymptomDomain.behaviour, 'Socially unusual behaviour'),
    SymptomItem('beh_eating', SymptomDomain.behaviour, 'Changes in eating habits'),
    // Movement & perception
    SymptomItem('mov_tremor', SymptomDomain.movementPerception, 'Tremor'),
    SymptomItem('mov_stiff', SymptomDomain.movementPerception, 'Stiffness'),
    SymptomItem('mov_balance', SymptomDomain.movementPerception, 'Balance problems'),
    SymptomItem('mov_halluc', SymptomDomain.movementPerception, 'Seeing things that are not there'),
    SymptomItem('mov_alert', SymptomDomain.movementPerception, 'Large changes in alertness'),
    SymptomItem('mov_dreams', SymptomDomain.movementPerception, 'Acting out dreams while asleep'),
  ];

  static List<SymptomItem> of(SymptomDomain domain) =>
      items.where((SymptomItem i) => i.domain == domain).toList(growable: false);
}

@immutable
class SymptomAssessment {
  const SymptomAssessment({this.responses = const <String, SymptomFrequency>{}});

  /// item id → reported frequency.
  final Map<String, SymptomFrequency> responses;

  bool get isEmpty => responses.isEmpty;

  int get answeredCount => responses.length;

  bool isDomainComplete(SymptomDomain domain) =>
      SymptomCatalogue.of(domain).every((SymptomItem i) => responses.containsKey(i.id));

  bool get isComplete => SymptomDomain.values.every(isDomainComplete);

  /// 0–100 reported-severity for one group. Not a score of the person: a
  /// higher number means more symptoms were reported more often, nothing more.
  double severity(SymptomDomain domain) {
    final List<SymptomItem> group = SymptomCatalogue.of(domain);
    final List<int> scores = <int>[
      for (final SymptomItem i in group)
        if (responses.containsKey(i.id)) responses[i.id]!.score,
    ];
    if (scores.isEmpty) return 0;
    final double mean = scores.reduce((int a, int b) => a + b) / scores.length;
    return (mean / 3 * 100).clamp(0, 100);
  }

  double get overallSeverity {
    final List<double> all =
        SymptomDomain.values.map(severity).toList(growable: false);
    return all.reduce((double a, double b) => a + b) / all.length;
  }

  /// Items reported at "often" or above — what a clinician reads first.
  List<SymptomItem> get prominent => SymptomCatalogue.items
      .where((SymptomItem i) => (responses[i.id]?.score ?? 0) >= 2)
      .toList(growable: false);

  SymptomAssessment withResponse(String itemId, SymptomFrequency frequency) {
    return SymptomAssessment(responses: <String, SymptomFrequency>{
      ...responses,
      itemId: frequency,
    });
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'responses': <String, String>{
          for (final MapEntry<String, SymptomFrequency> e in responses.entries)
            e.key: e.value.name,
        },
      };

  static SymptomAssessment fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const SymptomAssessment();
    final Map<dynamic, dynamic> raw =
        (json['responses'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return SymptomAssessment(responses: <String, SymptomFrequency>{
      for (final MapEntry<dynamic, dynamic> e in raw.entries)
        if (_enumByName(e.value as String?, SymptomFrequency.values) != null)
          e.key as String: _enumByName(e.value as String?, SymptomFrequency.values)!,
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Daily function
// ─────────────────────────────────────────────────────────────────────────

enum FunctionLevel { independent, needsHelp, dependent }

extension FunctionLevelX on FunctionLevel {
  String get label => switch (this) {
        FunctionLevel.independent => 'Independent',
        FunctionLevel.needsHelp => 'Needs some help',
        FunctionLevel.dependent => 'Needs full help',
      };

  String get shortLabel => switch (this) {
        FunctionLevel.independent => 'Independent',
        FunctionLevel.needsHelp => 'Some help',
        FunctionLevel.dependent => 'Full help',
      };

  int get score => index; // 0–2
}

@immutable
class FunctionalItem {
  const FunctionalItem(this.id, this.label, {this.instrumental = true});
  final String id;
  final String label;

  /// Instrumental activities of daily living (managing money, medication,
  /// transport…) change before basic self-care does, which is why they are
  /// reported separately.
  final bool instrumental;
}

class FunctionCatalogue {
  const FunctionCatalogue._();

  static const List<FunctionalItem> items = <FunctionalItem>[
    FunctionalItem('fn_money', 'Managing money and bills'),
    FunctionalItem('fn_meds', 'Taking medication on time'),
    FunctionalItem('fn_cooking', 'Cooking and preparing meals'),
    FunctionalItem('fn_shopping', 'Shopping'),
    FunctionalItem('fn_phone', 'Using the phone'),
    FunctionalItem('fn_transport', 'Travelling outside the home'),
    FunctionalItem('fn_appointments', 'Keeping appointments'),
    FunctionalItem('fn_bathing', 'Bathing and dressing', instrumental: false),
  ];
}

enum ImpairmentBand { none, mild, moderate, severe }

extension ImpairmentBandX on ImpairmentBand {
  String get label => switch (this) {
        ImpairmentBand.none => 'None reported',
        ImpairmentBand.mild => 'Mild',
        ImpairmentBand.moderate => 'Moderate',
        ImpairmentBand.severe => 'Substantial',
      };
}

@immutable
class FunctionalAssessment {
  const FunctionalAssessment({this.levels = const <String, FunctionLevel>{}});

  final Map<String, FunctionLevel> levels;

  bool get isEmpty => levels.isEmpty;

  bool get isComplete =>
      FunctionCatalogue.items.every((FunctionalItem i) => levels.containsKey(i.id));

  /// 100 = fully independent across everything reported.
  int get independencePercent {
    if (levels.isEmpty) return 100;
    final double mean = levels.values.fold<int>(0, (int a, FunctionLevel l) => a + l.score) /
        levels.length;
    return (100 - (mean / 2 * 100)).round().clamp(0, 100);
  }

  List<FunctionalItem> get needingHelp => FunctionCatalogue.items
      .where((FunctionalItem i) => (levels[i.id] ?? FunctionLevel.independent) != FunctionLevel.independent)
      .toList(growable: false);

  /// Banded from the instrumental activities only — a change there is the
  /// earliest functional signal and the one a clinician asks about first.
  ImpairmentBand get iadlImpairment {
    final List<FunctionalItem> iadl =
        FunctionCatalogue.items.where((FunctionalItem i) => i.instrumental).toList();
    final int affected = iadl
        .where((FunctionalItem i) =>
            (levels[i.id] ?? FunctionLevel.independent) != FunctionLevel.independent)
        .length;
    if (affected == 0) return ImpairmentBand.none;
    if (affected <= 2) return ImpairmentBand.mild;
    if (affected <= 4) return ImpairmentBand.moderate;
    return ImpairmentBand.severe;
  }

  FunctionalAssessment withLevel(String itemId, FunctionLevel level) {
    return FunctionalAssessment(levels: <String, FunctionLevel>{...levels, itemId: level});
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'levels': <String, String>{
          for (final MapEntry<String, FunctionLevel> e in levels.entries) e.key: e.value.name,
        },
      };

  static FunctionalAssessment fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const FunctionalAssessment();
    final Map<dynamic, dynamic> raw =
        (json['levels'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return FunctionalAssessment(levels: <String, FunctionLevel>{
      for (final MapEntry<dynamic, dynamic> e in raw.entries)
        if (_enumByName(e.value as String?, FunctionLevel.values) != null)
          e.key as String: _enumByName(e.value as String?, FunctionLevel.values)!,
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Medical and lifestyle context
// ─────────────────────────────────────────────────────────────────────────

enum MedicalCondition {
  hypertension,
  diabetes,
  highCholesterol,
  strokeOrTia,
  parkinsons,
  thyroid,
  headInjury,
  otherNeurological,
}

extension MedicalConditionX on MedicalCondition {
  String get label => switch (this) {
        MedicalCondition.hypertension => 'High blood pressure',
        MedicalCondition.diabetes => 'Diabetes',
        MedicalCondition.highCholesterol => 'High cholesterol',
        MedicalCondition.strokeOrTia => 'Previous stroke or TIA',
        MedicalCondition.parkinsons => "Parkinson's disease",
        MedicalCondition.thyroid => 'Thyroid condition',
        MedicalCondition.headInjury => 'Previous head injury',
        MedicalCondition.otherNeurological => 'Other neurological condition',
      };

  /// Conditions that are recognised contributors to vascular risk. Reported
  /// here as *risk factors present*, never as a cause of anything observed.
  bool get isVascularRisk => switch (this) {
        MedicalCondition.hypertension ||
        MedicalCondition.diabetes ||
        MedicalCondition.highCholesterol ||
        MedicalCondition.strokeOrTia =>
          true,
        _ => false,
      };
}

enum SleepQuality { good, fair, poor }

extension SleepQualityX on SleepQuality {
  String get label => switch (this) {
        SleepQuality.good => 'Good',
        SleepQuality.fair => 'Fair',
        SleepQuality.poor => 'Poor',
      };
}

enum MoodFrequency { never, sometimes, often }

extension MoodFrequencyX on MoodFrequency {
  String get label => switch (this) {
        MoodFrequency.never => 'Never',
        MoodFrequency.sometimes => 'Sometimes',
        MoodFrequency.often => 'Often',
      };
}

@immutable
class MedicalHistory {
  const MedicalHistory({
    this.conditions = const <MedicalCondition>{},
    this.sleepHours = 7,
    this.sleepQuality,
    this.lowMood,
    this.medications = const <String>[],
  });

  final Set<MedicalCondition> conditions;
  final double sleepHours;
  final SleepQuality? sleepQuality;

  /// How often the person has felt persistently sad or lost interest lately.
  /// Low mood affects cognitive performance, so it is recorded as context for
  /// reading a score — not as a finding of its own.
  final MoodFrequency? lowMood;
  final List<String> medications;

  bool get isComplete => sleepQuality != null && lowMood != null;

  int get vascularRiskCount =>
      conditions.where((MedicalCondition c) => c.isVascularRisk).length;

  bool get hasParkinsonism => conditions.contains(MedicalCondition.parkinsons);

  /// Factors that can depress performance independently of any cognitive
  /// change — surfaced whenever a score is explained.
  List<String> get reversibleContributors => <String>[
        if (sleepQuality == SleepQuality.poor) 'poor sleep quality',
        if (sleepHours < 6) 'short sleep duration',
        if (lowMood == MoodFrequency.often) 'frequently low mood',
        if (conditions.contains(MedicalCondition.thyroid)) 'a thyroid condition',
        if (medications.length >= 4) 'several concurrent medications',
      ];

  MedicalHistory copyWith({
    Set<MedicalCondition>? conditions,
    double? sleepHours,
    SleepQuality? sleepQuality,
    MoodFrequency? lowMood,
    List<String>? medications,
  }) {
    return MedicalHistory(
      conditions: conditions ?? this.conditions,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      lowMood: lowMood ?? this.lowMood,
      medications: medications ?? this.medications,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'conditions': conditions.map((MedicalCondition c) => c.name).toList(growable: false),
        'sleepHours': sleepHours,
        'sleepQuality': sleepQuality?.name,
        'lowMood': lowMood?.name,
        'medications': medications,
      };

  static MedicalHistory fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const MedicalHistory();
    return MedicalHistory(
      conditions: _enumSet(json['conditions'], MedicalCondition.values),
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 7,
      sleepQuality: _enumByName(json['sleepQuality'] as String?, SleepQuality.values),
      lowMood: _enumByName(json['lowMood'] as String?, MoodFrequency.values),
      medications: <String>[
        for (final Object? m in (json['medications'] as List<dynamic>?) ?? const <dynamic>[])
          m.toString(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Caregiver corroboration
// ─────────────────────────────────────────────────────────────────────────

/// What someone close to the person has observed. A second, independent
/// perspective is one of the most informative things in this whole intake:
/// people with cognitive change frequently under-report it, and the person
/// living with them frequently does not.
@immutable
class CaregiverObservation {
  const CaregiverObservation({
    required this.caregiverName,
    required this.relation,
    this.observations = const <String, bool>{},
    this.note = '',
    this.receivedAtIso = '',
  });

  final String caregiverName;
  final String relation;

  /// observation id → observed in the last 3 months.
  final Map<String, bool> observations;
  final String note;
  final String receivedAtIso;

  static const List<({String id, String label})> catalogue = <({String id, String label})>[
    (id: 'cg_repeat', label: 'Repeats questions'),
    (id: 'cg_appointments', label: 'Has forgotten appointments'),
    (id: 'cg_bills', label: 'Difficulty managing bills'),
    (id: 'cg_words', label: 'Struggles to find words'),
    (id: 'cg_lost', label: 'Became disoriented in a familiar place'),
    (id: 'cg_personality', label: 'Noticeable personality change'),
    (id: 'cg_halluc', label: 'Reported seeing things that were not there'),
    (id: 'cg_withdrawn', label: 'Withdrawn from usual activities'),
  ];

  List<String> get present => <String>[
        for (final ({String id, String label}) o in catalogue)
          if (observations[o.id] ?? false) o.label,
      ];

  List<String> get absent => <String>[
        for (final ({String id, String label}) o in catalogue)
          if (observations.containsKey(o.id) && !(observations[o.id] ?? false)) o.label,
      ];

  int get concernCount => present.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'caregiverName': caregiverName,
        'relation': relation,
        'observations': observations,
        'note': note,
        'receivedAt': receivedAtIso,
      };

  static CaregiverObservation? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final Map<dynamic, dynamic> raw =
        (json['observations'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return CaregiverObservation(
      caregiverName: json['caregiverName'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
      observations: <String, bool>{
        for (final MapEntry<dynamic, dynamic> e in raw.entries)
          e.key as String: e.value as bool? ?? false,
      },
      note: json['note'] as String? ?? '',
      receivedAtIso: json['receivedAt'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// The intake as a whole
// ─────────────────────────────────────────────────────────────────────────

/// Which step of the intake the person is on. The flow is resumable: a
/// half-finished intake is written after every step, so closing the app
/// mid-questionnaire loses nothing.
enum IntakeStep {
  consent,
  profile,
  reason,
  safety,
  symptoms,
  function,
  medical,
  caregiver,
  baseline,
  done,
}

extension IntakeStepX on IntakeStep {
  String get title => switch (this) {
        IntakeStep.consent => 'Consent & privacy',
        IntakeStep.profile => 'About you',
        IntakeStep.reason => 'Your concerns',
        IntakeStep.safety => 'Safety check',
        IntakeStep.symptoms => 'Symptom assessment',
        IntakeStep.function => 'Daily function',
        IntakeStep.medical => 'Medical history',
        IntakeStep.caregiver => 'Caregiver input',
        IntakeStep.baseline => 'Baseline assessment',
        IntakeStep.done => 'Complete',
      };
}

enum CompletedBy { patient, caregiver, familyMember, clinician }

extension CompletedByX on CompletedBy {
  String get label => switch (this) {
        CompletedBy.patient => 'The person themselves',
        CompletedBy.caregiver => 'A caregiver',
        CompletedBy.familyMember => 'A family member',
        CompletedBy.clinician => 'A health worker',
      };
}

/// Common professions in the region, offered as quick picks.
///
/// Not an exhaustive list and not stored as an enum — what someone did for a
/// living is free text, because it also feeds the activities themselves (a
/// weaver gets loom procedures, a teacher gets classroom ones), and a fixed
/// list would quietly flatten that.
class ProfessionSuggestions {
  const ProfessionSuggestions._();

  static const List<String> common = <String>[
    'Farmer',
    'Weaver',
    'Teacher',
    'Homemaker',
    'Shopkeeper',
    'Government service',
    'Driver',
    'Retired',
  ];
}

@immutable
class IntakeRecord {
  const IntakeRecord({
    this.consent,
    this.completedBy,
    this.reason = const ReasonForVisit(),
    this.safety = const SafetyCheck(),
    this.symptoms = const SymptomAssessment(),
    this.function = const FunctionalAssessment(),
    this.medical = const MedicalHistory(),
    this.caregiver,
    this.baselineActivities = const <String>{},
    this.baselineSessionDates = const <String>{},
    this.accountId,
    this.startedAtIso = '',
    this.completedAtIso,
  });

  final ConsentRecord? consent;

  /// Who filled the questionnaire in. A caregiver's account of someone else's
  /// symptoms reads differently from that person's own, and the report says
  /// which it is.
  final CompletedBy? completedBy;

  final ReasonForVisit reason;
  final SafetyCheck safety;
  final SymptomAssessment symptoms;
  final FunctionalAssessment function;
  final MedicalHistory medical;
  final CaregiverObservation? caregiver;

  /// Activity ids ([GameId.name]) already completed during the baseline run.
  /// Tracked here so a baseline interrupted half way — the phone locks, the
  /// person needs a break — resumes where it stopped instead of restarting.
  final Set<String> baselineActivities;

  /// The calendar days (`yyyy-mm-dd`) on which a baseline session was finished.
  ///
  /// The baseline is deliberately spread over three days, two activities each.
  /// One long sitting measures stamina as much as cognition; three short ones
  /// on separate days average out a bad night's sleep, and they also teach the
  /// daily habit the rest of the product depends on.
  final Set<String> baselineSessionDates;

  /// The Firebase uid this assessment belongs to, stamped when the person
  /// signs in. Carried into the sync payload and the report so an answer can
  /// always be attributed to the account that gave it — two people sharing a
  /// device get two separate records, not one merged one.
  final String? accountId;

  final String startedAtIso;
  final String? completedAtIso;

  static const IntakeRecord empty = IntakeRecord();

  bool get consentGiven => consent?.understood ?? false;

  bool get isComplete => completedAtIso != null;

  /// The first step that still needs answering — where "Continue" resumes.
  IntakeStep get nextStep {
    if (!consentGiven) return IntakeStep.consent;
    if (completedBy == null) return IntakeStep.profile;
    if (!reason.isComplete) return IntakeStep.reason;
    if (!safety.isComplete) return IntakeStep.safety;
    if (!symptoms.isComplete) return IntakeStep.symptoms;
    if (!function.isComplete) return IntakeStep.function;
    if (!medical.isComplete) return IntakeStep.medical;
    return IntakeStep.baseline;
  }

  double get progress {
    const List<IntakeStep> ordered = <IntakeStep>[
      IntakeStep.consent,
      IntakeStep.profile,
      IntakeStep.reason,
      IntakeStep.safety,
      IntakeStep.symptoms,
      IntakeStep.function,
      IntakeStep.medical,
      IntakeStep.baseline,
    ];
    final int index = ordered.indexOf(nextStep);
    if (index < 0) return 1;
    return index / ordered.length;
  }

  IntakeRecord copyWith({
    ConsentRecord? consent,
    CompletedBy? completedBy,
    ReasonForVisit? reason,
    SafetyCheck? safety,
    SymptomAssessment? symptoms,
    FunctionalAssessment? function,
    MedicalHistory? medical,
    CaregiverObservation? caregiver,
    Set<String>? baselineActivities,
    Set<String>? baselineSessionDates,
    String? accountId,
    String? startedAtIso,
    String? completedAtIso,
  }) {
    return IntakeRecord(
      consent: consent ?? this.consent,
      completedBy: completedBy ?? this.completedBy,
      reason: reason ?? this.reason,
      safety: safety ?? this.safety,
      symptoms: symptoms ?? this.symptoms,
      function: function ?? this.function,
      medical: medical ?? this.medical,
      caregiver: caregiver ?? this.caregiver,
      baselineActivities: baselineActivities ?? this.baselineActivities,
      baselineSessionDates: baselineSessionDates ?? this.baselineSessionDates,
      accountId: accountId ?? this.accountId,
      startedAtIso: startedAtIso ?? this.startedAtIso,
      completedAtIso: completedAtIso ?? this.completedAtIso,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'consent': consent?.toJson(),
        'completedBy': completedBy?.name,
        'reason': reason.toJson(),
        'safety': safety.toJson(),
        'symptoms': symptoms.toJson(),
        'function': function.toJson(),
        'medical': medical.toJson(),
        'caregiver': caregiver?.toJson(),
        'baselineActivities': baselineActivities.toList(growable: false),
        'baselineSessionDates': baselineSessionDates.toList(growable: false),
        'accountId': accountId,
        'startedAt': startedAtIso,
        'completedAt': completedAtIso,
      };

  static IntakeRecord fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return empty;
    return IntakeRecord(
      consent: ConsentRecord.fromJson(json['consent'] as Map<dynamic, dynamic>?),
      completedBy: _enumByName(json['completedBy'] as String?, CompletedBy.values),
      reason: ReasonForVisit.fromJson(json['reason'] as Map<dynamic, dynamic>?),
      safety: SafetyCheck.fromJson(json['safety'] as Map<dynamic, dynamic>?),
      symptoms: SymptomAssessment.fromJson(json['symptoms'] as Map<dynamic, dynamic>?),
      function: FunctionalAssessment.fromJson(json['function'] as Map<dynamic, dynamic>?),
      medical: MedicalHistory.fromJson(json['medical'] as Map<dynamic, dynamic>?),
      caregiver: CaregiverObservation.fromJson(json['caregiver'] as Map<dynamic, dynamic>?),
      baselineActivities: <String>{
        for (final Object? a in (json['baselineActivities'] as List<dynamic>?) ?? const <dynamic>[])
          a.toString(),
      },
      baselineSessionDates: <String>{
        for (final Object? d in (json['baselineSessionDates'] as List<dynamic>?) ?? const <dynamic>[])
          d.toString(),
      },
      accountId: json['accountId'] as String?,
      startedAtIso: json['startedAt'] as String? ?? '',
      completedAtIso: json['completedAt'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared JSON helpers
// ─────────────────────────────────────────────────────────────────────────

T? _enumByName<T extends Enum>(String? name, List<T> values) {
  if (name == null) return null;
  for (final T v in values) {
    if (v.name == name) return v;
  }
  return null;
}

Set<T> _enumSet<T extends Enum>(Object? raw, List<T> values) {
  if (raw is! List<dynamic>) return <T>{};
  return <T>{
    for (final Object? item in raw)
      if (_enumByName(item?.toString(), values) != null) _enumByName(item!.toString(), values)!,
  };
}
