import 'package:flutter/foundation.dart';

import 'onboarding.dart';

/// How a caregiver-flagged concern is doing, compared to the last time they
/// were asked — not always back to the onboarding baseline, so a concern
/// that has plateaued doesn't read as perpetually "stable" against a stale
/// reference point.
enum ConcernTrend { better, same, worse }

/// One caregiver check-in on a specific onboarding-flagged concern.
///
/// These, plus [CaregiverNoteEntry], are the only caregiver-authored input
/// that feeds the doctor's weekly report — neither the caregiver nor the
/// patient ever sees the report itself, only the ability to add to it.
@immutable
class CaregiverConcernUpdate {
  const CaregiverConcernUpdate({
    required this.id,
    required this.difficulty,
    required this.trend,
    this.comment = '',
    required this.at,
  });

  final String id;
  final DailyDifficulty difficulty;
  final ConcernTrend trend;
  final String comment;
  final DateTime at;
}

/// One freeform, timestamped note a caregiver leaves for the doctor.
@immutable
class CaregiverNoteEntry {
  const CaregiverNoteEntry({
    required this.id,
    required this.text,
    required this.at,
  });

  final String id;
  final String text;
  final DateTime at;
}
