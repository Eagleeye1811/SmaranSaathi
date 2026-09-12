import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/ai/ai_context.dart';
import '../../../core/ai/ai_context_builder.dart';
import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/health_assistant.dart';
import '../../../core/voice/voice_bootstrap.dart';
import '../../../core/models/clinical.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/personalization_service.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/models/daily.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../../data/mock/mock_data.dart';
import '../assistant/assistant_screen.dart';
import '../../intake/intake_kit.dart';
import '../games/game_launcher.dart';
import '../memories/memory_wallet_screen.dart';
import '../today/today_screen.dart';
import '../widgets/patient_widgets.dart';
import 'cognitive_profile_screen.dart';
import 'health_widgets.dart';

/// The patient's home.
///
/// Ordered by what the person came for: how am I doing, what should I do
/// today, where is it heading, and who can explain it. The activities sit
/// *inside* that story rather than being the point of the app — a screen full
/// of games is a game app, and this is a monitoring tool.
class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key, this.onOpenTab});

  /// Lets the dashboard switch the shell's tab rather than pushing a route.
  final ValueChanged<int>? onOpenTab;

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  final ScrollController _scroll = ScrollController();

  /// Shown once the top of the page is far enough away that swiping back to
  /// it is a chore. The page is long by design — the whole record is on it —
  /// so it needs a way back that is not six flicks.
  bool _showTopButton = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool show = _scroll.hasClients && _scroll.offset > 700;
    if (show != _showTopButton) setState(() => _showTopButton = show);
  }

  void _toTop() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;
    final Recommendation recommendation = state.todaysRecommendation;
    final GameDefinition game = MockData.game(recommendation.gameId);
    final bool assessmentDueToday = state.completedToday.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _showTopButton
          ? FloatingActionButton.small(
              onPressed: _toTop,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: l.dashboardBackToTop,
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
            )
          : null,
      body: MotifBackground(
        opacity: 0.035,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // Tapping the bar returns to the top, the way a title bar does
              // everywhere else.
              GestureDetector(onTap: _toTop, child: const PatientTopBar()),
              Expanded(
                child: ListView(
                  controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.xxl),
            children: <Widget>[
              _Header(name: state.patient.shortName, state: state),
              const SizedBox(height: Insets.md),

              // Offline is a normal state here, not an error: everything keeps
              // working and the queue drains when the connection returns.
              if (state.offline) ...<Widget>[
                OfflineBanner(pending: state.pendingSync),
                const SizedBox(height: Insets.md),
              ],

              // ── The one thing to do ───────────────────────────────────
              //
              // Leads the screen because it is what the person came here to
              // *do*. Before the baseline exists that is the invitation to
              // start; afterwards it is the activity chosen for today.
              if (!state.baselineReady)
                _JourneyCard(
                  // Into the activities page, rather than straight into a
                  // session the app picked. Being dropped into an activity you
                  // did not choose is disorienting for exactly the person this
                  // side of the app is for; the list lets them see what is on
                  // offer and pick the one they like the look of.
                  onStart: () => widget.onOpenTab?.call(2),
                )
              else
                _TodaysActivity(
                  game: game,
                  recommendation: recommendation,
                  dueToday: assessmentDueToday,
                ),
              const SizedBox(height: Insets.lg),

              // ── How they are ──────────────────────────────────────────
              _CheckIn(
                state: state,
                onTalk: (String opening) => Nav.open(
                  context,
                  AssistantScreen(
                    seedTurns: <ConversationTurn>[
                      ConversationTurn(fromUser: false, text: opening),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),

              // Written for this person from their onboarding answers — by
              // Gemini when it is reachable, on the device when it is not.
              const _TodaysQuestions(),
              const SizedBox(height: Insets.lg),

              // ── How it is going ───────────────────────────────────────
              if (state.baselineReady) ...<Widget>[
                StatusCard(
                  snapshot: snapshot,
                  onViewProfile: () =>
                      Nav.push(context, const CognitiveProfileScreen()),
                ),
                const SizedBox(height: Insets.lg),
              ],

              // This used to be a separate tab. Trends that live one tap away
              // from the thing they are about get looked at once; here they
              // are the answer to "how am I doing", directly under it.
              _ProgressSection(state: state, snapshot: snapshot),
              const SizedBox(height: Insets.lg),

              _RemindersStrip(state: state, onOpenTab: widget.onOpenTab),
              const SizedBox(height: Insets.md),

              // ── The warm parts of the app ─────────────────────────────
              //
              // Two, not five. The doctor summary and the care plan used to
              // sit here too — both are written for a clinician to read and
              // a caregiver to act on, and neither is something this person
              // opens for themselves. They are on the caregiver side, where
              // they are used.
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.forum_rounded,
                      label: l.dashboardAskCompanion,
                      detail: l.dashboardExplainResults,
                      color: AppColors.primary,
                      // 4, not 2 — this pointed at the activities tab, so the
                      // "ask the companion" card opened a list of puzzles.
                      onTap: () => widget.onOpenTab != null
                          ? widget.onOpenTab!(4)
                          : Nav.push(context, const AssistantScreen()),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.favorite_outline_rounded,
                      label: l.dashboardMemoryWallet,
                      detail: l.dashboardPeopleAndPlaces,
                      color: AppColors.terracotta,
                      onTap: () => Nav.push(context, const MemoryWalletScreen()),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.today_outlined,
                      label: l.patientNavToday,
                      detail: l.dashboardCheckInReminders,
                      color: AppColors.plum,
                      onTap: () => widget.onOpenTab != null
                          ? widget.onOpenTab!(1)
                          : Nav.push(context, const TodayScreen()),
                    ),
                  ),
                ],
              ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header: the companion in the middle.
///
/// The companion is centred and large because it is the thing the person
/// talks to — on a screen built for someone who may be anxious about what
/// they are about to read, a face belongs in the middle, not in a corner.
/// The name and status live in the bar above it, not here.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.state});

  final String name;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int hour = DateTime.now().hour;
    final String part = hour < 12
        ? l.greetingMorning
        : hour < 17
            ? l.greetingAfternoon
            : l.greetingEvening;

    return Column(
      children: <Widget>[
        Companion(
          state: state.mood == null
              ? CompanionState.happy
              : (state.mood == MoodLevel.low
                  ? CompanionState.gentle
                  : CompanionState.encouraging),
          size: 118,
          animate: !state.reduceMotion,
        ),
        const SizedBox(height: Insets.sm),
        Text('$part, $name', style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(
          state.baselineReady
              ? l.dashboardCognitiveHealthOnePlace
              : l.dashboardBuildStartingPoint,
          style: AppText.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The pre-baseline call to action: two activities a day, three days.
///
/// The one thing asked of the person before their profile exists.
///
/// It used to lead with the schedule — "two short activities a day, for three
/// days", a "Day 1 of 4" pill, "0 of 7 activities done" and a progress bar at
/// zero. That is an accurate description of the plan and a discouraging thing
/// to hand somebody who has not started: four counters, all of them empty,
/// before a single encouraging word. Someone with memory difficulty does not
/// need to be told how many days of homework are ahead of them.
///
/// What is left is an invitation and a button. The counting still happens —
/// the baseline needs it — it simply is not what greets them.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final int baselineTotal =
        AppState.baselinePlan.fold(0, (int sum, List<GameId> d) => sum + d.length);
    final int totalDone = baselineTotal - state.baselineRemaining.length;
    final bool restingToday =
        !state.canStartBaselineSession() && !state.baselineRunComplete;

    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      // Plain white. The warm gradient behind it fought the warm background
      // the whole page already sits on, so the card read as a smudge rather
      // than as a surface lifted off it.
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  restingToday
                      ? 'You have done enough for today. Come back when you are ready.'
                      : totalDone == 0
                          ? 'A few gentle activities, whenever you feel like it. '
                              'There is no score to beat and no wrong answer.'
                          : 'Good to see you again. Shall we carry on where we left off?',
                  style: AppText.body.wght(600),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (restingToday)
            SoftButton(
              label: l.dashboardIHaveTimeContinue,
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                state.unlockNextBaselineDay();
                onStart();
              },
            )
          else
            BigButton(
              label: totalDone == 0 ? l.dashboardStartFirstSession : l.dashboardStartTodaySession,
              icon: Icons.play_arrow_rounded,
              height: 62,
              onPressed: onStart,
            ),
        ],
      ),
    );
  }
}

/// Trends, in place on the home screen.
///
/// Everything here is derived from sessions actually played. With none, it
/// says so instead of drawing an empty chart or a placeholder score.
class _ProgressSection extends StatefulWidget {
  const _ProgressSection({required this.state, required this.snapshot});

  final AppState state;
  final MonitoringSnapshot snapshot;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  /// Collapsed by default. Bringing the trends onto the home screen was right,
  /// but printing all of them all the time made the page long enough that
  /// getting back to the top was work. The summary is always here; the
  /// per-domain detail is one tap away and stays open once opened.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.state;
    final AppLocalizations l = AppLocalizations.of(context);
    final MonitoringSnapshot snapshot = widget.snapshot;
    final List<SeriesPoint> weekly = AppState.monitor.weeklySeries(state.sessions);
    final List<DomainReading> readings =
        snapshot.readings.where((DomainReading r) => r.hasReading).toList();

    if (state.sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: l.dashboardYourProgress, icon: Icons.timeline_rounded),
          const SizedBox(height: Insets.sm),
          MmCard(
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: l.dashboardNothingToShowYet,
              message: l.dashboardFirstActivityStarts,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.dashboardYourProgress,
          icon: Icons.timeline_rounded,
          subtitle: snapshot.hasBaseline
              ? l.dashboardWeeklyAveragesBaseline
              : l.dashboardBuildingTowardsBaseline,
        ),
        const SizedBox(height: Insets.sm),
        if (weekly.length > 1) ...<Widget>[
          MmCard(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(l.dashboardOverallActivityScore, style: AppText.label),
                    if (snapshot.overallBaseline != null)
                      PillTag(
                        label: l.dashboardBaselineScore(snapshot.overallBaseline!.round()),
                        color: AppColors.secondary,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                TrendLineChart(
                  points: weekly,
                  labelEvery: weekly.length > 8 ? 2 : 1,
                  minValue: 40,
                  color: trendColor(snapshot.overallTrend),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: l.dashboardAdherence,
                value: '${snapshot.adherencePercent}%',
                meter: snapshot.adherencePercent / 100,
                icon: Icons.event_available_rounded,
                compact: true,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: StatTile(
                label: l.dashboardConsistency,
                value: '${snapshot.consistency}%',
                meter: snapshot.consistency / 100,
                color: AppColors.secondary,
                icon: Icons.timeline_rounded,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        StatTile(
          label: l.dashboardReportedIndependence,
          value: '${snapshot.functionalIndependence}%',
          meter: snapshot.functionalIndependence / 100,
          color: AppColors.accent,
          icon: Icons.home_work_outlined,
        ),
        if (!_expanded) ...<Widget>[
          const SizedBox(height: Insets.sm),
          SoftButton(
            label: readings.isEmpty
                ? l.dashboardMoreAboutProgress
                : l.dashboardSeeAllAreas(readings.length),
            icon: Icons.expand_more_rounded,
            onPressed: () => setState(() => _expanded = true),
          ),
        ] else ...<Widget>[
          if (readings.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            SectionHeader(
              title: l.cognitiveByDomainTitle,
              subtitle: l.dashboardWeeksAssessed(
                  snapshot.assessmentsCompleted, snapshot.assessmentsExpected),
            ),
            const SizedBox(height: Insets.sm),
            for (final DomainReading r in readings)
              DomainRow(reading: r, showSparkline: true),
          ],
          const SizedBox(height: Insets.md),
          MmCard(
            color: AppColors.primaryTint,
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.dashboardWhyScoreChanged, style: AppText.h3),
                const SizedBox(height: Insets.xs),
                Text(
                  l.dashboardWhyScoreChangedDetail,
                  style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: Insets.md),
                SoftButton(
                  label: l.dashboardExplainMyChange,
                  icon: Icons.help_outline_rounded,
                  filled: true,
                  onPressed: () => Nav.push(
                    context,
                    const AssistantScreen(initialAction: HealthQuickAction.whyChanged),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          const NotADiagnosisNote(),
          const SizedBox(height: Insets.sm),
          SoftButton(
            label: l.dashboardShowLess,
            icon: Icons.expand_less_rounded,
            color: AppColors.inkSoft,
            onPressed: () => setState(() => _expanded = false),
          ),
        ],
      ],
    );
  }
}


/// Today's questions, generated for this person.
///
/// Asked once per app session and held in the widget's state: regenerating on
/// every rebuild would change the question under someone mid-answer, and cost
/// a model call each time. A failure never shows an error — the on-device
/// questions are the same shape, so the person simply gets asked something.
class _TodaysQuestions extends StatefulWidget {
  const _TodaysQuestions();

  @override
  State<_TodaysQuestions> createState() => _TodaysQuestionsState();
}

class _TodaysQuestionsState extends State<_TodaysQuestions> {
  AiService? _ai;
  List<DailyQuestion> _questions = const <DailyQuestion>[];
  int _index = 0;
  bool _loading = true;
  String? _loadedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String currentLocale = Localizations.localeOf(context).languageCode;
    if (_loadedLocale != currentLocale) {
      _loadedLocale = currentLocale;
      _load(currentLocale);
    }
  }

  @override
  void dispose() {
    _ai?.dispose();
    super.dispose();
  }

  Future<void> _load([String? localeCode]) async {
    final AppState state = AppScope.read(context);
    final String activeLocale = localeCode ?? Localizations.localeOf(context).languageCode;
    final AiService ai = _ai ??= buildPatientAssistant(state);
    final PatientAiContext context_ = state.aiContext(replyLanguage: activeLocale);
    final AiResult<List<DailyQuestion>> result = await ai.dailyQuestions(context_);
    if (!mounted) return;
    setState(() {
      // ResilientAiService always succeeds — it falls back to the device — so
      // an error here means no service at all, and no card rather than a
      // broken one.
      _questions = result.valueOrNull ?? const <DailyQuestion>[];
      _questions = _questions
          .where((DailyQuestion q) => !state.answered(q.id))
          .toList(growable: false);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);

    if (_loading) {
      return MmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.dashboardThinkingOfQuestion, style: AppText.body.wght(700)),
            const SizedBox(height: 3),
            Text(l.dashboardJustAMoment, style: AppText.bodySmall),
          ],
        ),
      );
    }
    if (_index >= _questions.length) {
      if (_questions.isEmpty) return const SizedBox.shrink();
      return MmCard(
        color: AppColors.primaryTint,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        child: Row(
          children: <Widget>[
            const Companion(state: CompanionState.celebrating, size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${l.homeAllQuestionsAnswered} ${l.homeThankYouForTalking}',
                style: AppText.body.wght(600).tint(AppColors.primaryDeep),
              ),
            ),
          ],
        ),
      );
    }

    final DailyQuestion question = _questions[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.dashboardQuestionForYou,
          subtitle: l.dashboardAskedBecauseOfWhatYouTold,
        ),
        const SizedBox(height: Insets.sm),
        DailyQuestionCard(
          key: ValueKey<String>(question.id),
          question: question,
          onAnswer: (QuestionOption option) {
            state.answerQuestion(question, option);
            Future<void>.delayed(const Duration(milliseconds: 1900), () {
              if (mounted) setState(() => _index++);
            });
          },
        ),
      ],
    );
  }
}

/// The daily check-in, and what happens after it.
///
/// Answering used to be the end of it: the companion said something kind and
/// the card went quiet. But "not good" is the most important thing a person
/// tells this app all day, and following it with silence is the one response
/// nobody would give in a room. So the reply now ends in an offer, and the
/// offer opens the companion with the mood already in hand.
///
/// It is an offer, never a redirect. Being moved to another screen because of
/// something you admitted is a punishment for admitting it; the person taps
/// if they want to, and the card simply stays put if they do not.
/// The activity chosen for today, once there is a profile to choose against.
///
/// Lifted out of the page body, where it was seventy lines of nesting in the
/// middle of a list, so the order of the screen can be read at a glance.
class _TodaysActivity extends StatelessWidget {
  const _TodaysActivity({
    required this.game,
    required this.recommendation,
    required this.dueToday,
  });

  final GameDefinition game;
  final Recommendation recommendation;
  final bool dueToday;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: dueToday ? l.healthTodaysActivity : l.healthAnotherActivity,
          subtitle: recommendation.headline,
        ),
        const SizedBox(height: Insets.sm),
        MmCard(
          onTap: () => GameLauncher.open(context, game.id),
          padding: const EdgeInsets.all(Insets.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[game.tint, AppColors.surface],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SoftIcon(
                    // Falls back for an activity with no cognitive domain
                    // claim (Mood Canvas) — a plain recommended activity, not
                    // a fake domain badge.
                    icon: game.domain?.icon ?? Icons.brush_rounded,
                    color: game.accent,
                    background: Colors.white,
                    size: 54,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(game.localizedName(l), style: AppText.h3),
                        const SizedBox(height: 2),
                        Text(
                          '${game.domain?.clinicalLabel ?? game.tagline} · '
                          '${game.estimatedMinutes} min',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(recommendation.reason, style: AppText.body.copyWith(height: 1.45)),
              const SizedBox(height: Insets.md),
              BigButton(
                label: l.actionStart,
                icon: Icons.play_arrow_rounded,
                color: game.accent,
                height: 58,
                onPressed: () => GameLauncher.open(context, game.id),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.state, required this.onTalk});

  final AppState state;

  /// Opens the companion, carrying the opening line with it.
  final ValueChanged<String> onTalk;

  /// What the companion should say first, in the mood's own register.
  ///
  /// Three different openings rather than one, because "I am glad" and "I am
  /// sorry" are not interchangeable and a person who has just said they feel
  /// low will notice immediately if the app did not read it.
  String _opening(MoodLevel mood, String name) => switch (mood) {
        MoodLevel.good => 'You said you are feeling good today. '
            'I would love to hear what has made it a good day.',
        MoodLevel.okay => 'You said today feels about okay. '
            'Tell me how it has gone so far — I have time.',
        MoodLevel.low => 'You said you are not feeling good today, $name. '
            'I am here. Would you like to tell me what is on your mind?',
      };

  /// Short enough to stay on one line, and said the way a person would say
  /// it. "I would like to talk about it" is how a form asks; nobody stands in
  /// a kitchen and announces that.
  ///
  /// Mitra by name, because that is who is on the other side of the tap and
  /// the whole app calls the companion that already. "Talk to Mitra" is a
  /// person you can go and find; "open the assistant" is a feature.
  String _invitation(MoodLevel mood) => switch (mood) {
        MoodLevel.good => 'Tell Mitra about it',
        MoodLevel.okay => 'Tell Mitra about it',
        MoodLevel.low => 'Talk to Mitra',
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final MoodLevel? mood = state.mood;

    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      // White, like the card above it. The tinted gradient behind three white
      // tiles was doing the work the tiles' own outline should be doing.
      color: AppColors.surface,
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: Motion.normal,
            child: Text(
              mood == null ? l.homeMoodQuestion : mood.companionReply,
              key: ValueKey<String>(mood?.name ?? 'ask'),
              textAlign: TextAlign.center,
              style: AppText.h3,
            ),
          ),
          const SizedBox(height: Insets.md),
          MoodPicker(
            key: const Key('home_mood_picker'),
            selected: mood,
            onSelect: state.setMood,
          ),
          if (mood != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              mood == MoodLevel.low
                  ? 'You do not have to carry it on your own.'
                  : 'I would love to hear more, if you feel like sharing.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.tint(AppColors.inkSoft),
            ),
            const SizedBox(height: Insets.sm),
            BigButton(
              label: _invitation(mood),
              icon: Icons.forum_rounded,
              height: 58,
              // The app's own green, whatever the mood. Turning the button red
              // for "not good" made the offer of a conversation look like a
              // warning about the answer they had just given.
              onPressed: () => onTalk(_opening(mood, state.patient.shortName)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SoftIcon(icon: icon, color: color, background: color.withValues(alpha: 0.12)),
          const SizedBox(height: Insets.sm),
          Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
          Text(detail, style: AppText.caption),
        ],
      ),
    );
  }
}

class _RemindersStrip extends StatelessWidget {
  const _RemindersStrip({required this.state, this.onOpenTab});

  final AppState state;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    if (state.remindersTotal == 0) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      // Index 1 is Today, which is the reminder list. (This was 3, the
      // Companion tab — the same off-by-position slip as the nav bar.)
      onTap: () => onOpenTab != null ? onOpenTab!(1) : null,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const SoftIcon(icon: Icons.notifications_active_outlined),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.dashboardTodaysReminders, style: AppText.label),
                Text(l.dashboardRemindersDone(state.remindersDone, state.remindersTotal),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: MeterBar(value: state.adherencePercent / 100),
          ),
        ],
      ),
    );
  }
}
