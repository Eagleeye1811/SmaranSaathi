import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../core/widgets/voice_nav_host.dart';
import '../../l10n/app_localizations.dart';
import 'assistant/assistant_screen.dart';
import 'games/game_hub_screen.dart';
import 'health/care_plan_screen.dart';
import 'health/cognitive_profile_screen.dart';
import 'health/health_dashboard_screen.dart';
import 'health/report_screen.dart';
import 'memories/memory_wallet_screen.dart';
import 'profile/patient_profile_screen.dart';
import 'safety/return_home_banner.dart';
import 'today/today_screen.dart';
import 'wellness/wellness_corner_screen.dart';

/// The patient application: main destinations, large targets, no nesting.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  /// One entry per child of the `IndexedStack` below, **in the same order**.
  ///
  /// Four, not five: the profile moved to the top right of `PatientTopBar`,
  /// alongside reminders, matching where the caregiver's own two sit. Both
  /// are reached for at a moment rather than browsed, and four destinations
  /// leave the bar's targets as wide as this reader needs them.
  static const int _destinationCount = 4;

  /// Localised, so the bar reads in whatever language the app is set to.
  static List<NavDestination> _destinationsFor(AppLocalizations l) => <NavDestination>[
        NavDestination(l.patientNavHome, Icons.home_outlined, Icons.home_rounded),
        NavDestination(
            l.patientNavActivities, Icons.extension_outlined, Icons.extension_rounded),
        NavDestination(l.patientNavWellness, Icons.spa_outlined, Icons.spa_rounded),
        NavDestination(l.patientNavCompanion, Icons.forum_outlined, Icons.forum_rounded),
      ];

  void _go(int i) => setState(() => _index = i);

  static const Set<VoiceDestination> _voiceDestinations = <VoiceDestination>{
    VoiceDestination.home,
    VoiceDestination.today,
    VoiceDestination.reminders,
    VoiceDestination.activities,
    VoiceDestination.companion,
    VoiceDestination.profile,
    VoiceDestination.memories,
    VoiceDestination.memoryLane,
    VoiceDestination.carePlan,
    VoiceDestination.report,
    VoiceDestination.progress,
  };

  bool _onVoiceNavigate(VoiceDestination destination) {
    switch (destination) {
      case VoiceDestination.home:
        _go(0);
      case VoiceDestination.today:
      case VoiceDestination.reminders:
        Nav.open(context, const TodayScreen());
      case VoiceDestination.activities:
        _go(1);
      case VoiceDestination.companion:
        _go(3);
      case VoiceDestination.profile:
        Nav.open(context, const PatientProfileScreen());
      case VoiceDestination.memories:
        Nav.push(context, const MemoryWalletScreen());
      case VoiceDestination.carePlan:
        Nav.push(context, const CarePlanScreen());
      case VoiceDestination.report:
        Nav.push(context, const ReportScreen());
      case VoiceDestination.progress:
        Nav.push(context, const CognitiveProfileScreen());
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final List<NavDestination> destinations = _destinationsFor(l);
    return Scaffold(
      backgroundColor: state.highContrast ? Colors.white : AppColors.background,
      body: ReturnHomeBanner(
        child: VoiceNavHost(
          destinations: _voiceDestinations,
          onNavigate: _onVoiceNavigate,
          accent: AppColors.plum,
          child: IndexedStack(
            index: _index,
            children: <Widget>[
              HealthDashboardScreen(onOpenTab: (int tabIndex) {
                // 1 is reminders, which is a pushed screen rather than a
                // destination; everything above it shifts down by one to skip
                // the gap. Clamped, because the bar is now four wide and an
                // index past the end would throw rather than do nothing.
                if (tabIndex == 1) {
                  Nav.open(context, const TodayScreen());
                } else {
                  final int target = tabIndex > 1 ? tabIndex - 1 : tabIndex;
                  _go(target.clamp(0, _destinationCount - 1));
                }
              }),
              const GameHubScreen(),
              const WellnessCornerScreen(),
              const AssistantScreen(embedded: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppNavBar(
        destinations: destinations,
        index: _index,
        onChanged: _go,
        large: true,
        accent: AppColors.primary,
      ),
    );
  }
}
