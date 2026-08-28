import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/game.dart';
import 'familiar_place/familiar_place_game.dart';
import 'melody/melody_game.dart';
import 'memory_cards/memory_cards_game.dart';
import 'procedure/procedure_game.dart';
import 'story/story_game.dart';
import 'weaves/weaves_game.dart';

/// Single entry point for starting an activity, so the home screen, the hub
/// and the reminders can all launch the same experience.
class GameLauncher {
  const GameLauncher._();

  static Widget build(GameId id) => switch (id) {
        GameId.procedure => const ProcedureGame(),
        GameId.story => const StoryGame(),
        GameId.familiarPlace => const FamiliarPlaceGame(),
        GameId.melody => const MelodyGame(),
        GameId.weaves => const WeavesGame(),
        GameId.memoryCards => const MemoryCardsGame(),
      };

  static Future<void> open(BuildContext context, GameId id) =>
      Nav.open(context, build(id));
}
