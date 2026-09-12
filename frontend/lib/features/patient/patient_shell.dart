import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../core/widgets/voice_nav_host.dart';
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
  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination('Home', Icons.home_outlined, Icons.home_rounded),
    NavDestination('Activities', Icons.extension_outlined, Icons.extension_rounded),
    NavDestination('Wellness', Icons.spa_outlined, Icons.spa_rounded),
    NavDestination('Companion', Icons.forum_outlined, Icons.forum_rounded),
    NavDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
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
        _go(4);
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
                if (tabIndex == 1) {
                  Nav.open(context, const TodayScreen());
                } else if (tabIndex > 1) {
                  _go(tabIndex - 1);
                } else {
                  _go(tabIndex);
                }
              }),
              const GameHubScreen(),
              const WellnessCornerScreen(),
              const AssistantScreen(embedded: true),
              const PatientProfileScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppNavBar(
        destinations: _destinations,
        index: _index,
        onChanged: _go,
        large: true,
        accent: AppColors.primary,
      ),
    );
  }
}
