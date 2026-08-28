import 'dart:math' as math;

import '../models/assessment.dart';
import '../models/clinical.dart';
import '../models/game.dart';
import '../models/monitoring.dart';

/// Turns raw sessions into the longitudinal picture the whole product is
/// built around.
///
/// Three levels, in order:
///
/// 1. **Session metrics** — accuracy, pace, errors, hints. Produced by the
///    activities themselves.
/// 2. **Domain scores** — sessions grouped by the function they exercise and
///    averaged over a recent window.
/// 3. **Longitudinal metrics** — every domain score expressed as a deviation
///    from the person's own baseline, plus consistency, adherence and the
///    observed patterns.
///
/// Pure and stateless: the same inputs always give the same snapshot, which is
/// what makes the numbers on the dashboard, in the report and in the
/// assistant's answers provably the same numbers.
class CognitiveMonitoringService {
  const CognitiveMonitoringService();

  /// How many recent sessions per domain feed the current score. Four is
  /// enough to damp a single bad day without smoothing away real change.
  static const int windowPerDomain = 4;

  /// Sessions are scored on [GamePerformance.overall] — the same figure the
  /// person sees on their result screen, so nothing is computed behind their
  /// back.
  double _score(GameSession s) => s.performance.overall.toDouble();

  /// Mean score per domain over the most recent [windowPerDomain] sessions.
  /// Domains with no sessions are absent rather than zero.
  Map<CognitiveDomain, double> domainScores(
    List<GameSession> sessions, {
    int perDomain = windowPerDomain,
    bool oldestFirst = false,
  }) {
    final Map<CognitiveDomain, List<GameSession>> buckets = _bucket(sessions);
    final Map<CognitiveDomain, double> out = <CognitiveDomain, double>{};
    for (final MapEntry<CognitiveDomain, List<GameSession>> e in buckets.entries) {
      final List<GameSession> ordered = List<GameSession>.from(e.value)
        ..sort((GameSession a, GameSession b) => oldestFirst
            ? a.dayOffset.compareTo(b.dayOffset) * -1
            : a.dayOffset.compareTo(b.dayOffset));
      final List<GameSession> window = ordered.take(perDomain).toList(growable: false);
      if (window.isEmpty) continue;
      out[e.key] =
          window.fold<double>(0, (double a, GameSession s) => a + _score(s)) / window.length;
    }
    return out;
  }

  /// The person's baseline, taken from the *first complete pass* through the
  /// activities.
  ///
  /// [fromEarliest] picks the oldest sessions in each domain, which is right
  /// for a history that begins at the baseline — the demonstration record, or
  /// a profile whose very first sessions were the baseline run.
  ///
  /// A live capture passes `false` and takes the **most recent** session per
  /// domain instead, because those are the six activities the person has just
  /// completed. Taking the oldest there would silently baseline them against
  /// whatever else happened to be in the box — including the sample history a
  /// fresh install seeds so the charts are not empty — and the person's own
  /// assessment would never appear in their own baseline.
  CognitiveBaseline buildBaseline(
    List<GameSession> sessions, {
    required DateTime at,
    int perDomain = 2,
    bool fromEarliest = true,
  }) {
    final Map<CognitiveDomain, List<GameSession>> buckets = _bucket(sessions);
    final Map<CognitiveDomain, double> scores = <CognitiveDomain, double>{};
    int used = 0;
    for (final MapEntry<CognitiveDomain, List<GameSession>> e in buckets.entries) {
      // dayOffset counts backwards: 0 is today, higher is longer ago.
      final List<GameSession> ordered = List<GameSession>.from(e.value)
        ..sort((GameSession a, GameSession b) => fromEarliest
            ? b.dayOffset.compareTo(a.dayOffset)
            : a.dayOffset.compareTo(b.dayOffset));
      final List<GameSession> window = ordered.take(perDomain).toList(growable: false);
      if (window.isEmpty) continue;
      used += window.length;
      scores[e.key] =
          window.fold<double>(0, (double a, GameSession s) => a + _score(s)) / window.length;
    }
    return CognitiveBaseline(
      scores: scores,
      capturedAtIso: at.toIso8601String(),
      sessionCount: used,
    );
  }

  /// The complete monitoring picture.
  MonitoringSnapshot snapshot({
    required List<GameSession> sessions,
    required CognitiveBaseline? baseline,
    required IntakeRecord intake,
  }) {
    if (sessions.isEmpty) {
      return MonitoringSnapshot.empty;
    }

    final Map<CognitiveDomain, List<GameSession>> buckets = _bucket(sessions);
    final Map<CognitiveDomain, double> current = domainScores(sessions);

    final List<DomainReading> readings = <DomainReading>[
      for (final CognitiveDomain domain in CognitiveDomain.values)
        DomainReading(
          domain: domain,
          current: current[domain],
          baseline: baseline?.scoreFor(domain),
          sessionCount: buckets[domain]?.length ?? 0,
          history: _history(buckets[domain] ?? const <GameSession>[]),
          averageResponseMillis: _averageResponse(buckets[domain] ?? const <GameSession>[]),
        ),
    ];

    final int spanDays = sessions
        .map((GameSession s) => s.dayOffset)
        .fold<int>(0, (int a, int b) => math.max(a, b));
    final int weeks = math.max(1, (spanDays / 7).ceil());
    final Set<int> weeksWithSessions =
        sessions.map((GameSession s) => s.dayOffset ~/ 7).toSet();

    final MonitoringSnapshot snapshot = MonitoringSnapshot(
      readings: readings,
      baseline: baseline,
      patterns: const <ObservedPattern>[],
      assessmentsCompleted: weeksWithSessions.length,
      assessmentsExpected: weeks,
      consistency: _consistency(sessions),
      functionalIndependence: intake.function.isEmpty ? 100 : intake.function.independencePercent,
      lastAssessmentDaysAgo: sessions
          .map((GameSession s) => s.dayOffset)
          .fold<int>(9999, (int a, int b) => math.min(a, b)),
      totalSessions: sessions.length,
    );

    return MonitoringSnapshot(
      readings: snapshot.readings,
      baseline: snapshot.baseline,
      patterns: patterns(intake: intake, snapshot: snapshot),
      assessmentsCompleted: snapshot.assessmentsCompleted,
      assessmentsExpected: snapshot.assessmentsExpected,
      consistency: snapshot.consistency,
      functionalIndependence: snapshot.functionalIndependence,
      lastAssessmentDaysAgo: snapshot.lastAssessmentDaysAgo,
      totalSessions: snapshot.totalSessions,
    );
  }

  /// Observed patterns.
  ///
  /// Every rule here combines *reported symptoms* with *measured change* and
  /// states which inputs it used. There is deliberately no disease
  /// probability: naming a condition would need a validated model and evidence
  /// this app does not have, and a confident wrong label in a dementia app
  /// causes real harm.
  List<ObservedPattern> patterns({
    required IntakeRecord intake,
    required MonitoringSnapshot snapshot,
  }) {
    final SymptomAssessment symptoms = intake.symptoms;
    final List<ObservedPattern> out = <ObservedPattern>[];

    // ── Memory ──────────────────────────────────────────────────────────
    final double memorySeverity = symptoms.severity(SymptomDomain.memory);
    final bool memoryDeclining = snapshot.reading(CognitiveDomain.memory)?.isDeclining ?? false;
    out.add(ObservedPattern(
      id: 'memory',
      label: 'Memory-related concerns',
      level: _band(memorySeverity, boosted: memoryDeclining),
      rationale: _rationale(<String>[
        if (memorySeverity > 0) 'reported memory symptoms at ${memorySeverity.round()}%',
        if (memoryDeclining) 'memory activity scores below personal baseline',
        if (intake.caregiver != null && intake.caregiver!.present.isNotEmpty)
          'caregiver observations recorded',
      ]),
    ));

    // ── Executive / attention ───────────────────────────────────────────
    final double execSeverity = symptoms.severity(SymptomDomain.attentionThinking);
    final bool execDeclining =
        (snapshot.reading(CognitiveDomain.procedural)?.isDeclining ?? false) ||
            (snapshot.reading(CognitiveDomain.attention)?.isDeclining ?? false);
    out.add(ObservedPattern(
      id: 'executive',
      label: 'Attention & executive concerns',
      level: _band(execSeverity, boosted: execDeclining),
      rationale: _rationale(<String>[
        if (execSeverity > 0) 'reported difficulty with planning or concentration',
        if (execDeclining) 'executive or attention activity scores below baseline',
        if (intake.function.needingHelp.isNotEmpty)
          '${intake.function.needingHelp.length} daily activities need assistance',
      ]),
    ));

    // ── Language ────────────────────────────────────────────────────────
    final double languageSeverity = symptoms.severity(SymptomDomain.language);
    final bool languageDeclining =
        snapshot.reading(CognitiveDomain.reasoning)?.isDeclining ?? false;
    out.add(ObservedPattern(
      id: 'language',
      label: 'Language concerns',
      level: _band(languageSeverity, boosted: languageDeclining),
      rationale: _rationale(<String>[
        if (languageSeverity > 0) 'reported word-finding or comprehension difficulty',
        if (languageDeclining) 'language activity scores below baseline',
      ]),
    ));

    // ── Behavioural ─────────────────────────────────────────────────────
    final double behaviourSeverity = symptoms.severity(SymptomDomain.behaviour);
    out.add(ObservedPattern(
      id: 'behaviour',
      label: 'Behavioural & personality changes',
      level: _band(behaviourSeverity),
      rationale: _rationale(<String>[
        if (behaviourSeverity > 0) 'reported changes in interest, habits or social behaviour',
        if (intake.caregiver?.observations['cg_personality'] ?? false)
          'caregiver reported a personality change',
      ]),
    ));

    // ── Vascular risk ───────────────────────────────────────────────────
    final int vascular = intake.medical.vascularRiskCount;
    out.add(ObservedPattern(
      id: 'vascular',
      label: 'Vascular risk factors',
      level: vascular == 0
          ? PatternLevel.notPresent
          : vascular >= 3
              ? PatternLevel.high
              : PatternLevel.moderate,
      rationale: vascular == 0
          ? 'No vascular risk factors were reported.'
          : 'Based on $vascular reported condition${vascular == 1 ? '' : 's'} '
              'associated with vascular risk.',
    ));

    // ── Movement & perception ───────────────────────────────────────────
    final double movementSeverity = symptoms.severity(SymptomDomain.movementPerception);
    final bool fluctuates = intake.safety.hasFluctuation;
    final bool hallucinations =
        (symptoms.responses['mov_halluc']?.score ?? 0) >= 2;
    out.add(ObservedPattern(
      id: 'movement',
      label: 'Movement & perceptual features',
      level: _band(movementSeverity, boosted: fluctuates || hallucinations),
      rationale: _rationale(<String>[
        if (movementSeverity > 0) 'reported movement or perceptual symptoms',
        if (fluctuates) 'reported fluctuating alertness',
        if (hallucinations) 'reported visual experiences of things not present',
        if (intake.medical.hasParkinsonism) "reported Parkinson's diagnosis",
      ]),
    ));

    // ── Functional impact ───────────────────────────────────────────────
    final ImpairmentBand band = intake.function.iadlImpairment;
    out.add(ObservedPattern(
      id: 'function',
      label: 'Impact on daily activities',
      level: switch (band) {
        ImpairmentBand.none => PatternLevel.notPresent,
        ImpairmentBand.mild => PatternLevel.low,
        ImpairmentBand.moderate => PatternLevel.moderate,
        ImpairmentBand.severe => PatternLevel.high,
      },
      rationale: band == ImpairmentBand.none
          ? 'All daily activities were reported as independent.'
          : 'Assistance reported with '
              '${intake.function.needingHelp.map((FunctionalItem i) => i.label.toLowerCase()).join(', ')}.',
    ));

    return out;
  }

  /// One point per week, oldest first — the shape the trend chart wants.
  ///
  /// Weeks with no sessions are skipped rather than plotted as zero: a week
  /// the person did not use the app is missing data, not a bad week, and
  /// drawing it as a collapse to zero would be a lie told by a chart.
  List<SeriesPoint> weeklySeries(
    List<GameSession> sessions, {
    CognitiveDomain? domain,
    int weeks = 12,
  }) {
    final Iterable<GameSession> pool = domain == null
        ? sessions
        : sessions.where((GameSession s) => GameDomains.of(s.gameId) == domain);

    final Map<int, List<double>> byWeek = <int, List<double>>{};
    for (final GameSession s in pool) {
      final int week = s.dayOffset ~/ 7;
      if (week >= weeks) continue;
      byWeek.putIfAbsent(week, () => <double>[]).add(_score(s));
    }
    if (byWeek.isEmpty) return const <SeriesPoint>[];

    final List<int> ordered = byWeek.keys.toList()..sort((int a, int b) => b.compareTo(a));
    return <SeriesPoint>[
      for (final int week in ordered)
        SeriesPoint(
          week == 0 ? 'Now' : '${week}w',
          byWeek[week]!.reduce((double a, double b) => a + b) / byWeek[week]!.length,
        ),
    ];
  }

  /// Factors that can move a score without any cognitive change. Surfaced
  /// whenever the app explains a result, so a bad night's sleep is never read
  /// as decline.
  List<String> contextualFactors(IntakeRecord intake) => intake.medical.reversibleContributors;

  // ── Internals ──────────────────────────────────────────────────────────

  Map<CognitiveDomain, List<GameSession>> _bucket(List<GameSession> sessions) {
    final Map<CognitiveDomain, List<GameSession>> buckets =
        <CognitiveDomain, List<GameSession>>{};
    for (final GameSession s in sessions) {
      buckets.putIfAbsent(GameDomains.of(s.gameId), () => <GameSession>[]).add(s);
    }
    return buckets;
  }

  /// Oldest first, capped so a sparkline stays readable.
  List<double> _history(List<GameSession> sessions, {int limit = 10}) {
    final List<GameSession> ordered = List<GameSession>.from(sessions)
      ..sort((GameSession a, GameSession b) => b.dayOffset.compareTo(a.dayOffset));
    final List<GameSession> window =
        ordered.length <= limit ? ordered : ordered.sublist(ordered.length - limit);
    return window.map(_score).toList(growable: false);
  }

  int _averageResponse(List<GameSession> sessions) {
    final List<int> values = <int>[
      for (final GameSession s in sessions)
        if (s.performance.responseMillis > 0) s.performance.responseMillis,
    ];
    if (values.isEmpty) return 0;
    return (values.reduce((int a, int b) => a + b) / values.length).round();
  }

  /// 100 = every session scored the same; lower = more variable. Variability
  /// is reported rather than hidden: fluctuating performance is a finding.
  int _consistency(List<GameSession> sessions) {
    if (sessions.length < 2) return 100;
    final List<double> scores = sessions.map(_score).toList(growable: false);
    final double mean = scores.reduce((double a, double b) => a + b) / scores.length;
    final double variance =
        scores.fold<double>(0, (double a, double s) => a + math.pow(s - mean, 2)) /
            scores.length;
    final double sd = math.sqrt(variance);
    return (100 - sd * 3).round().clamp(0, 100);
  }

  PatternLevel _band(double severity, {bool boosted = false}) {
    final double value = boosted ? severity + 15 : severity;
    if (value <= 8) return PatternLevel.notPresent;
    if (value < 30) return PatternLevel.low;
    if (value < 55) return PatternLevel.moderate;
    return PatternLevel.high;
  }

  String _rationale(List<String> parts) {
    if (parts.isEmpty) return 'Nothing prominent was reported or observed.';
    final String joined = parts.length == 1
        ? parts.first
        : '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
    return 'Based on $joined.';
  }
}
