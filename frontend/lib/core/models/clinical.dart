import 'package:flutter/material.dart';

import 'game.dart';

/// Cognitive performance across domains. Deliberately framed as *activity
/// performance*, never as a diagnosis.
@immutable
class CognitiveProfile {
  const CognitiveProfile({required this.scores, required this.overall, required this.updated});

  final Map<CognitiveDomain, int> scores;
  final int overall;
  final String updated;

  int score(CognitiveDomain d) => scores[d] ?? 0;

  static CognitiveProfile fromJson(Map<String, dynamic> j) {
    final Map<CognitiveDomain, int> scores = <CognitiveDomain, int>{};
    final Object? rawScores = j['scores'];
    if (rawScores is Map<String, dynamic>) {
      for (final CognitiveDomain d in CognitiveDomain.values) {
        final Object? v = rawScores[d.name];
        if (v is int) scores[d] = v;
      }
    }
    return CognitiveProfile(
      scores: scores,
      overall: j['overall'] as int? ?? 0,
      updated: j['updated'] as String? ?? '',
    );
  }

  CognitiveProfile withDelta(Map<CognitiveDomain, int> deltas) {
    final Map<CognitiveDomain, int> next = Map<CognitiveDomain, int>.from(scores);
    deltas.forEach((CognitiveDomain k, int v) {
      next[k] = ((next[k] ?? 60) + v).clamp(20, 99);
    });
    final int avg = (next.values.reduce((int a, int b) => a + b) / next.length).round();
    return CognitiveProfile(scores: next, overall: avg, updated: 'Updated just now');
  }
}

enum TrendDirection { up, flat, down }

extension TrendDirectionX on TrendDirection {
  IconData get icon => switch (this) {
        TrendDirection.up => Icons.north_east_rounded,
        TrendDirection.flat => Icons.east_rounded,
        TrendDirection.down => Icons.south_east_rounded,
      };

  String get label => switch (this) {
        TrendDirection.up => 'Improving',
        TrendDirection.flat => 'Stable',
        TrendDirection.down => 'Declining',
      };
}

enum ClinicalStatus { stable, needsAttention, followUp }

extension ClinicalStatusX on ClinicalStatus {
  String get label => switch (this) {
        ClinicalStatus.stable => 'Stable',
        ClinicalStatus.needsAttention => 'Needs attention',
        ClinicalStatus.followUp => 'Follow-up',
      };
}

/// A row in the clinician's caseload.
@immutable
class ClinicPatient {
  const ClinicPatient({
    required this.id,
    required this.name,
    required this.age,
    required this.district,
    required this.score,
    required this.trend,
    required this.status,
    required this.sceneId,
    required this.language,
    required this.lastSession,
    required this.profile,
    required this.thirtyDay,
    required this.adherence,
    required this.engagement,
  });

  final String id;
  final String name;
  final int age;
  final String district;
  final int score;
  final TrendDirection trend;
  final ClinicalStatus status;
  final String sceneId;
  final String language;
  final String lastSession;
  final CognitiveProfile profile;

  /// 30 daily activity-score points, oldest first.
  final List<double> thirtyDay;
  final int adherence;
  final int engagement;

  static ClinicPatient fromJson(Map<String, dynamic> j) => ClinicPatient(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        age: j['age'] as int? ?? 0,
        district: j['district'] as String? ?? '',
        score: j['score'] as int? ?? 0,
        trend: switch (j['trend'] as String?) {
          'up' => TrendDirection.up,
          'down' => TrendDirection.down,
          _ => TrendDirection.flat,
        },
        status: switch (j['status'] as String?) {
          'needsAttention' => ClinicalStatus.needsAttention,
          'followUp' => ClinicalStatus.followUp,
          _ => ClinicalStatus.stable,
        },
        sceneId: j['sceneId'] as String? ?? '',
        language: j['language'] as String? ?? '',
        lastSession: j['lastSession'] as String? ?? '',
        profile: j['profile'] is Map<String, dynamic>
            ? CognitiveProfile.fromJson(j['profile'] as Map<String, dynamic>)
            : const CognitiveProfile(scores: <CognitiveDomain, int>{}, overall: 0, updated: ''),
        thirtyDay: <double>[
          for (final Object? v in (j['thirtyDay'] as List<dynamic>? ?? const <dynamic>[]))
            (v as num).toDouble(),
        ],
        adherence: j['adherence'] as int? ?? 0,
        engagement: j['engagement'] as int? ?? 0,
      );

  ClinicPatient copyWith({int? score, CognitiveProfile? profile, List<double>? thirtyDay}) {
    return ClinicPatient(
      id: id,
      name: name,
      age: age,
      district: district,
      score: score ?? this.score,
      trend: trend,
      status: status,
      sceneId: sceneId,
      language: language,
      lastSession: lastSession,
      profile: profile ?? this.profile,
      thirtyDay: thirtyDay ?? this.thirtyDay,
      adherence: adherence,
      engagement: engagement,
    );
  }
}

enum AlertSeverity { info, watch, urgent }

extension AlertSeverityX on AlertSeverity {
  String get label => switch (this) {
        AlertSeverity.info => 'Informational',
        AlertSeverity.watch => 'Requires attention',
        AlertSeverity.urgent => 'Consider further assessment',
      };
}

@immutable
class DoctorAlert {
  const DoctorAlert({
    required this.id,
    required this.patientName,
    required this.title,
    required this.detail,
    required this.severity,
    required this.age,
    this.domain,
  });

  final String id;
  final String patientName;
  final String title;
  final String detail;
  final AlertSeverity severity;

  /// e.g. "2 days ago"
  final String age;
  final CognitiveDomain? domain;
}

/// One labelled point for the small charts across the app.
@immutable
class SeriesPoint {
  const SeriesPoint(this.label, this.value);
  final String label;
  final double value;
}
