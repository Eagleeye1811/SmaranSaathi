import 'package:flutter/material.dart';

/// A personalised check-in question the companion asks during the day.
@immutable
class DailyQuestion {
  const DailyQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.journalLabel,
    this.subtitle = '',
    this.sceneId,
    this.warmFollowUp = 'Thank you for telling me.',
  });

  final String id;
  final String text;
  final String subtitle;

  /// Large tappable answers — no typing is ever required of the patient.
  final List<QuestionOption> options;

  /// How a positive answer reads in the memory journal.
  final String journalLabel;

  /// Optional illustration shown with the question (e.g. Priya's portrait).
  final String? sceneId;
  final String warmFollowUp;
}

@immutable
class QuestionOption {
  const QuestionOption({
    required this.label,
    required this.emoji,
    this.positive = true,
    this.response,
  });

  final String label;
  final String emoji;

  /// Whether the answer counts as "remembered / engaged" in the journal.
  final bool positive;
  final String? response;
}

@immutable
class JournalEntry {
  const JournalEntry({
    required this.questionId,
    required this.label,
    required this.answer,
    required this.positive,
    required this.time,
  });

  final String questionId;
  final String label;
  final String answer;
  final bool positive;
  final String time;
}

enum MoodLevel { good, okay, low }

extension MoodLevelX on MoodLevel {
  String get label => switch (this) {
        MoodLevel.good => 'Good',
        MoodLevel.okay => 'Okay',
        MoodLevel.low => 'Not good',
      };

  String get emoji => switch (this) {
        MoodLevel.good => '😊',
        MoodLevel.okay => '😐',
        MoodLevel.low => '😔',
      };

  String get companionReply => switch (this) {
        MoodLevel.good => 'That makes me happy. Let us have a lovely day together.',
        MoodLevel.okay => 'That is alright. We will take today slowly, together.',
        MoodLevel.low => 'I am here with you. Shall we do something gentle and familiar?',
      };
}

enum ReminderKind { medicine, hydration, cognitive, appointment, routine, social }

extension ReminderKindX on ReminderKind {
  String get label => switch (this) {
        ReminderKind.medicine => 'Medicine',
        ReminderKind.hydration => 'Hydration',
        ReminderKind.cognitive => 'Cognitive activity',
        ReminderKind.appointment => 'Appointment',
        ReminderKind.routine => 'Daily routine',
        ReminderKind.social => 'Social activity',
      };

  IconData get icon => switch (this) {
        ReminderKind.medicine => Icons.medication_liquid_rounded,
        ReminderKind.hydration => Icons.water_drop_rounded,
        ReminderKind.cognitive => Icons.psychology_alt_rounded,
        ReminderKind.appointment => Icons.event_available_rounded,
        ReminderKind.routine => Icons.wb_twilight_rounded,
        ReminderKind.social => Icons.people_rounded,
      };

  String get glyph => switch (this) {
        ReminderKind.medicine => '💊',
        ReminderKind.hydration => '💧',
        ReminderKind.cognitive => '🧠',
        ReminderKind.appointment => '📅',
        ReminderKind.routine => '🛌',
        ReminderKind.social => '🤝',
      };
}

@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.time,
    required this.minutesFromMidnight,
    required this.title,
    required this.kind,
    this.detail = '',
    this.done = false,
    this.smsEnabled = true,
  });

  final String id;
  final String time;
  final int minutesFromMidnight;
  final String title;
  final ReminderKind kind;
  final String detail;
  final bool done;
  /// When true, the backend scheduler will send an SMS to the patient's
  /// registered phone number at the scheduled time.
  final bool smsEnabled;

  Reminder copyWith({bool? done, bool? smsEnabled}) => Reminder(
        id: id,
        time: time,
        minutesFromMidnight: minutesFromMidnight,
        title: title,
        kind: kind,
        detail: detail,
        done: done ?? this.done,
        smsEnabled: smsEnabled ?? this.smsEnabled,
      );
}

/// A step on the patient's "Today's Journey" strip.
@immutable
class JourneyStep {
  const JourneyStep({required this.id, required this.label, required this.icon});
  final String id;
  final String label;
  final IconData icon;
}

/// Everything the patient did today that has to survive a restart.
///
/// Loaded in one call at startup so [AppState] can rebuild the day without a
/// round trip per field.
@immutable
class DailySnapshot {
  const DailySnapshot({
    this.mood,
    this.journal = const <JournalEntry>[],
    this.answeredQuestions = const <String>{},
    this.journeyDone = const <String>{},
    this.engagement = 78,
    this.completedGameIds = const <String>{},
    this.dayStamp,
  });

  final MoodLevel? mood;
  final List<JournalEntry> journal;
  final Set<String> answeredQuestions;
  final Set<String> journeyDone;
  final int engagement;

  /// `GameId.name` values completed today.
  final Set<String> completedGameIds;

  /// `yyyy-mm-dd` the snapshot belongs to. A snapshot from a previous day is
  /// discarded on load — "today's activities" must not carry over.
  final String? dayStamp;

  static const DailySnapshot empty = DailySnapshot();
}
