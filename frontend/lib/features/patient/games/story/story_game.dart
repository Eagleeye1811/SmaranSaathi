import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/game.dart';
import '../../../../core/models/patient.dart';
import '../../../../core/services/adaptive_difficulty_service.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/illustration.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../game_result_screen.dart';
import '../game_shell.dart';

/// A choice the patient can make in a story or scenario, with the simulated
/// semantic evaluation the language model would produce for it.
class StoryChoice {
  const StoryChoice({
    required this.text,
    required this.quality,
    required this.evaluation,
    required this.reply,
  });

  final String text;

  /// 0..1 — how well this continuation holds together.
  final double quality;

  /// The "✓ Relevant / ✓ Logical continuation" style read-out.
  final List<({String label, bool ok})> evaluation;
  final String reply;
}

class StoryRound {
  const StoryRound({
    required this.mode,
    required this.prompt,
    required this.question,
    required this.choices,
    this.sceneId,
    this.subtitle = '',
  });

  final String mode;
  final String prompt;
  final String question;
  final List<StoryChoice> choices;
  final String? sceneId;
  final String subtitle;
}

/// Finish the Story — story recall, everyday reasoning, and open storytelling
/// about the patient's own photographs.
///
/// The semantic evaluation shown after each answer is simulated: the scores
/// are attached to the authored choices rather than produced by a model.
class StoryGame extends StatefulWidget {
  const StoryGame({super.key});

  @override
  State<StoryGame> createState() => _StoryGameState();
}

enum _Phase { intro, story }

class _StoryGameState extends State<StoryGame> {
  final GameTracker _tracker = GameTracker();
  final GameDefinition _game = MockData.game(GameId.story);
  late final AppState _state = AppScope.read(context);
  late final int _maxUnlockedLevel = _state.levelOf(GameId.story);
  late int _selectedLevel;
  late final List<StoryRound> _rounds = _buildRounds(_state.patient);

  _Phase _phase = _Phase.intro;
  int _index = 0;
  StoryChoice? _chosen;
  bool _analysing = false;


  bool get _onPhotoRound => _index == _rounds.length;

  // Personal-photo round
  final Set<int> _fragments = <int>{};
  bool _storyEvaluated = false;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _state.levelOf(GameId.story);
  }

  void _changeLevel(int lvl) {
    setState(() {
      _selectedLevel = lvl;
    });
  }


  List<StoryRound> _buildRounds(Patient p) {
    final String daughter = p.family.isEmpty ? 'her daughter' : p.family.first.name;
    return <StoryRound>[
      StoryRound(
        mode: 'Story recall',
        sceneId: 'market',
        prompt:
            '${p.shortName.isEmpty ? 'Aama' : p.shortName} went to the market on Thursday morning. '
            'She bought rice and vegetables, and stopped to talk with Nirmali by the fish stalls. '
            'On the way home…',
        question: 'What do you think happened next?',
        choices: const <StoryChoice>[
          StoryChoice(
            text: 'She shared the vegetables with her neighbour.',
            quality: 0.92,
            evaluation: <({String label, bool ok})>[
              (label: 'Relevant to the story', ok: true),
              (label: 'Logical continuation', ok: true),
              (label: 'Good recall of characters', ok: true),
            ],
            reply:
                'That sounds just like you. Nirmali has walked home with you for thirty years.',
          ),
          StoryChoice(
            text: 'It began to rain, so she waited under the banyan tree.',
            quality: 0.85,
            evaluation: <({String label, bool ok})>[
              (label: 'Relevant to the story', ok: true),
              (label: 'Logical continuation', ok: true),
              (label: 'Introduces a new detail', ok: true),
            ],
            reply: 'A good answer. Thursday markets and sudden rain go together.',
          ),
          StoryChoice(
            text: 'She flew to the mountains on a boat.',
            quality: 0.32,
            evaluation: <({String label, bool ok})>[
              (label: 'Relevant to the story', ok: false),
              (label: 'Logical continuation', ok: false),
              (label: 'Kept the characters', ok: true),
            ],
            reply:
                'That is an imaginative one! Let us stay on the road home for now.',
          ),
        ],
      ),
      const StoryRound(
        mode: 'Everyday reasoning',
        sceneId: 'market',
        prompt: 'You have walked to the market, but when you reach the stall you '
            'realise you have forgotten your purse at home.',
        question: 'What would you do?',
        subtitle: 'There is no wrong answer — tell me what feels right.',
        choices: <StoryChoice>[
          StoryChoice(
            text: 'Go home and fetch the purse.',
            quality: 0.95,
            evaluation: <({String label, bool ok})>[
              (label: 'Practical decision', ok: true),
              (label: 'Safe choice', ok: true),
              (label: 'Clear reasoning', ok: true),
            ],
            reply: 'Sensible. The house is not far, and the stall will still be there.',
          ),
          StoryChoice(
            text: 'Ask the shopkeeper if I can pay tomorrow.',
            quality: 0.82,
            evaluation: <({String label, bool ok})>[
              (label: 'Practical decision', ok: true),
              (label: 'Uses social knowledge', ok: true),
              (label: 'Depends on trust', ok: false),
            ],
            reply:
                'That works too — you have bought rice from him for many years.',
          ),
          StoryChoice(
            text: 'Take the vegetables anyway.',
            quality: 0.30,
            evaluation: <({String label, bool ok})>[
              (label: 'Practical decision', ok: false),
              (label: 'Safe choice', ok: false),
              (label: 'Considered consequences', ok: false),
            ],
            reply: 'Let us think again. What would you say to the shopkeeper?',
          ),
          StoryChoice(
            text: 'Leave the market and come back another day.',
            quality: 0.62,
            evaluation: <({String label, bool ok})>[
              (label: 'Practical decision', ok: true),
              (label: 'Safe choice', ok: true),
              (label: 'Solves today\'s problem', ok: false),
            ],
            reply: 'That is safe, though there would be no rice for dinner tonight.',
          ),
        ],
      ),
      StoryRound(
        mode: 'Story recall',
        sceneId: 'river',
        prompt:
            'The ferry to Majuli was full that morning. $daughter held the basket while '
            'the boatman pushed away from the ghat. Halfway across the river…',
        question: 'What do you think happened next?',
        choices: const <StoryChoice>[
          StoryChoice(
            text: 'The children began to sing a Bihu song.',
            quality: 0.90,
            evaluation: <({String label, bool ok})>[
              (label: 'Relevant to the story', ok: true),
              (label: 'Logical continuation', ok: true),
              (label: 'Rich cultural detail', ok: true),
            ],
            reply: 'I can almost hear it. The river carries a song a long way.',
          ),
          StoryChoice(
            text: 'A flock of birds crossed in front of the boat.',
            quality: 0.86,
            evaluation: <({String label, bool ok})>[
              (label: 'Relevant to the story', ok: true),
              (label: 'Logical continuation', ok: true),
              (label: 'Vivid observation', ok: true),
            ],
            reply: 'Lovely. The river is full of birds in the cold months.',
          ),
          StoryChoice(
            text: 'I am not sure.',
            quality: 0.5,
            evaluation: <({String label, bool ok})>[
              (label: 'Relevant to the story', ok: true),
              (label: 'Logical continuation', ok: false),
              (label: 'Honest answer', ok: true),
            ],
            reply: 'That is perfectly fine. Not knowing is allowed here.',
          ),
        ],
      ),
    ];
  }

  List<String> get _fragmentOptions {
    final String name = _state.patient.family.isEmpty
        ? 'my daughter'
        : _state.patient.family.first.name;
    return <String>[
      'This is $name',
      'She is my daughter',
      'That was the day she finished college',
      'I wove the shawl she is wearing',
      'We had pitha afterwards',
      'Her father took the photograph',
      'She calls me every evening',
    ];
  }

  void _choose(StoryChoice c) {
    _tracker.attempts++;
    if (c.quality >= 0.6) {
      _tracker.correct++;
    } else {
      _tracker.mistakes++;
    }
    setState(() {
      _chosen = c;
      _analysing = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _analysing = false);
    });
  }

  void _next() {
    setState(() {
      _chosen = null;
      _index++;
    });
  }

  void _evaluateStory() {
    _tracker.attempts++;
    if (_fragments.length >= 3) {
      _tracker.correct++;
    } else {
      _tracker.mistakes++;
    }
    setState(() {
      _analysing = true;
      _storyEvaluated = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _analysing = false;
          _storyEvaluated = true;
        });
      }
    });
  }

  void _finish() {
    final GamePerformance p = _tracker.build(
      expectedSeconds: AdaptiveDifficultyService.expectedSeconds(GameId.story, _selectedLevel),
    );
    final AdaptiveDecision d = _state.finishGame(GameId.story, p);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameResultScreen(
          game: _game,
          performance: p,
          decision: d,
          playedLevel: _selectedLevel,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) {
      return _buildIntro();
    }

    if (_onPhotoRound) {
      return _buildPhotoRound();
    }

    return _buildStoryRound(_rounds[_index]);
  }

  Widget _buildIntro() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: _selectedLevel,
      companionMessage: l.gameStoryIntroMessage,
      companionState: CompanionState.happy,
      bottom: BigButton(
        label: l.gameStoryStartButton,
        icon: Icons.play_arrow_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.story),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MmCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameMemoryCardsChooseLevel, style: AppText.overline),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            levelNum: 1,
                            title: l.gameStoryLevelSimple,
                            subtitle: l.gameStorySubtitleStoryRecall,
                            unlocked: 1 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 1,
                            onTap: (1 <= _maxUnlockedLevel) ? () => _changeLevel(1) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            levelNum: 2,
                            title: l.gameStoryLevelGuided,
                            subtitle: l.gameStorySubtitleStoryRecall,
                            unlocked: 2 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 2,
                            onTap: (2 <= _maxUnlockedLevel) ? () => _changeLevel(2) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            levelNum: 3,
                            title: l.gameStoryLevelAdvanced,
                            subtitle: l.gameStorySubtitleOpenStory,
                            unlocked: 3 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 3,
                            onTap: (3 <= _maxUnlockedLevel) ? () => _changeLevel(3) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            levelNum: 4,
                            title: l.gameStoryLevelOpen,
                            subtitle: l.gameStorySubtitleFreeMemory,
                            unlocked: 4 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 4,
                            onTap: (4 <= _maxUnlockedLevel) ? () => _changeLevel(4) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: LevelOptionChip(
                            levelNum: 5,
                            title: l.gameStoryLevelDeepMemory,
                            subtitle: l.gameStorySubtitleFullRecall,
                            unlocked: 5 <= _maxUnlockedLevel,
                            selected: _selectedLevel == 5,
                            onTap: (5 <= _maxUnlockedLevel) ? () => _changeLevel(5) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameStoryCategoryLabel, style: AppText.overline),
                  const SizedBox(height: 8),
                  Text(l.gameStoryTitle, style: AppText.h1.sized(26)),
                  const SizedBox(height: 8),
                  Text(
                    l.gameStoryInstructions,
                    style: AppText.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryRound(StoryRound round) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int total = _rounds.length + 1;
    return GameShell(
      game: _game,
      level: _selectedLevel,

      stepLabel: l.gameStoryPartOfTotal(_index + 1, total),
      progress: (_index + (_chosen != null ? 0.6 : 0)) / total,
      companionMessage: _chosen == null
          ? round.question
          : (_analysing ? l.gameStoryThinkingAboutAnswer : _chosen!.reply),
      companionState: _chosen == null
          ? CompanionState.listening
          : (_analysing ? CompanionState.thinking : CompanionState.happy),
      bottom: _chosen != null && !_analysing
          ? BigButton(
              label: _index == _rounds.length - 1 ? l.gameStoryOneLastThing : l.gameStoryNextStory,
              icon: Icons.arrow_forward_rounded,
              color: _game.accent,
              onPressed: _next,
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MmCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (round.sceneId != null)
                    SizedBox(
                      height: 132,
                      child: SceneImage(sceneId: round.sceneId!, radius: 0, fit: false),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        PillTag(label: round.mode, color: _game.accent, dense: true),
                        const SizedBox(height: 12),
                        Text(round.prompt, style: AppText.patientBody.sized(19)),
                        if (round.subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(round.subtitle, style: AppText.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            if (_chosen == null) ...<Widget>[
              Text(l.gameStoryChooseWhatHappensNext, style: AppText.overline),
              const SizedBox(height: 10),
              for (final StoryChoice c in round.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceCard(
                    text: c.text,
                    accent: _game.accent,
                    onTap: () => _choose(c),
                  ),
                ),
            ] else
              _EvaluationPanel(
                analysing: _analysing,
                answer: _chosen!.text,
                rows: _chosen!.evaluation,
                accent: _game.accent,
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoRound() {
    final AppLocalizations l = AppLocalizations.of(context);
    final Patient p = _state.patient;
    final MemoryAsset asset = p.assets.isNotEmpty
        ? p.assets.first
        : MemoryAsset(
            id: 'x',
            title: l.gameStoryDefaultPhotoTitle,
            sceneId: 'portrait_priya',
            kind: MemoryAssetKind.person,
          );
    final List<String> options = _fragmentOptions;
    final int total = _rounds.length + 1;

    return GameShell(
      game: _game,
      level: _selectedLevel,
      stepLabel: l.gameStoryPartOfTotal(total, total),
      progress: _storyEvaluated ? 1 : 0.86,
      companionMessage: _storyEvaluated
          ? l.gameStoryThankYouKeepSafe
          : (_analysing
              ? l.gameStoryLovelyStoryListening
              : l.gameStoryTellSmallStory),
      companionState: _storyEvaluated
          ? CompanionState.celebrating
          : (_analysing ? CompanionState.thinking : CompanionState.listening),
      bottom: _storyEvaluated
          ? BigButton(
              label: l.gameStoryFinish,
              icon: Icons.check_rounded,
              color: _game.accent,
              onPressed: _finish,
            )
          : (_analysing
              ? null
              : BigButton(
                  label: _fragments.isEmpty ? l.gameStoryTapFewPartsFirst : l.gameStoryThatIsMyStory,
                  icon: Icons.auto_awesome_rounded,
                  color: _game.accent,
                  onPressed: _fragments.isEmpty ? null : _evaluateStory,
                )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MmCard(
              child: Column(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: Corners.r(Corners.md),
                      boxShadow: AppColors.softShadow(y: 6, blur: 18),
                    ),
                    child: SceneImage(sceneId: asset.sceneId, size: 176, radius: Corners.md),
                  ),
                  const SizedBox(height: 12),
                  Text(asset.title, style: AppText.h3),
                  if (asset.year != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(l.gameStoryFromYourMemories(asset.year!), style: AppText.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            if (!_storyEvaluated) ...<Widget>[
              Text(l.gameStoryTapWhatYouRemember, style: AppText.overline),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: <Widget>[
                  for (int i = 0; i < options.length; i++)
                    Pressable(
                      onTap: _analysing
                          ? null
                          : () => setState(() {
                                if (!_fragments.remove(i)) _fragments.add(i);
                              }),
                      child: AnimatedContainer(
                        duration: Motion.quick,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: _fragments.contains(i) ? _game.accent : Colors.white,
                          borderRadius: Corners.r(Corners.pill),
                          border: Border.all(
                            color: _fragments.contains(i) ? _game.accent : AppColors.hairline,
                            width: 1.6,
                          ),
                        ),
                        child: Text(
                          options[i],
                          style: AppText.body.wght(600).tint(
                                _fragments.contains(i) ? Colors.white : AppColors.ink,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_fragments.isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.lg),
                Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: _game.tint,
                    borderRadius: Corners.r(Corners.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.gameStoryYourStory, style: AppText.overline.tint(_game.accent)),
                      const SizedBox(height: 8),
                      Text(
                        '${(_fragments.toList()..sort()).map((int i) => options[i]).join('. ')}.',
                        style: AppText.patientBody.sized(18),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_analysing) ...<Widget>[
              const SizedBox(height: Insets.lg),
              const _AnalysingStrip(),
            ],
            if (_storyEvaluated) ...<Widget>[
              _StoryScoreCard(
                coherence: (58 + _fragments.length * 9).clamp(45, 96),
                details: (52 + _fragments.length * 11).clamp(45, 97),
                association: (50 + _fragments.length * 10).clamp(40, 95),
                accent: _game.accent,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.text, required this.accent, required this.onTap});
  final String text;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(color: AppColors.hairline, width: 1.4),
          boxShadow: AppColors.softShadow(y: 4, blur: 12, opacity: 0.05),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: AppText.patientBody.wght(600).sized(18))),
          ],
        ),
      ),
    );
  }
}

class _AnalysingStrip extends StatelessWidget {
  const _AnalysingStrip();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        const Companion(state: CompanionState.thinking, size: 54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.gameStoryMitraListening, style: AppText.body.wght(700)),
              const SizedBox(height: 8),
              const _ShimmerLine(width: double.infinity),
              const SizedBox(height: 6),
              const _ShimmerLine(width: 180),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine({required this.width});
  final double width;

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) => Container(
        width: widget.width,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: Corners.r(6),
          gradient: LinearGradient(
            begin: Alignment(-1 + _c.value * 2, 0),
            end: Alignment(0 + _c.value * 2, 0),
            colors: const <Color>[
              AppColors.surfaceMuted,
              AppColors.hairline,
              AppColors.surfaceMuted,
            ],
          ),
        ),
      ),
    );
  }
}

class _EvaluationPanel extends StatelessWidget {
  const _EvaluationPanel({
    required this.analysing,
    required this.answer,
    required this.rows,
    required this.accent,
  });

  final bool analysing;
  final String answer;
  final List<({String label, bool ok})> rows;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.gameStoryYourAnswer, style: AppText.overline),
          const SizedBox(height: 8),
          Text('“$answer”', style: AppText.patientBody.wght(600).sized(18)),
          const SizedBox(height: Insets.md),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 7),
              Text(l.gameStoryHowMitraReadIt, style: AppText.overline.tint(accent)),
            ],
          ),
          const SizedBox(height: 12),
          if (analysing)
            const _AnalysingStrip()
          else
            for (final ({String label, bool ok}) r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: <Widget>[
                    Icon(
                      r.ok ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                      size: 20,
                      color: r.ok ? AppColors.success : AppColors.inkMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.label,
                        style: AppText.body.wght(600).tint(
                              r.ok ? AppColors.ink : AppColors.inkMuted,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _StoryScoreCard extends StatelessWidget {
  const _StoryScoreCard({
    required this.coherence,
    required this.details,
    required this.association,
    required this.accent,
  });

  final int coherence;
  final int details;
  final int association;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 17, color: accent),
              const SizedBox(width: 7),
              Text(l.gameStoryHowMitraReadYourStory, style: AppText.overline.tint(accent)),
            ],
          ),
          const SizedBox(height: 14),
          _ScoreRow(label: l.gameStoryCoherence, value: coherence, color: accent),
          const SizedBox(height: 12),
          _ScoreRow(label: l.gameStoryRelevantDetails, value: details, color: accent),
          const SizedBox(height: 12),
          _ScoreRow(label: l.gameStoryMemoryAssociation, value: association, color: accent),
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: Corners.r(Corners.sm),
            ),
            child: Text(
              l.gameStorySimulatedCaption,
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 140,
          child: Text(label, style: AppText.body.wght(600).tint(AppColors.inkSoft)),
        ),
        Expanded(child: MeterBar(value: value / 100, color: color, height: 9)),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text('$value%',
              textAlign: TextAlign.right, style: AppText.body.wght(800).tint(color)),
        ),
      ],
    );
  }
}
