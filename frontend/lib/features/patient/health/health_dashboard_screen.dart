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
import '../../../data/mock/mock_data.dart';
import '../assistant/assistant_screen.dart';
import '../../intake/baseline_screens.dart';
import '../../intake/intake_kit.dart';
import '../games/game_launcher.dart';
import '../memories/memory_wallet_screen.dart';
import '../today/today_screen.dart';
import '../widgets/patient_widgets.dart';
import 'care_plan_screen.dart';
import 'cognitive_profile_screen.dart';
import 'health_widgets.dart';
import 'report_screen.dart';

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
              tooltip: 'Back to the top',
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
              if (state.offline) OfflineBanner(pending: state.pendingSync),
              const SizedBox(height: Insets.sm),
              // The daily check-in stays on the home screen: mood is one of
              // the ordinary things that moves a cognitive score, and asking
              // for it every day is what makes it useful when explaining one.
              _CheckIn(state: state),
              const SizedBox(height: Insets.lg),
              // Written for this person from their onboarding answers — by
              // Gemini when it is reachable, on the device when it is not.
              const _TodaysQuestions(),
              const SizedBox(height: Insets.lg),
              // Before the baseline exists there is nothing honest to put in a
              // status card, so the journey takes its place: two activities a
              // day until the profile is real.
              if (!state.baselineReady) ...<Widget>[
                _JourneyCard(
                  onStart: () => openBaselineSession(
                    context,
                    onComplete: () => Nav.open(
                      context,
                      CognitiveProfileScreen(
                        firstTime: true,
                        onContinue: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ] else ...<Widget>[
                StatusCard(
                  snapshot: snapshot,
                  onViewProfile: () =>
                      Nav.push(context, const CognitiveProfileScreen()),
                ),
                const SizedBox(height: Insets.lg),
                SectionHeader(
                  title: assessmentDueToday ? "Today's activity" : 'Another activity',
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
                            icon: game.domain.icon,
                            color: game.accent,
                            background: Colors.white,
                            size: 54,
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(game.name, style: AppText.h3),
                                const SizedBox(height: 2),
                                Text(
                                  '${game.domain.clinicalLabel} · ${game.estimatedMinutes} min',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Text(recommendation.reason,
                          style: AppText.body.copyWith(height: 1.45)),
                      const SizedBox(height: Insets.md),
                      BigButton(
                        label: 'Start',
                        icon: Icons.play_arrow_rounded,
                        color: game.accent,
                        height: 58,
                        onPressed: () => GameLauncher.open(context, game.id),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],

              // ── Progress, in place ────────────────────────────────────
              //
              // This used to be a separate tab. Trends that live one tap away
              // from the thing they are about get looked at once; here they
              // are the answer to "how am I doing", directly under it.
              _ProgressSection(state: state, snapshot: snapshot),
              const SizedBox(height: Insets.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.forum_rounded,
                      label: 'Ask your companion',
                      detail: 'Explain my results',
                      color: AppColors.primary,
                      onTap: () => Nav.push(context, const AssistantScreen()),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.description_outlined,
                      label: 'Doctor summary',
                      detail: 'Ready to share',
                      color: AppColors.secondary,
                      onTap: () => Nav.push(context, const ReportScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              _ActionCard(
                icon: Icons.checklist_rounded,
                label: 'Care plan',
                detail: snapshot.suggestsClinicalDiscussion
                    ? 'A conversation with a doctor is suggested'
                    : 'Weekly assessment and daily activity',
                color: AppColors.accent,
                wide: true,
                onTap: () => Nav.push(context, const CarePlanScreen()),
              ),
              const SizedBox(height: Insets.lg),
              _RemindersStrip(state: state),
              const SizedBox(height: Insets.md),
              // The warm parts of the app the monitoring journey sits on top
              // of. Kept one tap away rather than in the navigation bar: they
              // support the day, they are not what the person came for.
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Memory wallet',
                      detail: 'People and places',
                      color: AppColors.terracotta,
                      onTap: () => Nav.push(context, const MemoryWalletScreen()),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.today_outlined,
                      label: 'Today',
                      detail: 'Check-in and reminders',
                      color: AppColors.plum,
                      onTap: () => Nav.push(context, const TodayScreen()),
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
    final int hour = DateTime.now().hour;
    final String part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

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
              ? 'Your cognitive health, in one place'
              : 'Let us build your starting point together',
          style: AppText.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The pre-baseline call to action: two activities a day, three days.
///
/// The only thing asked of the person until the profile exists. It says how
/// far along they are, what today asks, and that stopping for the day is the
/// plan working rather than the plan failing.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final int day = state.baselineDayIndex;
    final int totalDone = GameId.values.length - state.baselineRemaining.length;
    final bool restingToday =
        !state.canStartBaselineSession() && !state.baselineRunComplete;

    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, AppColors.accentTint.withValues(alpha: 0.6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            restingToday
                ? "You have done today's two. Rest now — I will be here "
                    'tomorrow for the next pair.'
                : day == 0
                    ? 'Let us start your journey. Two short activities today, '
                        'and I will be with you for both.'
                    : 'Welcome back. Two more activities and we are on day '
                        '${day + 1} of three.',
            style: AppText.body.wght(600),
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PillTag(
                label: 'Day ${day >= AppState.baselinePlan.length ? AppState.baselinePlan.length : day + 1} '
                    'of ${AppState.baselinePlan.length}',
                color: AppColors.accent,
                dense: true,
              ),
              Text('$totalDone of ${GameId.values.length} activities done',
                  style: AppText.caption),
            ],
          ),
          const SizedBox(height: Insets.sm),
          MeterBar(value: totalDone / GameId.values.length, height: 8),
          const SizedBox(height: Insets.md),
          if (restingToday) ...<Widget>[
            Text(
              'The gap between sessions is part of the measurement: three '
              "separate days average out one bad night's sleep.",
              style: AppText.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            SoftButton(
              label: 'I have time now — continue',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                state.unlockNextBaselineDay();
                onStart();
              },
            ),
          ] else
            BigButton(
              label: totalDone == 0 ? 'Start my first session' : "Start today's session",
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
    final MonitoringSnapshot snapshot = widget.snapshot;
    final List<SeriesPoint> weekly = AppState.monitor.weeklySeries(state.sessions);
    final List<DomainReading> readings =
        snapshot.readings.where((DomainReading r) => r.hasReading).toList();

    if (state.sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: 'Your progress', icon: Icons.timeline_rounded),
          const SizedBox(height: Insets.sm),
          const MmCard(
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: 'Nothing to show yet',
              message: 'Your first activity starts this. Every number here '
                  'comes from something you have actually done.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Your progress',
          icon: Icons.timeline_rounded,
          subtitle: snapshot.hasBaseline
              ? 'Weekly averages against your baseline'
              : 'Building towards your baseline',
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
                    Text('Overall activity score', style: AppText.label),
                    if (snapshot.overallBaseline != null)
                      PillTag(
                        label: 'Baseline ${snapshot.overallBaseline!.round()}',
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
                label: 'Adherence',
                value: '${snapshot.adherencePercent}%',
                meter: snapshot.adherencePercent / 100,
                icon: Icons.event_available_rounded,
                compact: true,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: StatTile(
                label: 'Consistency',
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
          label: 'Reported independence in daily activities',
          value: '${snapshot.functionalIndependence}%',
          meter: snapshot.functionalIndependence / 100,
          color: AppColors.accent,
          icon: Icons.home_work_outlined,
        ),
        if (!_expanded) ...<Widget>[
          const SizedBox(height: Insets.sm),
          SoftButton(
            label: readings.isEmpty
                ? 'More about my progress'
                : 'See all ${readings.length} areas',
            icon: Icons.expand_more_rounded,
            onPressed: () => setState(() => _expanded = true),
          ),
        ] else ...<Widget>[
          if (readings.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            SectionHeader(
              title: 'By domain',
              subtitle: '${snapshot.assessmentsCompleted} of '
                  '${snapshot.assessmentsExpected} weeks assessed',
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
                Text('Why did my score change?', style: AppText.h3),
                const SizedBox(height: Insets.xs),
                Text(
                  'Sleep, mood, illness, medication and plain tiredness all move '
                  'these numbers. Ask the companion to read your own record and '
                  'explain what it sees.',
                  style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: Insets.md),
                SoftButton(
                  label: 'Explain my change',
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
            label: 'Show less',
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ai?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppState state = AppScope.read(context);
    final AiService ai = _ai ??= buildPatientAssistant(state);
    final PatientAiContext context_ = state.aiContext();
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

    if (_loading) {
      return const MmCard(
        child: ListRow(
          leading: SoftIcon(icon: Icons.auto_awesome_rounded),
          title: 'Thinking of something to ask you…',
          subtitle: 'Just a moment',
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
                'You have answered all of today\'s questions. Thank you for '
                'talking with me.',
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
          title: 'A question for you',
          icon: Icons.auto_awesome_rounded,
          subtitle: 'Asked because of what you told me about yourself',
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

class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      padding: const EdgeInsets.all(Insets.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, AppColors.primaryTint.withValues(alpha: 0.55)],
      ),
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: Motion.normal,
            child: Text(
              state.mood == null ? l.homeMoodQuestion : state.mood!.companionReply,
              key: ValueKey<String>(state.mood?.name ?? 'ask'),
              textAlign: TextAlign.center,
              style: AppText.h3,
            ),
          ),
          const SizedBox(height: Insets.md),
          MoodPicker(selected: state.mood, onSelect: state.setMood),
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
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.md),
      child: wide
          ? Row(
              children: <Widget>[
                SoftIcon(icon: icon, color: color, background: color.withValues(alpha: 0.12)),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      Text(detail, style: AppText.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ],
            )
          : Column(
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
  const _RemindersStrip({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.remindersTotal == 0) return const SizedBox.shrink();
    return MmCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const SoftIcon(icon: Icons.notifications_active_outlined),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Today\'s reminders', style: AppText.label),
                Text('${state.remindersDone} of ${state.remindersTotal} done',
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
