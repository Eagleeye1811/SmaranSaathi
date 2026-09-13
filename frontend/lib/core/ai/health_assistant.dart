import 'package:flutter/material.dart';

import '../models/assessment.dart';
import '../models/clinical.dart';
import '../models/game.dart';
import '../models/monitoring.dart';
import '../models/patient.dart';

/// What the assistant is asked to do, offered as buttons rather than an empty
/// text box.
///
/// A blank chat prompt is the wrong interface for someone worried about their
/// memory: it asks them to know what to ask. These six cover what people
/// actually want from a cognitive monitoring app, and each one is answered
/// from their own data.
enum HealthQuickAction {
  explainResults,
  whyChanged,
  prepareForDoctor,
  whatToMonitor,
  aboutDementia,
  howAmIDoing,
}

extension HealthQuickActionX on HealthQuickAction {
  String get label => switch (this) {
        HealthQuickAction.explainResults => 'Explain my results',
        HealthQuickAction.whyChanged => 'Why did my score change?',
        HealthQuickAction.prepareForDoctor => 'Prepare for my doctor visit',
        HealthQuickAction.whatToMonitor => 'What should I monitor?',
        HealthQuickAction.aboutDementia => 'Explain dementia',
        HealthQuickAction.howAmIDoing => 'How am I doing?',
      };

  IconData get icon => switch (this) {
        HealthQuickAction.explainResults => Icons.insights_rounded,
        HealthQuickAction.whyChanged => Icons.help_outline_rounded,
        HealthQuickAction.prepareForDoctor => Icons.medical_information_outlined,
        HealthQuickAction.whatToMonitor => Icons.visibility_outlined,
        HealthQuickAction.aboutDementia => Icons.menu_book_outlined,
        HealthQuickAction.howAmIDoing => Icons.favorite_outline_rounded,
      };
}

/// One answer: a short spoken-style paragraph, optional bullets, and where the
/// numbers in it came from.
@immutable
class HealthAnswer {
  const HealthAnswer({
    required this.text,
    this.bullets = const <String>[],
    this.followUps = const <HealthQuickAction>[],
    this.grounded = true,
  });

  final String text;
  final List<String> bullets;
  final List<HealthQuickAction> followUps;

  /// True when every figure in the answer came from this person's own record.
  /// The screen labels ungrounded answers as general information.
  final bool grounded;
}

/// The data-aware, safety-constrained assistant.
///
/// Two rules make this useful rather than gimmicky:
///
/// 1. **It only says what the record supports.** Every number below is read
///    from the same snapshot the dashboard draws; there is no model inventing
///    a figure, and no network call needed to answer.
/// 2. **It will not diagnose, under any phrasing.** [diagnosisGuard] catches
///    the question people most want to ask, and answers it honestly — what the
///    app can say, what it cannot, and who can.
class HealthAssistant {
  const HealthAssistant();

  /// Questions that must never reach a language model, because the honest
  /// answer is fixed and a fluent guess would be harmful.
  ///
  /// The stems are matched with a trailing `\w*` on purpose: "diagnose",
  /// "diagnosed" and "diagnosis" are the same question, and a pattern that
  /// only caught one of them would let the other reach a language model.
  static final RegExp _diagnosisPattern = RegExp(
    r'\b(alzheimer\w*|dementia|lewy|parkinson\w*|diagnos\w*|do i have|have i got|'
    r"am i getting|what.?s wrong with me|how long do i have|will i forget|"
    r'am i losing my (mind|memory))',
    caseSensitive: false,
  );

  /// Returns a fixed, honest answer when the question asks for a diagnosis,
  /// and null otherwise.
  HealthAnswer? diagnosisGuard(String question, {required MonitoringSnapshot snapshot}) {
    if (!_diagnosisPattern.hasMatch(question)) return null;
    return HealthAnswer(
      text: 'I cannot diagnose Alzheimer\'s disease or any other condition, and I '
          'would not want to guess about something this important. Several very '
          'different conditions can cause cognitive changes, and some of them are '
          'treatable, and telling them apart needs a professional assessment.\n\n'
          'What I can do is summarise exactly what you have reported and what your '
          'activities have measured, so you can take it to a doctor.',
      bullets: <String>[
        if (snapshot.hasBaseline)
          'You have ${snapshot.totalSessions} recorded sessions since your baseline',
        if (snapshot.declining.isNotEmpty)
          'Change from baseline in: ${snapshot.declining.map((DomainReading r) => r.domain.clinicalLabel.toLowerCase()).join(', ')}',
        'Your summary is ready under "Prepare for my doctor visit"',
      ],
      followUps: <HealthQuickAction>[
        HealthQuickAction.prepareForDoctor,
        HealthQuickAction.explainResults,
      ],
    );
  }

  /// Answers one of the quick actions from the person's own record.
  HealthAnswer answer(
    HealthQuickAction action, {
    required Patient patient,
    required IntakeRecord intake,
    required MonitoringSnapshot snapshot,
  }) {
    return switch (action) {
      HealthQuickAction.explainResults => _explainResults(snapshot),
      HealthQuickAction.whyChanged => _whyChanged(intake, snapshot),
      HealthQuickAction.prepareForDoctor => _prepareForDoctor(intake, snapshot),
      HealthQuickAction.whatToMonitor => _whatToMonitor(intake, snapshot),
      HealthQuickAction.aboutDementia => _aboutDementia(),
      HealthQuickAction.howAmIDoing => _howAmIDoing(patient, snapshot),
    };
  }

  // ── Answers ────────────────────────────────────────────────────────────

  HealthAnswer _explainResults(MonitoringSnapshot snapshot) {
    if (!snapshot.hasBaseline) {
      return const HealthAnswer(
        text: 'You have not completed a baseline assessment yet, so there is '
            'nothing to compare against. Once you finish the six activities '
            'once, everything afterwards is measured against that starting '
            'point rather than against other people.',
        followUps: <HealthQuickAction>[HealthQuickAction.aboutDementia],
      );
    }

    final List<DomainReading> down = snapshot.declining;
    final List<DomainReading> steady = snapshot.assessed
        .where((DomainReading r) => r.trend == TrendDirection.flat)
        .toList(growable: false);

    return HealthAnswer(
      text: down.isEmpty
          ? 'Your recent activity scores are in line with your own baseline. '
              'Small movements up and down between sessions are normal and do not '
              'mean anything on their own. This is a monitoring observation, not '
              'a diagnosis.'
          : 'Compared with your own baseline, your '
              '${down.map((DomainReading r) => r.domain.clinicalLabel.toLowerCase()).join(' and ')} '
              'activities have been scoring lower recently. '
              '${steady.isEmpty ? '' : 'Your ${steady.take(2).map((DomainReading r) => r.domain.clinicalLabel.toLowerCase()).join(' and ')} results have stayed steady. '}'
              'This is a monitoring observation, not a diagnosis.',
      bullets: <String>[
        for (final DomainReading r in snapshot.assessed)
          '${r.domain.clinicalLabel}: ${r.current!.round()} '
              '(baseline ${r.baseline?.round() ?? '—'}), ${r.deltaLabel.toLowerCase()}',
      ],
      followUps: <HealthQuickAction>[
        HealthQuickAction.whyChanged,
        HealthQuickAction.prepareForDoctor,
      ],
    );
  }

  HealthAnswer _whyChanged(IntakeRecord intake, MonitoringSnapshot snapshot) {
    final List<String> contributors = intake.medical.reversibleContributors;
    return HealthAnswer(
      text: 'A single lower session usually is not decline. Performance on tasks '
          'like these moves with sleep, mood, illness, medication, pain, noise '
          'and simple tiredness, and it varies naturally from day to day. '
          'What matters is whether a change persists across several weeks.\n\n'
          '${contributors.isEmpty ? 'Nothing in your health record obviously explains a dip.' : 'From what you told us, these could be affecting your results: ${contributors.join(', ')}.'} '
          'If the change continues, it is worth discussing with a healthcare '
          'professional.',
      bullets: <String>[
        'Session-to-session consistency: ${snapshot.consistency}%',
        if (snapshot.lastAssessmentDaysAgo != null && snapshot.lastAssessmentDaysAgo! < 9000)
          'Last assessment: ${snapshot.lastAssessmentDaysAgo == 0 ? 'today' : '${snapshot.lastAssessmentDaysAgo} days ago'}',
        'Assessments completed: ${snapshot.assessmentsCompleted} of ${snapshot.assessmentsExpected} weeks',
      ],
      followUps: <HealthQuickAction>[
        HealthQuickAction.whatToMonitor,
        HealthQuickAction.explainResults,
      ],
    );
  }

  HealthAnswer _prepareForDoctor(IntakeRecord intake, MonitoringSnapshot snapshot) {
    final List<String> questions = <String>[
      if (snapshot.declining.isNotEmpty)
        'My ${snapshot.declining.first.domain.clinicalLabel.toLowerCase()} scores have moved away from my baseline over '
            '${snapshot.assessmentsExpected} weeks. What could explain that?',
      if (intake.reason.onset != null)
        'I first noticed changes ${intake.reason.onset!.label.toLowerCase()} and they have been '
            '${(intake.reason.progression?.label ?? 'changing').toLowerCase()}. Is that pattern important?',
      if (intake.function.needingHelp.isNotEmpty)
        'I now need help with ${intake.function.needingHelp.map((FunctionalItem i) => i.label.toLowerCase()).join(' and ')}. Should that be assessed?',
      if (intake.medical.reversibleContributors.isNotEmpty)
        'Could ${intake.medical.reversibleContributors.join(' or ')} be contributing?',
      'Are there blood tests or scans that would rule anything out?',
      'What should I watch for, and when should I come back?',
    ];

    return HealthAnswer(
      text: 'Here is what I would take to the appointment. Your full summary of '
          'symptoms, caregiver observations, daily function and twelve weeks of '
          'activity trends is ready to share from the report screen.',
      bullets: questions,
      followUps: <HealthQuickAction>[HealthQuickAction.explainResults],
    );
  }

  HealthAnswer _whatToMonitor(IntakeRecord intake, MonitoringSnapshot snapshot) {
    return HealthAnswer(
      text: 'Keep the weekly assessment going. A trend is only as good as the '
          'points in it. Alongside that, these are the things worth noticing '
          'between sessions, based on what you have already told us.',
      bullets: <String>[
        if (snapshot.declining.isNotEmpty)
          'Whether ${snapshot.declining.map((DomainReading r) => r.domain.clinicalLabel.toLowerCase()).join(' and ')} difficulties show up in everyday life, not just in the activities',
        if (intake.function.needingHelp.isNotEmpty)
          'Whether help is needed with anything new beyond '
              '${intake.function.needingHelp.map((FunctionalItem i) => i.label.toLowerCase()).join(', ')}',
        'Any sudden change over hours or days, which needs medical attention, not monitoring',
        'Sleep, mood and new medications, since all three affect performance',
        'Anything a family member notices that you have not',
      ],
      followUps: <HealthQuickAction>[HealthQuickAction.prepareForDoctor],
    );
  }

  HealthAnswer _aboutDementia() {
    return const HealthAnswer(
      text: '"Dementia" is an umbrella term for a lasting decline in thinking '
          'that is significant enough to affect everyday life. It is caused by '
          'several different underlying conditions, and it is not a normal part '
          'of ageing.\n\n'
          'Forgetting a name and remembering it later is ordinary. Repeatedly '
          'losing track of recent conversations, or no longer managing tasks you '
          'used to manage, is worth assessing, partly because some causes of '
          'cognitive change, such as thyroid problems, vitamin deficiency, '
          'depression, sleep disorders and medication effects, can be treated.',
      bullets: <String>[
        'Only a clinician can determine the cause of cognitive change',
        'This app monitors and summarises; it does not detect or exclude any condition',
        'Sudden changes are a reason to seek medical help straight away',
      ],
      grounded: false,
      followUps: <HealthQuickAction>[
        HealthQuickAction.whatToMonitor,
        HealthQuickAction.prepareForDoctor,
      ],
    );
  }

  HealthAnswer _howAmIDoing(Patient patient, MonitoringSnapshot snapshot) {
    if (!snapshot.hasBaseline) {
      return const HealthAnswer(
        text: 'We are just getting started. Once you have completed the baseline '
            'assessment I will be able to tell you how things are moving.',
      );
    }
    return HealthAnswer(
      text: '${snapshot.headline} '
          '${snapshot.declining.isEmpty ? 'You have kept the assessments going, which is what makes any of this meaningful.' : 'Your other areas have held steady.'} '
          'This is a monitoring observation, not a diagnosis.',
      bullets: <String>[
        'Assessment adherence: ${snapshot.adherencePercent}%',
        'Reported independence in daily activities: ${snapshot.functionalIndependence}%',
        'Sessions recorded: ${snapshot.totalSessions}',
      ],
      followUps: <HealthQuickAction>[
        HealthQuickAction.explainResults,
        HealthQuickAction.whyChanged,
      ],
    );
  }
}
