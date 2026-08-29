import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../l10n/app_localizations.dart';
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

  List<NavDestination> _destinations(AppLocalizations l) => <NavDestination>[
        NavDestination(
            l.caregiverNavDashboard, Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
        NavDestination(
            l.caregiverNavPatient, Icons.elderly_woman_outlined, Icons.elderly_woman_rounded),
        NavDestination(l.caregiverNavActivity, Icons.insights_outlined, Icons.insights_rounded),
        NavDestination(l.caregiverNavReminders, Icons.notifications_none_rounded,
            Icons.notifications_rounded),
        NavDestination(l.caregiverNavProfile, Icons.person_outline_rounded, Icons.person_rounded),
      ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
        destinations: _destinations(l),
        index: _index,
        onChanged: _go,
        accent: AppColors.primary,
      ),
    );
  }
}
