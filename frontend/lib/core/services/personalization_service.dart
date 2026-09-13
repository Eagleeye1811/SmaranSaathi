import 'package:flutter/foundation.dart';

import '../../data/mock/mock_data.dart';
import '../models/game.dart';
import '../models/patient.dart';

/// Why the companion is suggesting something — shown to the patient in plain
/// words and to the caregiver as an explanation of the recommendation.
@immutable
class Recommendation {
  const Recommendation({
    required this.gameId,
    required this.headline,
    required this.reason,
    required this.evidence,
  });

  final GameId gameId;
  final String headline;

  /// Patient-facing sentence, warm and short.
  final String reason;

  /// Caregiver-facing: which profile facts produced this.
  final List<String> evidence;
}

/// Simulated personalisation engine.
///
/// Maps facts from the patient's memory profile onto content choices. The
/// logic is intentionally simple and readable — the point of the prototype is
/// to show *that* the product personalises and *what from*, not to ship a
/// recommender.
class PersonalizationService {
  const PersonalizationService();

  /// Picks today's suggested activity from the profile and recent history.
  Recommendation recommend(
    Patient patient, {
    Map<GameId, int> completedToday = const <GameId, int>{},
    GameId? avoid,
  }) {
    final String occupation = patient.occupation.toLowerCase();
    final String activity = patient.favouriteActivity.toLowerCase();
    final String food = patient.favouriteFood.toLowerCase();

    final List<Recommendation> candidates = <Recommendation>[];

    if (occupation.contains('weav') || activity.contains('weav')) {
      candidates.add(Recommendation(
        gameId: GameId.weaves,
        headline: 'Weaves of the Hills',
        reason: 'You know these patterns better than anyone. Shall we finish one together?',
        evidence: <String>[
          'Occupation: ${patient.occupation}',
          'Favourite activity: ${patient.favouriteActivity}',
          'Memory asset: her first gamosa',
        ],
      ));
      candidates.add(Recommendation(
        gameId: GameId.procedure,
        headline: 'Procedure Reconstruction',
        reason: 'Let us try something you know well: the steps of dressing the loom.',
        evidence: <String>[
          'Occupation: ${patient.occupation}',
          'Procedural memory is her strongest recent domain',
        ],
      ));
    }

    if (activity.contains('cook') || food.isNotEmpty) {
      candidates.add(Recommendation(
        gameId: GameId.procedure,
        headline: 'Procedure Reconstruction',
        reason: 'Let us try something you know well. Shall we make tea, step by step?',
        evidence: <String>[
          if (food.isNotEmpty) 'Favourite food: ${patient.favouriteFood}',
          'Everyday procedures are familiar and low-stress',
        ],
      ));
    }

    if (patient.family.isNotEmpty) {
      candidates.add(Recommendation(
        gameId: GameId.story,
        headline: 'Finish the Story',
        reason:
            'I have a picture of ${patient.family.first.name}. Would you tell me a little about it?',
        evidence: <String>[
          'Important person: ${patient.family.first.name} (${patient.family.first.relation})',
          'Personal photographs improve engagement',
        ],
      ));
    }

    if (patient.location.toLowerCase().contains('assam') ||
        patient.location.toLowerCase().contains('manipur') ||
        patient.location.isNotEmpty) {
      candidates.add(Recommendation(
        gameId: GameId.melody,
        headline: 'Melody of the Valleys',
        reason: 'Shall we listen to the dhol for a while, and play it back together?',
        evidence: <String>[
          'Location: ${patient.location}',
          'Regional instruments used instead of generic tones',
        ],
      ));
      candidates.add(Recommendation(
        gameId: GameId.familiarPlace,
        headline: 'Familiar Place Explorer',
        reason: 'Let us walk through a house that looks like yours and find a few things.',
        evidence: <String>[
          'Location: ${patient.location}',
          'House layout drawn from her own daily routine',
        ],
      ));
    }

    if (candidates.isEmpty) {
      return const Recommendation(
        gameId: GameId.memoryCards,
        headline: 'NER Memory Cards',
        reason: 'Shall we start with something gentle, finding pairs?',
        evidence: <String>['Default starting activity for a new profile'],
      );
    }

    // Prefer something not already done today, and not the one just played.
    for (final Recommendation r in candidates) {
      if (r.gameId == avoid) continue;
      if ((completedToday[r.gameId] ?? 0) > 0) continue;
      return r;
    }
    return candidates.firstWhere((Recommendation r) => r.gameId != avoid,
        orElse: () => candidates.first);
  }

  /// Ordered "for you" list used to sort the game hub.
  List<GameId> priorityOrder(Patient patient) {
    final List<GameId> order = <GameId>[];
    final String occ = '${patient.occupation} ${patient.favouriteActivity}'.toLowerCase();
    if (occ.contains('weav') || occ.contains('sew') || occ.contains('cloth')) {
      order.add(GameId.weaves);
    }
    if (occ.contains('cook') || patient.favouriteFood.isNotEmpty) order.add(GameId.procedure);
    if (patient.family.isNotEmpty) order.add(GameId.story);
    if (patient.location.isNotEmpty) order.add(GameId.melody);
    for (final GameDefinition g in MockData.games) {
      if (!order.contains(g.id)) order.add(g.id);
    }
    return order;
  }

  /// Content used inside the procedure game, personalised by level.
  String procedureTitle(Patient patient, int level) {
    if (level >= 5 && patient.occupation.toLowerCase().contains('weav')) {
      return 'Dressing the loom';
    }
    if (level >= 3 && patient.favouriteFood.toLowerCase().contains('pitha')) {
      return 'Making til pitha';
    }
    return 'Making tea';
  }

  /// One-line explanation of how the profile shaped a screen. Used in the
  /// caregiver view to make the personalisation legible.
  List<String> personalisationSummary(Patient patient) {
    return <String>[
      if (patient.occupation.isNotEmpty)
        '${patient.occupation} → weaving patterns and loom procedures appear in her activities',
      if (patient.family.isNotEmpty)
        '${patient.family.first.name} → the companion asks after her by name',
      if (patient.favouriteFood.isNotEmpty)
        '${patient.favouriteFood} → cooking steps replace generic tasks',
      if (patient.location.isNotEmpty)
        '${patient.location} → dhol, pepa and gogona replace generic sounds',
      if (patient.language.isNotEmpty)
        '${patient.language} → content and voice prompts use her language',
    ];
  }
}
