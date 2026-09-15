import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/core/models/patient.dart';
import 'package:smaran_saathi/core/models/positive_feedback.dart';
import 'package:smaran_saathi/data/mock/mock_data.dart';
import 'package:smaran_saathi/l10n/app_localizations.dart';

/// The end-of-activity message is the one screen a dementia patient reads
/// straight after a session that may have gone badly. These tests are about
/// what it must never say, as much as what it should.
void main() {
  const AppLocalizations l = AppLocalizations(Locale('en'));

  const AdaptiveDecision decision = AdaptiveDecision(
    direction: DifficultyDirection.maintain,
    nextLevel: 2,
    reason: 'steady',
    signals: <String>[],
  );

  GamePerformance perf(int overall) => GamePerformance(
        accuracy: overall.toDouble(),
        focus: overall.toDouble(),
        memory: overall.toDouble(),
        hintsUsed: 0,
        mistakes: 0,
        seconds: 60,
        completed: true,
      );

  GameSession session(GameId id, int daysAgo, int overall) => GameSession(
        gameId: id,
        dayOffset: daysAgo,
        level: 1,
        performance: perf(overall),
        timeLabel: '10:00 AM',
        playedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      );

  PositiveFeedback build({
    required GameId id,
    required int overall,
    Patient? patient,
    List<GameSession> sessions = const <GameSession>[],
  }) =>
      PositiveFeedbackEngine.build(
        game: MockData.game(id),
        performance: perf(overall),
        decision: decision,
        l: l,
        patient: patient,
        sessions: sessions,
      );

  group('the personal note says something only about this person', () {
    test('a first session names the activity rather than inventing history', () {
      final PositiveFeedback f = build(
        id: GameId.melody,
        overall: 90,
        patient: MockData.ramesh,
        // Only the session just played, which the engine must not count as
        // history about itself.
        sessions: <GameSession>[session(GameId.melody, 0, 90)],
      );

      expect(f.personalNote, isNotNull);
      expect(f.personalNote, contains('first time'));
    });

    test('the life anchor comes from the profile, matched to the domain', () {
      // Melody is the auditory activity, so it should reach for music.
      final Patient withMusic = Patient(
        id: MockData.ramesh.id,
        name: MockData.ramesh.name,
        shortName: MockData.ramesh.shortName,
        age: MockData.ramesh.age,
        location: MockData.ramesh.location,
        language: MockData.ramesh.language,
        occupation: MockData.ramesh.occupation,
        favouriteActivity: MockData.ramesh.favouriteActivity,
        favouriteFood: MockData.ramesh.favouriteFood,
        favouriteMusic: 'Borgeet',
        tradition: MockData.ramesh.tradition,
        portraitScene: MockData.ramesh.portraitScene,
        family: MockData.ramesh.family,
        memories: MockData.ramesh.memories,
        assets: MockData.ramesh.assets,
        routine: MockData.ramesh.routine,
      );

      final PositiveFeedback f = build(
        id: GameId.melody,
        overall: 90,
        patient: withMusic,
        sessions: <GameSession>[session(GameId.melody, 0, 90)],
      );

      expect(f.personalNote, contains('Borgeet'));
    });

    test('consecutive days are counted in words, never digits', () {
      final PositiveFeedback f = build(
        id: GameId.melody,
        overall: 90,
        patient: MockData.ramesh,
        sessions: <GameSession>[
          session(GameId.melody, 0, 90),
          session(GameId.melody, 1, 88),
          session(GameId.melody, 2, 85),
        ],
      );

      expect(f.personalNote, contains('three days'));
      expect(f.personalNote, isNot(matches(RegExp(r'\d'))));
    });

    test('a long gap is welcomed back, not scolded', () {
      final PositiveFeedback f = build(
        id: GameId.melody,
        overall: 80,
        patient: MockData.ramesh,
        sessions: <GameSession>[
          session(GameId.melody, 0, 80),
          session(GameId.melody, 40, 80),
        ],
      );

      expect(f.personalNote, contains('good to have you back'));
    });

    test('an improvement on their own last session is named', () {
      final PositiveFeedback f = build(
        id: GameId.melody,
        overall: 92, // radiant
        patient: MockData.ramesh,
        sessions: <GameSession>[
          session(GameId.melody, 0, 92),
          session(GameId.melody, 3, 50), // gentle, and long enough ago
        ],
      );

      expect(f.personalNote, contains('more smoothly'));
    });
  });

  group('it never reports a decline', () {
    test('a worse session than last time gets no history sentence at all', () {
      final PositiveFeedback f = build(
        id: GameId.melody,
        overall: 40, // gentle
        patient: MockData.ramesh,
        sessions: <GameSession>[
          session(GameId.melody, 0, 40),
          session(GameId.melody, 3, 95), // they did far better before
        ],
      );

      final String note = f.personalNote ?? '';
      for (final String forbidden in <String>[
        'less',
        'worse',
        'harder',
        'not as',
        'last time',
      ]) {
        expect(note.toLowerCase(), isNot(contains(forbidden)),
            reason: 'a gentler session must not be compared to a better one');
      }
    });

    test('no session ever renders a digit in the personal note', () {
      for (final int overall in <int>[0, 30, 55, 70, 85, 100]) {
        final PositiveFeedback f = build(
          id: GameId.memoryCards,
          overall: overall,
          patient: MockData.ramesh,
          sessions: <GameSession>[
            session(GameId.memoryCards, 0, overall),
            session(GameId.memoryCards, 1, 60),
            session(GameId.memoryCards, 2, 60),
          ],
        );
        expect(f.personalNote ?? '', isNot(matches(RegExp(r'\d'))));
      }
    });
  });

  group('it stays silent rather than saying something empty', () {
    test('a blank profile with unremarkable history produces no note', () {
      // A steady session matching an equally steady one a few days ago:
      // nothing to celebrate, nothing to mourn, and a profile with no
      // details to draw on. The right output is silence.
      final PositiveFeedback f = build(
        id: GameId.memoryCards,
        overall: 60,
        patient: MockData.emptyPatient,
        sessions: <GameSession>[
          session(GameId.memoryCards, 0, 60),
          session(GameId.memoryCards, 4, 60),
        ],
      );

      expect(f.personalNote, isNull);
    });

    test('omitting the patient keeps the old, impersonal behaviour', () {
      final PositiveFeedback f = build(id: GameId.memoryCards, overall: 70);
      expect(f.personalNote, isNull);
      // The rest of the feedback is untouched.
      expect(f.headline, isNotEmpty);
      expect(f.body, isNotEmpty);
      expect(f.domainNote, isNotEmpty);
    });

    test('an epoch playedAt from an old box never invents a streak', () {
      final PositiveFeedback f = build(
        id: GameId.memoryCards,
        overall: 70,
        patient: MockData.emptyPatient,
        sessions: <GameSession>[
          GameSession(
            gameId: GameId.memoryCards,
            dayOffset: 0,
            level: 1,
            performance: perf(70),
            timeLabel: '10:00 AM',
            playedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          GameSession(
            gameId: GameId.memoryCards,
            dayOffset: 1,
            level: 1,
            performance: perf(70),
            timeLabel: '10:00 AM',
            playedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      );

      expect(f.personalNote ?? '', isNot(contains('running')));
    });
  });
}
