import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_nav_bar.dart';
import 'alerts/doctor_alerts_screen.dart';
import 'analytics/doctor_analytics_screen.dart';
import 'overview/doctor_overview_screen.dart';
import 'patients/doctor_patients_screen.dart';
import 'profile/doctor_profile_screen.dart';

/// The clinician application. Wrapped in the cooler clinical theme so it never
/// reads like the patient's warm experience.
class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _index = 0;

  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
    NavDestination('Patients', Icons.groups_outlined, Icons.groups_rounded),
    NavDestination('Analytics', Icons.query_stats_outlined, Icons.query_stats_rounded),
    NavDestination('Alerts', Icons.notification_important_outlined,
        Icons.notification_important_rounded),
    NavDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        body: IndexedStack(
          index: _index,
          children: <Widget>[
            DoctorOverviewScreen(onOpenTab: _go),
            const DoctorPatientsScreen(),
            const DoctorAnalyticsScreen(),
            const DoctorAlertsScreen(),
            const DoctorProfileScreen(),
          ],
        ),
        bottomNavigationBar: AppNavBar(
          destinations: _destinations,
          index: _index,
          onChanged: _go,
          accent: AppColors.clinicAccent,
        ),
      ),
    );
  }
}
