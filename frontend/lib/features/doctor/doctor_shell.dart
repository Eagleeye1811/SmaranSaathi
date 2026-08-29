import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../core/widgets/voice_nav_host.dart';
import '../../l10n/app_localizations.dart';
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

  void _go(int i) => setState(() => _index = i);

  /// The clinic's five tabs. A clinician with gloves on, or one reading a
  /// chart in the other hand, gets to the alerts list without looking down.
  static const Set<VoiceDestination> _voiceDestinations = <VoiceDestination>{
    VoiceDestination.overview,
    VoiceDestination.home,
    VoiceDestination.patients,
    VoiceDestination.analytics,
    VoiceDestination.alerts,
    VoiceDestination.profile,
  };

  bool _onVoiceNavigate(VoiceDestination destination) {
    switch (destination) {
      case VoiceDestination.overview:
      case VoiceDestination.home:
        _go(0);
      case VoiceDestination.patients:
        _go(1);
      case VoiceDestination.analytics:
        _go(2);
      case VoiceDestination.alerts:
        _go(3);
      case VoiceDestination.profile:
        _go(4);
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<NavDestination> destinations = <NavDestination>[
      NavDestination(l.doctorTabOverview, Icons.dashboard_outlined, Icons.dashboard_rounded),
      NavDestination(l.doctorTabPatients, Icons.groups_outlined, Icons.groups_rounded),
      NavDestination(
          l.doctorTabAnalytics, Icons.query_stats_outlined, Icons.query_stats_rounded),
      NavDestination(l.doctorTabAlerts, Icons.notification_important_outlined,
          Icons.notification_important_rounded),
      NavDestination(l.doctorTabProfile, Icons.person_outline_rounded, Icons.person_rounded),
    ];
    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        body: VoiceNavHost(
          destinations: _voiceDestinations,
          onNavigate: _onVoiceNavigate,
          accent: AppColors.clinicAccent,
          child: IndexedStack(
            index: _index,
            children: <Widget>[
              DoctorOverviewScreen(onOpenTab: _go),
              const DoctorPatientsScreen(),
              const DoctorAnalyticsScreen(),
              const DoctorAlertsScreen(),
              const DoctorProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: AppNavBar(
          destinations: destinations,
          index: _index,
          onChanged: _go,
          accent: AppColors.clinicAccent,
        ),
      ),
    );
  }
}
