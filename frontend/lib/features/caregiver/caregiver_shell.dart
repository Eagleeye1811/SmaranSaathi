import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../core/widgets/voice_nav_host.dart';
import '../../l10n/app_localizations.dart';
import 'activity/caregiver_activity_screen.dart';
import 'dashboard/caregiver_dashboard_screen.dart';
import 'memory_profile/memory_profile_screen.dart';
import 'profile/caregiver_profile_screen.dart';
import 'reminders/caregiver_reminders_screen.dart';
import 'safety/safe_zone_screen.dart';
import '../../app/routes/app_routes.dart';

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

  /// The caregiver's five tabs. A caregiver is usually standing up with the
  /// patient rather than sitting with the phone, so reaching a tab by name is
  /// worth as much here as it is on the patient side.
  static const Set<VoiceDestination> _voiceDestinations = <VoiceDestination>{
    VoiceDestination.dashboard,
    VoiceDestination.home,
    VoiceDestination.patient,
    VoiceDestination.activityLog,
    VoiceDestination.reminders,
    VoiceDestination.safeZone,
    VoiceDestination.profile,
  };

  bool _onVoiceNavigate(VoiceDestination destination) {
    switch (destination) {
      // "Home" and "dashboard" are the same place to a caregiver, so both
      // names work rather than one of them being refused.
      case VoiceDestination.dashboard:
      case VoiceDestination.home:
        _go(0);
      case VoiceDestination.patient:
        _go(1);
      case VoiceDestination.activityLog:
        _go(2);
      case VoiceDestination.reminders:
        _go(3);
      case VoiceDestination.profile:
        _go(4);
      // Pushed rather than a sixth tab: a six-tab bar is where a caregiver
      // starts mis-tapping, and this is a screen you open on purpose.
      case VoiceDestination.safeZone:
        Nav.push(context, const SafeZoneScreen());
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: VoiceNavHost(
        destinations: _voiceDestinations,
        onNavigate: _onVoiceNavigate,
        accent: AppColors.primary,
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            CaregiverDashboardScreen(onOpenTab: _go),
            const MemoryProfileScreen(),
            const CaregiverActivityScreen(),
            const CaregiverRemindersScreen(),
            const CaregiverProfileScreen(),
          ],
        ),
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
