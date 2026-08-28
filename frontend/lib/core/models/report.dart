import 'package:flutter/foundation.dart';

import 'assessment.dart';
import 'clinical.dart';
import 'game.dart';
import 'monitoring.dart';
import 'patient.dart';

/// The clinician-ready summary — the artefact the whole journey produces.
///
/// It is a *structured summary of what the person reported and what the app
/// measured*, in the order a clinician reads it: why they came, what they and
/// their caregiver describe, how daily life is affected, what the activities
/// measured against their own baseline, and what else could explain it.
///
/// It contains no diagnosis, no disease probability and no recommendation
/// beyond "discuss this with a professional", because that is the only
/// conclusion the underlying data supports.
@immutable
class ReportSection {
  const ReportSection({required this.title, required this.lines, this.note});

  final String title;
  final List<String> lines;
  final String? note;
}

@immutable
class ClinicalReport {
  const ClinicalReport({
    required this.patientName,
    required this.age,
    required this.language,
    required this.occupation,
    required this.completedBy,
    required this.periodLabel,
    required this.generatedAtIso,
    required this.sections,
    required this.readings,
    required this.patterns,
    required this.suggestsDiscussion,
  });

  final String patientName;
  final int age;
  final String language;
  /// What the person did for a living. Recorded because it shapes what the
  /// activities ask of them, and because a clinician reads a result
  /// differently for a retired accountant than for a weaver.
  final String occupation;
  final String completedBy;
  final String periodLabel;
  final String generatedAtIso;

  final List<ReportSection> sections;
  final List<DomainReading> readings;
  final List<ObservedPattern> patterns;
  final bool suggestsDiscussion;

  static const String disclaimer =
      'This report summarises self-reported symptoms, reported daily function '
      'and in-app activity performance. It is not a diagnosis and does not '
      'detect, diagnose or exclude dementia or any other condition. Scores '
      'describe performance on this application only and should be read '
      'alongside clinical assessment, never in place of it.';

  /// Builds the report from the same objects every screen already uses, so a
  /// figure in the report can never disagree with the one on the dashboard.
  factory ClinicalReport.build({
    required Patient patient,
    required IntakeRecord intake,
    required MonitoringSnapshot snapshot,
    required DateTime now,
  }) {
    final List<ReportSection> sections = <ReportSection>[];

    // Reason for assessment.
    sections.add(ReportSection(
      title: 'Reason for assessment',
      lines: <String>[
        if (intake.reason.concerns.isEmpty)
          'No presenting concern recorded.'
        else
          ...intake.reason.concerns.map((PresentingConcern c) => c.label),
        if (intake.reason.onset != null) 'Onset: ${intake.reason.onset!.label}',
        if (intake.reason.progression != null)
          'Course: ${intake.reason.progression!.label}',
      ],
    ));

    // Reported symptoms, grouped, only what was reported at "often" or above.
    final List<SymptomItem> prominent = intake.symptoms.prominent;
    sections.add(ReportSection(
      title: 'Patient-reported symptoms',
      lines: prominent.isEmpty
          ? <String>['No symptom was reported at "often" or above.']
          : <String>[
              for (final SymptomDomain d in SymptomDomain.values)
                if (prominent.any((SymptomItem i) => i.domain == d))
                  '${d.label}: '
                      '${prominent.where((SymptomItem i) => i.domain == d).map((SymptomItem i) => i.text.toLowerCase()).join(', ')}',
            ],
      note: 'Reported severity by group — '
          '${SymptomDomain.values.map((SymptomDomain d) => '${d.label} ${intake.symptoms.severity(d).round()}%').join(' · ')}',
    ));

    // Caregiver corroboration.
    final CaregiverObservation? caregiver = intake.caregiver;
    sections.add(ReportSection(
      title: 'Caregiver observations',
      lines: caregiver == null
          ? <String>['No caregiver input was provided.']
          : <String>[
              if (caregiver.caregiverName.isNotEmpty)
                'Reported by ${caregiver.caregiverName}'
                    '${caregiver.relation.isEmpty ? '' : ' (${caregiver.relation})'}',
              ...caregiver.present.map((String p) => 'Observed: $p'),
              ...caregiver.absent.map((String p) => 'Not observed: $p'),
              if (caregiver.note.trim().isNotEmpty) 'Note: ${caregiver.note.trim()}',
            ],
    ));

    // Functional status.
    sections.add(ReportSection(
      title: 'Functional status',
      lines: <String>[
        'Reported independence: ${intake.function.independencePercent}%',
        'Instrumental activities: ${intake.function.iadlImpairment.label}',
        if (intake.function.needingHelp.isEmpty)
          'No assistance reported with the activities asked about.'
        else
          'Assistance reported with: '
              '${intake.function.needingHelp.map((FunctionalItem i) => i.label.toLowerCase()).join(', ')}',
      ],
    ));

    // Cognitive activity performance.
    sections.add(ReportSection(
      title: 'Cognitive activity performance',
      lines: <String>[
        if (!snapshot.hasBaseline)
          'No baseline has been established yet.'
        else ...<String>[
          for (final DomainReading r in snapshot.readings)
            if (r.hasReading)
              '${r.domain.clinicalLabel}: ${r.current!.round()}'
                  '${r.baseline == null ? '' : ' (baseline ${r.baseline!.round()}, ${_arrow(r.trend)} ${r.deltaLabel.toLowerCase()})'}'
            else
              '${r.domain.clinicalLabel}: not yet assessed',
        ],
        'Sessions recorded: ${snapshot.totalSessions}',
        'Assessment adherence: ${snapshot.adherencePercent}% '
            '(${snapshot.assessmentsCompleted} of ${snapshot.assessmentsExpected} weeks)',
        'Session-to-session consistency: ${snapshot.consistency}%',
      ],
      note: 'Scores are 0–100 composites of accuracy, focus and recall within '
          'this application, compared against the person\'s own first '
          'assessment rather than any population norm.',
    ));

    // Medical and contextual factors.
    sections.add(ReportSection(
      title: 'Medical & contextual factors',
      lines: <String>[
        if (intake.medical.conditions.isEmpty)
          'No relevant medical history reported.'
        else
          'Reported: ${intake.medical.conditions.map((MedicalCondition c) => c.label.toLowerCase()).join(', ')}',
        'Sleep: ${intake.medical.sleepHours.toStringAsFixed(1)} h'
            '${intake.medical.sleepQuality == null ? '' : ', quality ${intake.medical.sleepQuality!.label.toLowerCase()}'}',
        if (intake.medical.lowMood != null)
          'Persistently low mood or loss of interest: ${intake.medical.lowMood!.label.toLowerCase()}',
        if (intake.medical.medications.isNotEmpty)
          'Medications: ${intake.medical.medications.join(', ')}',
        if (intake.medical.reversibleContributors.isNotEmpty)
          'Factors that can affect performance independently of cognition: '
              '${intake.medical.reversibleContributors.join(', ')}',
      ],
    ));

    // Safety.
    if (intake.safety.requiresUrgentReview || intake.safety.hasFluctuation) {
      sections.add(ReportSection(
        title: 'Safety screen',
        lines: <String>[
          if (intake.safety.suddenOnset ?? false)
            'Reported sudden onset within hours or days.',
          if (intake.safety.neurologicalRedFlag ?? false)
            'Reported recent weakness, speech difficulty, fainting, seizure or severe headache.',
          if (intake.safety.hasFluctuation)
            'Reported alertness that fluctuates markedly through the day.',
        ],
      ));
    }

    return ClinicalReport(
      patientName: patient.name,
      age: patient.age,
      language: patient.language,
      occupation: patient.occupation.trim().isEmpty ? 'Not recorded' : patient.occupation,
      completedBy: intake.completedBy?.label ?? 'Not recorded',
      periodLabel: _period(snapshot, now),
      generatedAtIso: now.toIso8601String(),
      sections: sections,
      readings: snapshot.readings,
      patterns: snapshot.patterns,
      suggestsDiscussion: snapshot.suggestsClinicalDiscussion,
    );
  }

  /// The report as text, for sharing, printing or pasting into a record.
  String asPlainText() {
    final StringBuffer b = StringBuffer()
      ..writeln('COGNITIVE HEALTH SUMMARY')
      ..writeln('=' * 46)
      ..writeln('Patient: $patientName, $age')
      ..writeln('Language: $language · Profession: $occupation')
      ..writeln('Completed by: $completedBy')
      ..writeln('Assessment period: $periodLabel')
      ..writeln('Generated: ${generatedAtIso.split('T').first}')
      ..writeln();

    for (final ReportSection s in sections) {
      b.writeln(s.title.toUpperCase());
      b.writeln('-' * 46);
      for (final String line in s.lines) {
        b.writeln('• $line');
      }
      if (s.note != null) b.writeln('  (${s.note})');
      b.writeln();
    }

    b
      ..writeln('OBSERVED PATTERNS')
      ..writeln('-' * 46);
    for (final ObservedPattern p in patterns) {
      b.writeln('• ${p.label}: ${p.level.label.toUpperCase()} — ${p.rationale}');
    }
    b.writeln();

    if (suggestsDiscussion) {
      b
        ..writeln('NEXT STEP')
        ..writeln('-' * 46)
        ..writeln('• Persistent change was observed across more than one area. '
            'Discussion with a healthcare professional is appropriate.')
        ..writeln();
    }

    b
      ..writeln('IMPORTANT')
      ..writeln('-' * 46)
      ..writeln(disclaimer);
    return b.toString();
  }

  static String _period(MonitoringSnapshot snapshot, DateTime now) {
    final DateTime? start = snapshot.baseline?.capturedAt;
    if (start == null) return 'Single session';
    return '${_month(start)} – ${_month(now)}';
  }

  static String _month(DateTime d) {
    const List<String> names = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  static String _arrow(TrendDirection t) => switch (t) {
        TrendDirection.up => '↑',
        TrendDirection.flat => '→',
        TrendDirection.down => '↓',
      };
}
