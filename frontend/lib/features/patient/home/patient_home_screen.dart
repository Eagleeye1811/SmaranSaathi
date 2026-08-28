import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/models/game.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/personalization_service.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../games/game_launcher.dart';
import '../voice/ask_mitra_button.dart';
import '../widgets/patient_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// The heart of the product: one screen, four decisions, no menus.
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late final List<DailyQuestion> _questions = MockData.dailyQuestions(AppScope.read(context).patient);
  int _questionIndex = 0;

  String _greeting(AppLocalizations l) {
    final int h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning;
    if (h < 17) return l.greetingAfternoon;
    return l.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final Recommendation rec = state.todaysRecommendation;
    final GameDefinition game = MockData.game(rec.gameId);

    final DailyQuestion? question = _questionIndex < _questions.length
        ? _questions[_questionIndex]
        : null;

    final Reminder? nextReminder = () {
      for (final Reminder r in state.reminders) {
        if (!r.done && r.kind != ReminderKind.appointment) return r;
      }
      return null;
    }();

    return MotifBackground(
      opacity: 0.045,
      washColors: <Color>[
        AppColors.accentTint.withValues(alpha: 0.85),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const PatientTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                children: <Widget>[
                  if (state.offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: OfflineBanner(
                        pending: state.pendingSync,
                      ),
                    ),

                  // ── Greeting + companion ──────────────────────────────
                  FadeInUp(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${_greeting(l)},',
                                style: AppText.patientTitle.sized(24).tint(AppColors.inkSoft),
                              ),
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      state.patient.shortName.isEmpty
                                          ? 'friend'
                                          : state.patient.shortName,
                                      style: AppText.patientTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('❤️', style: TextStyle(fontSize: 24)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_dateLabel(), style: AppText.bodySmall),
                            ],
                          ),
                        ),
                        SceneImage(
                          sceneId: state.patient.portraitScene,
                          size: 58,
                          circle: true,
                          borderColor: Colors.white,
                          borderWidth: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Mood check-in ─────────────────────────────────────
                  FadeInUp(
                    delayMs: 60,
                    child: MmCard(
                      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.lg),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Colors.white, AppColors.primaryTint.withValues(alpha: 0.55)],
                      ),
                      child: Column(
                        children: <Widget>[
                          Center(
                            child: Companion(
                              state: state.mood == null
                                  ? CompanionState.happy
                                  : (state.mood == MoodLevel.low
                                      ? CompanionState.gentle
                                      : CompanionState.encouraging),
                              size: 148,
                              animate: !state.reduceMotion,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: Motion.normal,
                            child: Text(
                              state.mood == null
                                  ? l.homeMoodQuestion
                                  : state.mood!.companionReply,
                              key: ValueKey<String>(state.mood?.name ?? 'ask'),
                              textAlign: TextAlign.center,
                              style: AppText.companionSpeech,
                            ),
                          ),
                          const SizedBox(height: Insets.lg),
                          MoodPicker(
                            selected: state.mood,
                            onSelect: state.setMood,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Companion recommendation ──────────────────────────
                  FadeInUp(
                    delayMs: 110,
                    child: _RecommendationCard(
                      recommendation: rec,
                      game: game,
                      level: state.levelOf(rec.gameId),
                      onStart: () => GameLauncher.open(context, rec.gameId),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Ask Mitra ─────────────────────────────────────────
                  const FadeInUp(
                    delayMs: 150,
                    child: AskMitraButton(),
                  ),
                  const SizedBox(height: Insets.lg),

                  // ── Today's memory question ───────────────────────────
                  if (question != null) ...<Widget>[
                    FadeInUp(
                      delayMs: 150,
                      child: SectionHeader(
                        title: 'Today\'s memory',
                        subtitle: l.homeSmallQuestion,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                    FadeInUp(
                      delayMs: 170,
                      child: DailyQuestionCard(
                        key: ValueKey<String>(question.id),
                        question: question,
                        onAnswer: (QuestionOption o) {
                          state.answerQuestion(question, o);
                          Future<void>.delayed(const Duration(milliseconds: 1900), () {
                            if (mounted) setState(() => _questionIndex++);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                  ] else ...<Widget>[
                    FadeInUp(
                      delayMs: 150,
                      child: MmCard(
                        color: AppColors.primaryTint,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        child: Row(
                          children: <Widget>[
                            const Companion(state: CompanionState.celebrating, size: 66),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You have answered all of today\'s questions. '
                                'Thank you for talking with me.',
                                style: AppText.bodyLarge.wght(600).tint(AppColors.primaryDeep),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                  ],

                  // ── Next reminder ─────────────────────────────────────
                  if (nextReminder != null) ...<Widget>[
                    FadeInUp(
                      delayMs: 190,
                      child: SectionHeader(
                        title: l.homeComingUp,
                        icon: Icons.notifications_active_rounded,
                        action: 'All',
                        onAction: () => widget.onOpenTab?.call(3),
                      ),
                    ),
                    FadeInUp(
                      delayMs: 200,
                      child: ReminderRow(
                        reminder: nextReminder,
                        onToggle: () => state.toggleReminder(nextReminder.id),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                  ],

                  // ── Today's journey ───────────────────────────────────
                  FadeInUp(
                    delayMs: 230,
                    child: SectionHeader(
                      title: 'Today\'s journey',
                      icon: Icons.route_rounded,
                    ),
                  ),
                  FadeInUp(
                    delayMs: 250,
                    child: MmCard(
                      child: JourneyStrip(
                        steps: MockData.journey,
                        done: state.journeyDone,
                      ),
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

  String _dateLabel() {
    const List<String> months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const List<String> days = <String>[
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    final DateTime n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.game,
    required this.level,
    required this.onStart,
  });

  final Recommendation recommendation;
  final GameDefinition game;
  final int level;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: EdgeInsets.zero,
      clip: true,
      shadow: AppColors.liftShadow(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.md),
            color: game.tint,
            child: Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded, size: 18, color: game.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.homeRecommendsLabel,
                    style: AppText.overline.tint(game.accent),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: Corners.r(Corners.md),
                        boxShadow: AppColors.softShadow(y: 4, blur: 12),
                      ),
                      child: SceneImage(sceneId: game.sceneId, size: 84, radius: Corners.md),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(game.name, style: AppText.h3.wght(800)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              PillTag(
                                label: game.domain.label,
                                icon: game.domain.icon,
                                color: game.accent,
                                dense: true,
                              ),
                              DifficultyDots(level: level, color: game.accent, size: 8),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                CompanionSpeech(
                  message: recommendation.reason,
                  state: CompanionState.encouraging,
                  companionSize: 62,
                  compact: true,
                ),
                const SizedBox(height: Insets.md),
                BigButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  color: game.accent,
                  onPressed: onStart,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
