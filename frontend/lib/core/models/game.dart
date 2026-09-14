import 'package:flutter/material.dart';

/// The activities in the prototype — most are scored cognitive exercises,
/// but not all (see [GameDefinition.hasLevels]).
///
/// New values should still be appended at the end, matching every prior
/// addition here: `Hive`'s `EnumAdapter<GameId>` (see `data/local/adapters.dart`)
/// is actually name-based, not index-based, but appending last keeps this
/// enum's history easy to read and costs nothing.
enum GameId {
  procedure,
  story,
  familiarPlace,
  melody,
  weaves,
  memoryCards,
  villageMarket,
  moodCanvas,
}

/// The cognitive domain an activity mainly exercises.
enum CognitiveDomain { memory, attention, reasoning, spatial, auditory, procedural }

extension CognitiveDomainX on CognitiveDomain {
  /// The patient-facing name, kept warm and plain.
  String get label => switch (this) {
        CognitiveDomain.memory => 'Memory',
        CognitiveDomain.attention => 'Attention',
        CognitiveDomain.reasoning => 'Reasoning',
        CognitiveDomain.spatial => 'Spatial',
        CognitiveDomain.auditory => 'Auditory',
        CognitiveDomain.procedural => 'Procedural',
      };

  /// The name a clinician would recognise, used on the cognitive profile,
  /// the trends and the report.
  ///
  /// Each label is claimed only where the activity behind it genuinely
  /// exercises that function — the six activities were not built to a
  /// standard battery, so nothing here is presented as an equivalent of one.
  String get clinicalLabel => switch (this) {
        CognitiveDomain.memory => 'Memory',
        CognitiveDomain.attention => 'Attention',
        CognitiveDomain.reasoning => 'Language & reasoning',
        CognitiveDomain.spatial => 'Visuospatial',
        CognitiveDomain.auditory => 'Auditory processing',
        CognitiveDomain.procedural => 'Executive function',
      };

  /// What the activities in this domain actually ask the person to do.
  String get measures => switch (this) {
        CognitiveDomain.memory => 'Recalling and recognising material after a delay',
        CognitiveDomain.attention => 'Sustaining focus and resisting distraction',
        CognitiveDomain.reasoning => 'Following a narrative and choosing a sensible next step',
        CognitiveDomain.spatial => 'Locating objects and orienting within a familiar space',
        CognitiveDomain.auditory => 'Holding and reproducing a heard sequence',
        CognitiveDomain.procedural => 'Sequencing and planning the steps of a familiar task',
      };

  IconData get icon => switch (this) {
        CognitiveDomain.memory => Icons.psychology_alt_rounded,
        CognitiveDomain.attention => Icons.center_focus_strong_rounded,
        CognitiveDomain.reasoning => Icons.lightbulb_outline_rounded,
        CognitiveDomain.spatial => Icons.explore_outlined,
        CognitiveDomain.auditory => Icons.graphic_eq_rounded,
        CognitiveDomain.procedural => Icons.checklist_rounded,
      };
}

/// Which domain each activity reports into.
///
/// The single source of truth: the content catalogue, the AI context and the
/// monitoring service all read this rather than each keeping their own copy —
/// they disagreed once, and a domain score computed from a different mapping
/// than the one shown on screen is the worst kind of wrong.
class GameDomains {
  const GameDomains._();

  /// `null` for an activity that isn't a cognitive-skill test at all (see
  /// [GameDefinition.hasLevels]) — returning a domain for it would either
  /// misrepresent what it measures, or (if given its own new domain) add a
  /// radar-chart wedge that can never have data, since nothing ever creates
  /// a scored session for it. Callers that bucket sessions by domain (see
  /// `CognitiveMonitoringService._bucket`) must skip a `null` result.
  static CognitiveDomain? of(GameId id) => switch (id) {
        GameId.procedure => CognitiveDomain.procedural,
        GameId.story => CognitiveDomain.reasoning,
        GameId.familiarPlace => CognitiveDomain.spatial,
        GameId.melody => CognitiveDomain.auditory,
        GameId.weaves => CognitiveDomain.attention,
        GameId.memoryCards => CognitiveDomain.memory,
        // Shares Procedure's domain rather than adding a new CognitiveDomain:
        // both are "Executive function" clinically, and the monitoring
        // service's executive-concerns pattern already reads `procedural`.
        GameId.villageMarket => CognitiveDomain.procedural,
        // Free drawing tests nothing on this list — see the doc comment.
        GameId.moodCanvas => null,
      };

  static List<GameId> forDomain(CognitiveDomain domain) =>
      GameId.values.where((GameId g) => of(g) == domain).toList(growable: false);
}

/// Static definition of an activity — name, framing, illustration, focus.
@immutable
class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.domain,
    required this.sceneId,
    required this.accent,
    required this.tint,
    required this.estimatedMinutes,
    this.hasLevels = true,
  });

  final GameId id;
  final String name;
  final String tagline;
  final String description;

  /// `null` for an activity with no genuine cognitive-domain claim — see
  /// [GameDomains.of], which this should always agree with.
  final CognitiveDomain? domain;
  final String sceneId;
  final Color accent;
  final Color tint;
  final int estimatedMinutes;

  /// False for an activity with no difficulty levels or adaptive scoring —
  /// screens that show a level picker, a "Level N" indicator, or a
  /// score-by-activity chart must gate on this rather than assume every
  /// catalogue entry is a scored exercise.
  final bool hasLevels;
}

/// The result of one play-through, fed to the adaptive engine.
@immutable
class GamePerformance {
  const GamePerformance({
    required this.accuracy,
    required this.focus,
    required this.memory,
    required this.hintsUsed,
    required this.mistakes,
    required this.seconds,
    required this.completed,
    this.attempts = 0,
    this.correct = 0,
    this.responseMillis = 0,
  });

  /// 0–100
  final double accuracy;
  final double focus;
  final double memory;
  final int hintsUsed;
  final int mistakes;
  final int seconds;
  final bool completed;

  /// Response-level counts. Recorded because a clinician reads *how* a score
  /// was reached, not just the score: 70% reached in eight confident attempts
  /// is a different observation from 70% reached in twenty hesitant ones.
  final int attempts;
  final int correct;

  /// Mean time per response, in milliseconds. Derived from the session's own
  /// clock rather than measured per tap, so it is an average pace rather than
  /// a laboratory reaction time — the report says so.
  final int responseMillis;

  double get responseSeconds => responseMillis / 1000;

  String get responseLabel =>
      responseMillis == 0 ? '—' : '${(responseMillis / 1000).toStringAsFixed(1)}s';

  int get incorrect => attempts == 0 ? mistakes : (attempts - correct).clamp(0, attempts);

  /// A single friendly headline number shown on the result screen.
  int get overall => ((accuracy * 0.5) + (focus * 0.25) + (memory * 0.25)).round().clamp(0, 100);

  String get durationLabel {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

/// One completed session, stored in mock history.
@immutable
class GameSession {
  const GameSession({
    required this.gameId,
    required this.dayOffset,
    required this.level,
    required this.performance,
    required this.timeLabel,
    required this.playedAt,
  });

  final GameId gameId;

  /// 0 = today, 1 = yesterday …
  final int dayOffset;
  final int level;
  final GamePerformance performance;
  final String timeLabel;

  /// When this was actually played — used to bucket sessions into a real
  /// rolling 7-day reporting window (see `WeeklyReportBuilder`). Added after
  /// the first release; a box written by an older build has no field 5,
  /// which the adapter defaults to the epoch rather than crashing.
  final DateTime playedAt;
}

/// What the adaptive engine decided to do next.
enum DifficultyDirection { increase, maintain, decrease }

extension DifficultyDirectionX on DifficultyDirection {
  String get label => switch (this) {
        DifficultyDirection.increase => 'Difficulty ↑',
        DifficultyDirection.maintain => 'Difficulty maintained',
        DifficultyDirection.decrease => 'Difficulty ↓',
      };

  String get patientMessage => switch (this) {
        DifficultyDirection.increase => 'Next time we will try something a little bigger.',
        DifficultyDirection.maintain => 'We will keep next time just like this one.',
        DifficultyDirection.decrease => 'Next time will be a little gentler.',
      };

  IconData get icon => switch (this) {
        DifficultyDirection.increase => Icons.trending_up_rounded,
        DifficultyDirection.maintain => Icons.trending_flat_rounded,
        DifficultyDirection.decrease => Icons.trending_down_rounded,
      };
}

@immutable
class AdaptiveDecision {
  const AdaptiveDecision({
    required this.direction,
    required this.nextLevel,
    required this.reason,
    required this.signals,
  });

  final DifficultyDirection direction;
  final int nextLevel;
  final String reason;

  /// Human-readable signals the engine "considered" — shown to build trust.
  final List<String> signals;
}
