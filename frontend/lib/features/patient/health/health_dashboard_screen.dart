import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/game.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/personalization_service.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/models/daily.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/mock/mock_data.dart';
import '../assistant/assistant_screen.dart';
import '../games/game_launcher.dart';
import '../memories/memory_wallet_screen.dart';
import '../today/today_screen.dart';
import '../widgets/patient_widgets.dart';
import 'care_plan_screen.dart';
import 'cognitive_profile_screen.dart';
import 'health_widgets.dart';
import 'progress_screen.dart';
import 'report_screen.dart';

/// The patient's home.
///
/// Ordered by what the person came for: how am I doing, what should I do
/// today, where is it heading, and who can explain it. The activities sit
/// *inside* that story rather than being the point of the app — a screen full
/// of games is a game app, and this is a monitoring tool.
class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key, this.onOpenTab});

  /// Lets the dashboard switch the shell's tab rather than pushing a route.
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final MonitoringSnapshot snapshot = state.monitoring;
    final Recommendation recommendation = state.todaysRecommendation;
    final GameDefinition game = MockData.game(recommendation.gameId);
    final bool assessmentDueToday = state.completedToday.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.035,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.xxl),
            children: <Widget>[
              _Greeting(name: state.patient.shortName),
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
              SectionHeader(
                title: 'Your progress',
                action: 'View trends',
                onAction: () => Nav.push(context, const ProgressScreen()),
              ),
              const SizedBox(height: Insets.sm),
              MmCard(
                onTap: () => Nav.push(context, const ProgressScreen()),
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  children: <Widget>[
                    for (final DomainReading r in snapshot.assessed.take(3))
                      DomainRow(reading: r, showSparkline: true),
                    if (snapshot.assessed.isEmpty)
                      const EmptyState(
                        title: 'No results yet',
                        message: 'Complete the baseline assessment to start tracking.',
                      ),
                  ],
                ),
              ),
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
              _RemindersStrip(state: state, onOpenTab: onOpenTab),
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
                      onTap: () => onOpenTab != null ? onOpenTab!(1) : Nav.push(context, const TodayScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final int hour = DateTime.now().hour;
    final String part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Row(
      children: <Widget>[
        const Companion(state: CompanionState.happy, size: 62),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$part, $name', style: AppText.h2),
              const SizedBox(height: 2),
              Text('Your cognitive health, in one place', style: AppText.bodySmall),
            ],
          ),
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
  const _RemindersStrip({required this.state, this.onOpenTab});

  final AppState state;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    if (state.remindersTotal == 0) return const SizedBox.shrink();
    return MmCard(
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
