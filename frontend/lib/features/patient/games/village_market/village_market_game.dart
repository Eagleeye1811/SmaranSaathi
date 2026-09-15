import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/content_labels.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';
import '../widgets/game_level_path_map.dart';
import 'market_map.dart';
import 'market_stalls.dart';

/// The Village Market Adventure — executive function, planning and working
/// memory, framed as a mini adventure rather than a shopping test.
///
/// The whole point is a real, concrete plan the patient can hold onto: a
/// shopping list, visible on screen the entire time rather than only ever
/// spoken once; a starting budget, stated up front; and a basket that
/// spends down that budget one purchase at a time. One stall's items are on
/// screen at a time — the patient walks the market stall by stall — and the
/// trip naturally ends once every listed item is found or the money runs
/// out, whichever comes first. No item pick is ever "wrong" (an item off
/// the list still goes in the basket, just doesn't count toward the list),
/// no timer runs against the patient, and there is no reachable `completed:
/// false` path — a session is either warmly completed or, if the patient
/// backs out early via the header close button, simply not recorded.
class VillageMarketGame extends StatefulWidget {
  const VillageMarketGame({super.key});

  @override
  State<VillageMarketGame> createState() => _VillageMarketGameState();
}

enum _Phase { intro, listMention, explore }

class _VillageMarketGameState extends State<VillageMarketGame> {
  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.villageMarket);
  late final AppState _state = AppScope.read(context);
  late final int _maxUnlockedLevel = _state.levelOf(GameId.villageMarket);
  late int _selectedLevel;
  late final String _listGiver = shoppingListGiver(_state.patient);

  _Phase _phase = _Phase.intro;

  String? _selectedStallId;
  final Set<String> _visitedStalls = <String>{};
  final Set<String> _basket = <String>{};
  final List<String> _nudgesShown = <String>[];
  int _hintTier = 0;

  bool _autoNudgeFired = false;
  bool _listCompleteShown = false;
  bool _fundsLowShown = false;
  bool _rainShown = false;
  bool _budgetShown = false;
  bool _overfullShown = false;
  bool _headingHome = false;

  String? _feedback;
  bool _feedbackPositive = true;
  String? _narrative;
  final List<String> _narrativeQueue = <String>[];

  // ── level gating ─────────────────────────────────────────────────────────
  // Kept in one place and checked directly against `levelDescription` below,
  // rather than drifting apart the way the level pickers in the six earlier
  // activities did.

  /// One glyph per level of market-readiness, from a light basket to the
  /// coin purse the higher levels actually start watching.
  IconData _levelIcon(int lvl) => switch (lvl) {
        1 => Icons.shopping_basket_outlined,
        2 => Icons.storefront_outlined,
        3 => Icons.local_grocery_store_rounded,
        4 => Icons.account_balance_wallet_rounded,
        _ => Icons.emoji_events_rounded,
      };

  int _stallCountFor(int lvl) => switch (lvl) {
        1 => 3,
        2 => 4,
        3 => 5,
        4 => 5,
        _ => 6,
      };

  int _nudgeBudgetFor(int lvl) => switch (lvl) {
        1 => 3,
        2 => 2,
        3 => 2,
        _ => 1,
      };

  bool _rainEnabledFor(int lvl) => lvl >= 3;

  /// The day's total, stated up front at every level — see
  /// [_buildListMention]. Matches the ₹150-spent trigger point already used
  /// by [_maybeShowNarrativeCues] for [gameVillageMarketBudgetMessage]'s
  /// "only ₹200 left": 350 - 150 = 200, so that line stays true.
  static const int _budgetTotal = 350;

  int get _stallCount => _stallCountFor(_selectedLevel);
  int get _nudgeBudget => _nudgeBudgetFor(_selectedLevel);
  bool get _rainEnabled => _rainEnabledFor(_selectedLevel);

  /// What is left of [_budgetTotal] — never negative, so a purchase that
  /// would overdraw it is simply declined (see [_tapItem]) rather than ever
  /// letting this read as an alarming negative number.
  int get _budgetRemaining => (_budgetTotal - _basketTotal).clamp(0, _budgetTotal);

  late final List<Stall> _stalls = MarketContent.layoutFor(_stallCount);

  double get _basketFullness => (_basket.length / 6).clamp(0, 1);

  int get _basketTotal {
    int total = 0;
    for (final String id in _basket) {
      total += MarketContent.itemById(id).price;
    }
    return total;
  }

  MarketItem? get _nextMissingNeeded {
    for (final MarketItem i in MarketContent.neededItems) {
      if (!_basket.contains(i.id)) return i;
    }
    return null;
  }

  /// True once the list can no longer be completed — every still-missing
  /// needed item now costs more than what's left to spend. The other half
  /// of the trip's natural ending, alongside [_nextMissingNeeded] going
  /// null: "buy everything on the list, or run out of money trying."
  bool get _fundsExhaustedForList {
    final Iterable<MarketItem> missing =
        MarketContent.neededItems.where((MarketItem i) => !_basket.contains(i.id));
    if (missing.isEmpty) return false;
    return missing.every((MarketItem i) => i.price > _budgetRemaining);
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.villageMarket);
  }

  void _changeLevel(int lvl) => setState(() => _selectedLevel = lvl);

  void _selectStall(String id) {
    if (_headingHome) return;
    setState(() {
      _selectedStallId = id;
      _visitedStalls.add(id);
      _feedback = null;
    });
    _maybeShowNarrativeCues();
  }

  void _tapItem(MarketItem item) {
    if (_headingHome) return;
    final AppLocalizations l = AppLocalizations.of(context);
    if (_basket.contains(item.id)) {
      setState(() {
        _feedbackPositive = true;
        _feedback = l.gameVillageMarketAlreadyHaveIt;
      });
      return;
    }
    // The one real constraint in an otherwise errorless game: the budget is
    // finite, so a purchase that would overdraw it is gently declined —
    // never added to the basket, never charged — rather than letting
    // `_budgetRemaining` go negative.
    if (item.price > _budgetRemaining) {
      setState(() {
        _feedbackPositive = false;
        _feedback = l.gameVillageMarketNotEnoughMoney;
      });
      return;
    }
    _tracker.attempts++;
    final bool needed = item.role == MarketItemRole.needed;
    setState(() {
      _basket.add(item.id);
      if (needed) {
        _tracker.correct++;
        _hintTier = 0;
        _feedbackPositive = true;
        _feedback = l.gameVillageMarketPickedUp(item.name);
      } else {
        _feedbackPositive = false;
        _feedback = l.gameVillageMarketInterestingOne;
      }
    });
    _maybeShowNarrativeCues();
  }

  /// Checks all five queued narrative triggers on every call rather than
  /// stopping at the first one that fires: an early `return` after the
  /// first match meant that if two conditions became true on the same tap —
  /// most plausibly the budget and overfull cues together — the second
  /// one's "shown" flag stayed false and, if that tap was immediately
  /// followed by "Head home" with no further interaction, its message never
  /// got queued at all. Cues that can't display immediately (one is already
  /// showing) are queued and drained one at a time instead of being
  /// skipped.
  void _maybeShowNarrativeCues() {
    final AppLocalizations l = AppLocalizations.of(context);
    if (!_autoNudgeFired && _visitedStalls.length >= 2 && _nextMissingNeeded != null) {
      _autoNudgeFired = true;
      setState(() => _nudgesShown.add(l.gameVillageMarketNudgeAuto(_listGiver)));
    }
    // The one moment worth celebrating on its own: everything on the list is
    // found. Checked as soon as it becomes true, not gated on stall count
    // like the auto-nudge above — there is no reason to delay good news.
    if (!_listCompleteShown && _nextMissingNeeded == null) {
      _listCompleteShown = true;
      _queueNarrative(l.gameVillageMarketListComplete);
    }
    // The other natural ending: money ran out before the list did. Checked
    // after list-completion so the two can never both fire for the same
    // state (one requires the list to still have a gap, the other requires
    // it not to).
    if (!_fundsLowShown && _fundsExhaustedForList) {
      _fundsLowShown = true;
      _queueNarrative(l.gameVillageMarketFundsLow);
    }
    if (_rainEnabled && !_rainShown && _visitedStalls.length >= 2) {
      _rainShown = true;
      _queueNarrative(l.gameVillageMarketRainMessage);
    }
    if (!_budgetShown && _basketTotal >= 150) {
      _budgetShown = true;
      _queueNarrative(l.gameVillageMarketBudgetMessage);
    }
    if (!_overfullShown && _basket.length > 6) {
      _overfullShown = true;
      _queueNarrative(l.gameVillageMarketOverfullMessage);
    }
  }

  void _queueNarrative(String message) {
    _narrativeQueue.add(message);
    if (_narrative == null) _advanceNarrativeQueue();
  }

  void _advanceNarrativeQueue() {
    if (_narrativeQueue.isEmpty) return;
    final String message = _narrativeQueue.removeAt(0);
    setState(() => _narrative = message);
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted || _narrative != message) return;
      setState(() => _narrative = null);
      _advanceNarrativeQueue();
    });
  }

  void _useHint() {
    final MarketItem? target = _nextMissingNeeded;
    if (target == null) return;
    if (_tracker.hints >= _nudgeBudget) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final String msg =
        _hintTier == 0 ? l.gameVillageMarketNudgeCategory : l.gameVillageMarketNudgeItem(target.name);
    setState(() {
      _tracker.hints++;
      _hintTier = (_hintTier + 1).clamp(0, 1);
      _nudgesShown.add(msg);
    });
  }

  void _headHome() {
    if (_headingHome) return;
    final AppLocalizations l = AppLocalizations.of(context);
    // Any still-queued narrative cue is dropped here deliberately, in favour
    // of the trip-complete message — the game is ending, so a "watch the
    // coin purse" reminder popping up after "shopping trip is complete"
    // would read as a mistake, not a nicety.
    _narrativeQueue.clear();
    setState(() {
      _headingHome = true;
      _narrative = l.gameVillageMarketTripComplete;
    });
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _finish();
    });
  }

  /// Fraction (0-100) of the mentioned list actually found and kept.
  ///
  /// This exists because `GameTracker`'s `accuracy` (`correct/attempts`) and
  /// `memory` (hint-based) formulas both only look at taps that actually
  /// happened: a patient who taps exactly one needed item, gets it right
  /// first try, and heads home immediately would score `accuracy == 100`
  /// (1 correct of 1 attempt) and `memory == 100` (no hints used) despite
  /// abandoning two of the three needed items — precision can't see items
  /// that were never attempted at all. `_finish` blends this recall figure
  /// into both so a minimal-effort basket can't read as a perfect one.
  double get _listCompletion =>
      MarketContent.neededItems.where((MarketItem i) => _basket.contains(i.id)).length /
      MarketContent.neededItems.length *
      100;

  /// [GamePerformance] keeps its usual three fields, but this game gives
  /// them a different, honest meaning: `accuracy` blends list-completion
  /// recall with per-tap precision, `memory` blends the same recall with
  /// `GameTracker`'s hint-based formula, and `focus` is blended with budget
  /// restraint since `mistakes` is deliberately always 0 here.
  ///
  /// An empty basket reports 0, not 100: `GameTracker.accuracy` defaults to
  /// 100 when `attempts == 0` (a reasonable default for games where "no
  /// mistakes yet" is neutral), but here it would otherwise let a patient
  /// who taps nothing and immediately heads home score a perfect run —
  /// rewarding disengagement rather than reflecting it honestly to the
  /// caregiver who reads this figure.
  double _budgetRestraintScore() {
    if (_basket.isEmpty) return 0;
    final int neededFound =
        MarketContent.neededItems.where((MarketItem i) => _basket.contains(i.id)).length;
    final int impulseCount = _basket
        .map(MarketContent.itemById)
        .where((MarketItem i) => i.role == MarketItemRole.impulse)
        .length;
    final double completion = neededFound / MarketContent.neededItems.length * 40;
    final double restraint = (1 - (impulseCount / _basket.length)).clamp(0, 1) * 60;
    return (completion + restraint).clamp(0, 100);
  }

  void _finish() {
    final AppLocalizations l = AppLocalizations.of(context);
    final GamePerformance base = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.villageMarket, _selectedLevel),
      completed: true,
    );
    final double restraint = _budgetRestraintScore();
    final double completion = _listCompletion;
    // Same reasoning as `_listCompletion`'s doc comment: `base.accuracy` and
    // `base.memory` each default to a high score for a minimal-effort
    // basket, so both are blended 50/50 with recall of the mentioned list
    // rather than trusted on their own. An empty basket still reports 0
    // outright rather than "50% of nothing".
    final GamePerformance p = GamePerformance(
      accuracy: _basket.isEmpty ? 0 : (base.accuracy * 0.5 + completion * 0.5).clamp(0, 100),
      focus: (base.focus * 0.5 + restraint * 0.5).clamp(0, 100),
      memory: _basket.isEmpty ? 0 : (base.memory * 0.5 + completion * 0.5).clamp(0, 100),
      hintsUsed: base.hintsUsed,
      mistakes: base.mistakes,
      seconds: base.seconds,
      completed: true,
      attempts: base.attempts,
      correct: base.correct,
      responseMillis: base.responseMillis,
    );
    final AdaptiveDecision d = _state.finishGame(GameId.villageMarket, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _selectedLevel,
          highlights: <({String label, String value})>[
            (label: l.gameVillageMarketStallsVisited, value: '${_visitedStalls.length}'),
            (label: l.gameVillageMarketThingsBroughtHome, value: '${_basket.length}'),
            (label: l.gameVillageMarketNudgesFromMitra, value: '${_tracker.hints}'),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.intro => _buildIntro(),
      _Phase.listMention => _buildListMention(),
      _Phase.explore => _buildExplore(),
    };
  }

  Widget _buildIntro() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: l.gameVillageMarketIntroMessage,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: l.gameVillageMarketStartWalking,
        icon: Icons.storefront_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.listMention),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Level Path Map ──────────────────────────────────────
            GameLevelPathMap(
              gameId: GameId.villageMarket,
              accentColor: _game.accent,
              selectedLevel: _selectedLevel,
              maxUnlockedLevel: _maxUnlockedLevel,
              onLevelSelected: _changeLevel,
              levels: <GameLevelItem>[
                for (int lvl = 1; lvl <= AdaptiveDifficultyService.maxLevel; lvl++)
                  GameLevelItem(
                    levelNum: lvl,
                    title: localizedLevelDescription(l, GameId.villageMarket, lvl),
                    subtitle: l.gameVillageMarketStallsOpen(_stallCountFor(lvl)),
                    icon: _levelIcon(lvl),
                    stars: lvl == 1 ? 3 : (lvl <= _maxUnlockedLevel ? 2 : 0),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameVillageMarketCategoryLabel, style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(_game.localizedName(l), style: AppText.h1.sized(24)),
                  const SizedBox(height: 8),
                  Text(l.gameVillageMarketInstructions, style: AppText.bodySmall),
                  const SizedBox(height: 14),
                  // Recomputed from the level, not read off `_stalls` —
                  // that field locks in on first access, before a level
                  // chosen here has a chance to change it.
                  Builder(builder: (BuildContext context) {
                    final List<Stall> preview = MarketContent.layoutFor(_stallCount);
                    return SizedBox(
                      height: 66,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: preview.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(width: 10),
                        itemBuilder: (BuildContext context, int i) => SizedBox(
                          width: 56,
                          child: Column(
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: preview[i].awning.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: preview[i].awning.withValues(alpha: 0.4)),
                                ),
                                child: Icon(preview[i].icon, size: 20, color: preview[i].awning),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                preview[i].name,
                                style: AppText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListMention() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      // The budget is stated up front at every level, matching the list
      // itself being on screen the whole time — both are the plan the
      // patient works from, not a number revealed only once spending
      // pressure shows up.
      companionMessage: l.gameVillageMarketListMentionWithBudget(_listGiver, _budgetTotal),
      companionState: CompanionState.thinking,
      bottom: BigButton(
        label: l.gameVillageMarketListMentionContinue,
        icon: Icons.arrow_forward_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.explore),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _shoppingListPanel(),
            const SizedBox(height: Insets.md),
            MmCard(
              padding: const EdgeInsets.all(Insets.md),
              child: Row(
                children: <Widget>[
                  Icon(Icons.shopping_basket_rounded, color: _game.accent, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.gameVillageMarketInstructions,
                      style: AppText.bodySmall.tint(AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplore() {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final Stall? selected =
        _selectedStallId == null ? null : _stalls.firstWhere((Stall s) => s.id == _selectedStallId);

    return GameShell(
      game: _game,
      level: _selectedLevel,
      hintsLeft: (_nudgeBudget - _tracker.hints).clamp(0, _nudgeBudget),
      hintsTotal: _nudgeBudget,
      onHint: (_nextMissingNeeded == null || _headingHome) ? null : _useHint,
      companionMessage: _narrative,
      companionState: CompanionState.gentle,
      scrollable: !wide,
      bottom: BigButton(
        label: l.gameVillageMarketHeadHome,
        icon: Icons.home_rounded,
        color: _game.accent,
        onPressed: _headingHome ? null : _headHome,
      ),
      child: wide ? _wideLayout(selected) : _narrowLayout(selected),
    );
  }

  // ── layouts ──────────────────────────────────────────────────────────────

  Widget _narrowLayout(Stall? selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _mapPanel(mapHeight: 190),
          const SizedBox(height: Insets.md),
          _shoppingListPanel(),
          const SizedBox(height: Insets.md),
          _basketPanel(),
          const SizedBox(height: Insets.md),
          if (_nudgesShown.isNotEmpty) ...<Widget>[
            _nudgePanel(),
            const SizedBox(height: Insets.md),
          ],
          if (_feedback != null) ...<Widget>[
            FeedbackBubble(message: _feedback!, positive: _feedbackPositive),
            const SizedBox(height: Insets.md),
          ],
          selected != null ? _stallPanel(selected, columns: 3) : _emptyStallPrompt(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _wideLayout(Stall? selected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 250,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _shoppingListPanel(),
                  const SizedBox(height: Insets.md),
                  _basketPanel(),
                  const SizedBox(height: Insets.md),
                  _nudgePanel(alwaysShow: true),
                ],
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _mapPanel(mapHeight: 260),
                  if (_feedback != null) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    FeedbackBubble(message: _feedback!, positive: _feedbackPositive),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: selected != null ? _stallPanel(selected, columns: 2) : _emptyStallPrompt(),
            ),
          ),
        ],
      ),
    );
  }

  // ── panels ───────────────────────────────────────────────────────────────

  Widget _mapPanel({required double mapHeight}) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.gameVillageMarketCategoryLabel, style: AppText.overline),
          const SizedBox(height: 8),
          MarketMap(
            stalls: _stalls,
            selectedId: _selectedStallId,
            visited: _visitedStalls,
            onSelect: _selectStall,
            height: mapHeight,
          ),
        ],
      ),
    );
  }

  Widget _basketPanel() {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: Icons.shopping_basket_rounded, color: _game.accent, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(l.gameVillageMarketBasketLabel, style: AppText.overline)),
              Text('${_basket.length}', style: AppText.body.wght(800).tint(_game.accent)),
            ],
          ),
          const SizedBox(height: 10),
          MeterBar(value: _basketFullness, color: _game.accent, height: 8),
          const SizedBox(height: 8),
          Text(
            l.gameVillageMarketBudgetRemaining(_budgetRemaining),
            style: AppText.caption.wght(700).tint(_game.accent),
          ),
        ],
      ),
    );
  }

  /// The list itself, visible on screen throughout the whole trip — not
  /// just mentioned once at the start. Each item shows a check the moment
  /// it lands in the basket, so "what's left to find" never depends on
  /// memory alone.
  Widget _shoppingListPanel() {
    final AppLocalizations l = AppLocalizations.of(context);
    final int found =
        MarketContent.neededItems.where((MarketItem i) => _basket.contains(i.id)).length;
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: Icons.checklist_rounded, color: _game.accent, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(l.gameVillageMarketListLabel, style: AppText.overline)),
              Text(
                l.gameVillageMarketListProgress(found, MarketContent.neededItems.length),
                style: AppText.caption.wght(700).tint(_game.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final MarketItem item in MarketContent.neededItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    _basket.contains(item.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 20,
                    color: _basket.contains(item.id) ? AppColors.success : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Icon(item.icon, size: 18, color: item.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: AppText.body.wght(600).tint(
                          _basket.contains(item.id) ? AppColors.inkMuted : AppColors.ink),
                    ),
                  ),
                  Text(l.gameVillageMarketPriceTag(item.price), style: AppText.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _nudgePanel({bool alwaysShow = false}) {
    if (_nudgesShown.isEmpty && !alwaysShow) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context);
    final int left = (_nudgeBudget - _tracker.hints).clamp(0, _nudgeBudget);
    return MmCard(
      padding: const EdgeInsets.all(14),
      color: AppColors.accentTint,
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text(l.gameVillageMarketHintsLeft(left), style: AppText.overline.tint(AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_nudgesShown.isEmpty)
            Text(l.gameVillageMarketTapLightbulb, style: AppText.bodySmall.tint(AppColors.ink))
          else
            for (int i = 0; i < _nudgesShown.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_nudgesShown[i], style: AppText.body.wght(600).tint(AppColors.ink)),
              ),
        ],
      ),
    );
  }

  Widget _stallPanel(Stall stall, {required int columns}) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SoftIcon(icon: stall.icon, color: stall.awning, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.gameVillageMarketYouAreAt, style: AppText.overline),
                    const SizedBox(height: 2),
                    Text(stall.name, style: AppText.h2.sized(21)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.gameVillageMarketTapAnything, style: AppText.caption),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns == 2 ? 0.86 : 0.72,
            ),
            itemCount: stall.items.length,
            itemBuilder: (BuildContext context, int i) {
              final MarketItem item = stall.items[i];
              return MarketItemTile(
                item: item,
                inBasket: _basket.contains(item.id),
                onTap: _headingHome ? null : () => _tapItem(item),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyStallPrompt() {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          const Icon(Icons.storefront_rounded, size: 34, color: AppColors.inkMuted),
          const SizedBox(height: 10),
          Text(l.gameVillageMarketTapAStall, textAlign: TextAlign.center, style: AppText.bodySmall),
        ],
      ),
    );
  }
}
