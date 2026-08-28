import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/app_nav_bar.dart';
import 'assistant/assistant_screen.dart';
import 'games/game_hub_screen.dart';
import 'health/health_dashboard_screen.dart';
import 'profile/patient_profile_screen.dart';
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
    NavDestination('Today', Icons.notifications_outlined, Icons.notifications_rounded),
    NavDestination('Activities', Icons.extension_outlined, Icons.extension_rounded),
    NavDestination('Companion', Icons.forum_outlined, Icons.forum_rounded),
    NavDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Scaffold(
      backgroundColor: state.highContrast ? Colors.white : AppColors.background,
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HealthDashboardScreen(onOpenTab: _go),
          const TodayScreen(),
          const GameHubScreen(),
          const AssistantScreen(embedded: true),
          const PatientProfileScreen(),
        ],
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
