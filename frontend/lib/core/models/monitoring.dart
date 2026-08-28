import 'package:flutter/foundation.dart';

import 'clinical.dart';
import 'game.dart';

/// Longitudinal monitoring: the part of the product that a single test cannot
/// give you.
///
/// One score on one day says very little — practice, sleep, mood, a noisy room
/// and the weather all move it. What carries information is the same person
/// measured repeatedly against *their own* first result. Everything in this
/// file is expressed as a deviation from that personal baseline.

/// The person's own reference point: the domain scores from their first
/// complete assessment. Every later reading is compared against this rather
/// than against a population norm, because the app has no normative data and
/// pretending otherwise would be dishonest.
@immutable
class CognitiveBaseline {
  const CognitiveBaseline({
    required this.scores,
    required this.capturedAtIso,
    required this.sessionCount,
  });

  final Map<CognitiveDomain, double> scores;
  final String capturedAtIso;

  /// How many sessions the baseline was averaged over. A baseline from six
  /// sessions is worth more than one from two, and the report says which.
  final int sessionCount;

  double? scoreFor(CognitiveDomain domain) => scores[domain];

  double get overall => scores.isEmpty
      ? 0
      : scores.values.reduce((double a, double b) => a + b) / scores.length;

  DateTime? get capturedAt => DateTime.tryParse(capturedAtIso);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scores': <String, double>{
          for (final MapEntry<CognitiveDomain, double> e in scores.entries) e.key.name: e.value,
        },
        'capturedAt': capturedAtIso,
        'sessionCount': sessionCount,
      };

  static CognitiveBaseline? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final Map<dynamic, dynamic> raw =
        (json['scores'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final Map<CognitiveDomain, double> scores = <CognitiveDomain, double>{};
    for (final MapEntry<dynamic, dynamic> e in raw.entries) {
      for (final CognitiveDomain d in CognitiveDomain.values) {
        if (d.name == e.key) scores[d] = (e.value as num).toDouble();
      }
    }
    if (scores.isEmpty) return null;
    return CognitiveBaseline(
      scores: scores,
      capturedAtIso: json['capturedAt'] as String? ?? '',
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One domain, now versus baseline.
@immutable
class DomainReading {
  const DomainReading({
    required this.domain,
    required this.current,
    required this.baseline,
    required this.sessionCount,
    required this.history,
    this.averageResponseMillis = 0,
  });

  final CognitiveDomain domain;

  /// Mean of the recent window, 0–100. Null when the domain has never been
  /// played — shown as "not yet assessed" rather than as a zero.
  final double? current;
  final double? baseline;
  final int sessionCount;

  /// Oldest first, one point per session in the window — feeds the sparkline.
  final List<double> history;

  final int averageResponseMillis;

  bool get hasReading => current != null;

  /// Change from the person's own baseline, in points.
  double? get delta =>
      (current == null || baseline == null) ? null : current! - baseline!;

  /// A change smaller than this is treated as noise, not as movement. Set at
  /// five points because repeated sessions of the same activity routinely vary
  /// by that much for reasons that have nothing to do with cognition.
  static const double meaningfulChange = 5;

  TrendDirection get trend {
    final double? d = delta;
    if (d == null) return TrendDirection.flat;
    if (d >= meaningfulChange) return TrendDirection.up;
    if (d <= -meaningfulChange) return TrendDirection.down;
    return TrendDirection.flat;
  }

  /// True when this domain has moved down beyond the noise floor.
  bool get isDeclining => trend == TrendDirection.down;

  String get deltaLabel {
    final double? d = delta;
    if (d == null) return 'No baseline yet';
    if (d.abs() < meaningfulChange) return 'Within normal variation';
    final String sign = d > 0 ? '+' : '';
    return '$sign${d.round()} points vs baseline';
  }
}

/// How prominent a group of findings is. Deliberately a *pattern* vocabulary
/// rather than a disease vocabulary: the app reports what it observed, and a
/// clinician decides what it means.
enum PatternLevel { notPresent, low, moderate, high }

extension PatternLevelX on PatternLevel {
  String get label => switch (this) {
        PatternLevel.notPresent => 'Not prominent',
        PatternLevel.low => 'Low',
        PatternLevel.moderate => 'Moderate',
        PatternLevel.high => 'High',
      };
}

/// One observed pattern, with the reasoning that produced it. The reasoning is
/// always shown — an unexplained label in a health app is worse than no label.
@immutable
class ObservedPattern {
  const ObservedPattern({
    required this.id,
    required this.label,
    required this.level,
    required this.rationale,
  });

  final String id;
  final String label;
  final PatternLevel level;
  final String rationale;
}

/// Everything the dashboard, the trends screen, the assistant and the report
/// read from. Computed, never stored — recomputing from sessions keeps it
/// impossible for a cached figure to disagree with the history behind it.
@immutable
class MonitoringSnapshot {
  const MonitoringSnapshot({
    required this.readings,
    required this.baseline,
    required this.patterns,
    required this.assessmentsCompleted,
    required this.assessmentsExpected,
    required this.consistency,
    required this.functionalIndependence,
    required this.lastAssessmentDaysAgo,
    required this.totalSessions,
  });

  final List<DomainReading> readings;
  final CognitiveBaseline? baseline;
  final List<ObservedPattern> patterns;

  /// Weekly assessment adherence over the monitoring period.
  final int assessmentsCompleted;
  final int assessmentsExpected;

  /// 0–100. How stable performance has been session to session; high
  /// variability is itself worth reporting, and is common in some conditions.
  final int consistency;

  final int functionalIndependence;
  final int? lastAssessmentDaysAgo;
  final int totalSessions;

  static const MonitoringSnapshot empty = MonitoringSnapshot(
    readings: <DomainReading>[],
    baseline: null,
    patterns: <ObservedPattern>[],
    assessmentsCompleted: 0,
    assessmentsExpected: 0,
    consistency: 0,
    functionalIndependence: 100,
    lastAssessmentDaysAgo: null,
    totalSessions: 0,
  );

  bool get hasBaseline => baseline != null;

  DomainReading? reading(CognitiveDomain domain) {
    for (final DomainReading r in readings) {
      if (r.domain == domain) return r;
    }
    return null;
  }

  List<DomainReading> get assessed =>
      readings.where((DomainReading r) => r.hasReading).toList(growable: false);

  double? get overallCurrent {
    final List<DomainReading> list = assessed;
    if (list.isEmpty) return null;
    return list.fold<double>(0, (double a, DomainReading r) => a + r.current!) / list.length;
  }

  double? get overallBaseline => baseline?.overall;

  double? get overallDelta => (overallCurrent == null || overallBaseline == null)
      ? null
      : overallCurrent! - overallBaseline!;

  TrendDirection get overallTrend {
    final double? d = overallDelta;
    if (d == null) return TrendDirection.flat;
    if (d >= DomainReading.meaningfulChange) return TrendDirection.up;
    if (d <= -DomainReading.meaningfulChange) return TrendDirection.down;
    return TrendDirection.flat;
  }

  List<DomainReading> get declining =>
      readings.where((DomainReading r) => r.isDeclining).toList(growable: false);

  int get adherencePercent => assessmentsExpected == 0
      ? 0
      : ((assessmentsCompleted / assessmentsExpected) * 100).round().clamp(0, 100);

  /// The single sentence the dashboard leads with. Describes change, states
  /// plainly that it is not a diagnosis, and never names a condition.
  String get headline {
    if (!hasBaseline) {
      return 'Complete your first assessment to establish a personal baseline.';
    }
    final List<DomainReading> down = declining;
    if (down.isEmpty) {
      return 'Your recent results are consistent with your personal baseline.';
    }
    final List<String> names =
        down.map((DomainReading r) => r.domain.clinicalLabel.toLowerCase()).toList();
    return 'Your recent results show greater variation in ${_list(names)} '
        'compared with your baseline.';
  }

  /// The short status shown beside the headline.
  ///
  /// Reports domain-level change rather than the overall average: a drop
  /// concentrated in one or two domains barely moves the mean, and labelling
  /// that "stable" next to a sentence describing the change is exactly the
  /// kind of quiet contradiction that makes a health app untrustworthy.
  String get statusLabel {
    if (!hasBaseline) return 'No baseline';
    if (declining.isNotEmpty) return 'Change observed';
    if (overallTrend == TrendDirection.up) return 'Improving';
    return 'Stable';
  }

  /// Which direction the status pill should be coloured for.
  TrendDirection get statusTrend =>
      declining.isNotEmpty ? TrendDirection.down : overallTrend;

  static String _list(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// Whether the app should encourage a conversation with a clinician. Two or
  /// more declining domains, or one declining domain alongside reported
  /// functional difficulty, is the threshold — not a single low session.
  bool get suggestsClinicalDiscussion =>
      declining.length >= 2 || (declining.isNotEmpty && functionalIndependence < 85);
}
