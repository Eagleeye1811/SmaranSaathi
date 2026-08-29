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
import 'memory_home/memory_home_screen.dart';
import 'profile/patient_profile_screen.dart';
import 'safety/return_home_banner.dart';
import 'today/today_screen.dart';

/// The patient application: four destinations, large targets, no nesting.
///
/// The destinations follow the journey rather than the feature list — where am
/// I now, what do I do today, where is it heading, who can explain it. The
/// memory wallet and the daily check-in are still there, reached from the
/// dashboard, because they support the journey rather than being the point of
/// it.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination('Home', Icons.home_outlined, Icons.home_rounded),
    NavDestination('Activities', Icons.extension_outlined, Icons.extension_rounded),
    NavDestination('Companion', Icons.forum_outlined, Icons.forum_rounded),
    NavDestination('Today', Icons.notifications_outlined, Icons.notifications_rounded),
    NavDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _go(int i) => setState(() => _index = i);

  /// Everywhere a patient can be taken by voice.
  ///
  /// Wider than the five tabs: the screens reached *from* the dashboard are
  /// exactly the ones a patient struggles to find by tapping, so being able to
  /// simply ask for "my report" is where voice earns its place.
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

  /// Tab switches happen in place; everything else is pushed, which is also
  /// what makes "go back" meaningful afterwards.
  bool _onVoiceNavigate(VoiceDestination destination) {
    switch (destination) {
      case VoiceDestination.home:
        _go(0);
      // The Today tab *is* the reminder list, so both names land there rather
      // than one of them being a dead end.
      case VoiceDestination.today:
      case VoiceDestination.reminders:
        _go(1);
      case VoiceDestination.activities:
        _go(2);
      case VoiceDestination.companion:
        _go(3);
      case VoiceDestination.profile:
        _go(4);
      case VoiceDestination.memories:
        Nav.push(context, const MemoryWalletScreen());
      case VoiceDestination.memoryLane:
        Nav.push(context, const MemoryHomeScreen());
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
      // Above the tabs, not inside one: someone who has wandered needs to see
      // it whichever screen they happen to be on.
      body: ReturnHomeBanner(
        child: VoiceNavHost(
          destinations: _voiceDestinations,
          onNavigate: _onVoiceNavigate,
          accent: AppColors.plum,
          child: IndexedStack(
            index: _index,
            children: <Widget>[
              HealthDashboardScreen(onOpenTab: _go),
              const TodayScreen(),
              const GameHubScreen(),
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
