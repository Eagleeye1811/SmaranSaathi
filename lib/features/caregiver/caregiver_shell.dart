import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/app_nav_bar.dart';
import 'activity/caregiver_activity_screen.dart';
import 'dashboard/caregiver_dashboard_screen.dart';
import 'memory_profile/memory_profile_screen.dart';
import 'profile/caregiver_profile_screen.dart';
import 'reminders/caregiver_reminders_screen.dart';

/// The caregiver application.
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;

  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    NavDestination('Patient', Icons.elderly_woman_outlined, Icons.elderly_woman_rounded),
    NavDestination('Activity', Icons.insights_outlined, Icons.insights_rounded),
    NavDestination('Reminders', Icons.notifications_none_rounded, Icons.notifications_rounded),
    NavDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          CaregiverDashboardScreen(onOpenTab: _go),
          const MemoryProfileScreen(),
          const CaregiverActivityScreen(),
          const CaregiverRemindersScreen(),
          const CaregiverProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        destinations: _destinations,
        index: _index,
        onChanged: _go,
        accent: AppColors.primary,
      ),
    );
  }
}
