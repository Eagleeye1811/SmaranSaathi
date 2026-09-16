import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../core/widgets/voice_nav_host.dart';
import '../../l10n/app_localizations.dart';
import 'alerts/doctor_alerts_screen.dart';
import 'appointments/doctor_appointments_screen.dart';
import 'chat/doctor_chats_screen.dart';
import 'overview/doctor_overview_screen.dart';
import 'patients/doctor_patients_screen.dart';
import 'profile/doctor_profile_screen.dart';

/// The clinician application shell.
/// Features a streamlined navigation bar (Overview, Patients, Chats, Appointments),
/// with Alerts and Profile accessible from the top bar header.
class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  /// The clinic's destinations reachable by voice.
  static const Set<VoiceDestination> _voiceDestinations = <VoiceDestination>{
    VoiceDestination.overview,
    VoiceDestination.home,
    VoiceDestination.patients,
    VoiceDestination.analytics,
    VoiceDestination.alerts,
    VoiceDestination.profile,
    VoiceDestination.chats,
  };

  bool _onVoiceNavigate(VoiceDestination destination) {
    switch (destination) {
      case VoiceDestination.overview:
      case VoiceDestination.home:
      case VoiceDestination.analytics:
        _go(0);
      case VoiceDestination.patients:
        _go(1);
      case VoiceDestination.chats:
        _go(2);
      case VoiceDestination.alerts:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DoctorAlertsScreen()),
        );
      case VoiceDestination.profile:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DoctorProfileScreen()),
        );
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    final int unreadChats = state.totalDoctorUnreadChats;

    final List<NavDestination> destinations = <NavDestination>[
      NavDestination(l.doctorTabOverview, Icons.dashboard_outlined, Icons.dashboard_rounded),
      NavDestination(l.doctorTabPatients, Icons.groups_outlined, Icons.groups_rounded),
      NavDestination(
        l.doctorTabChats,
        Icons.chat_bubble_outline_rounded,
        Icons.chat_rounded,
        badgeCount: unreadChats,
      ),
      NavDestination(l.doctorTabAppointments, Icons.calendar_month_outlined, Icons.calendar_month_rounded),
    ];

    return Theme(
      data: AppTheme.clinic(),
      child: VoiceNavHost(
        destinations: _voiceDestinations,
        onNavigate: _onVoiceNavigate,
        accent: AppColors.clinicAccent,
        showFloatingMic: false,
        child: Scaffold(
          backgroundColor: AppColors.clinicBackground,
          body: IndexedStack(
            index: _index,
            children: <Widget>[
              DoctorOverviewScreen(
                onOpenTab: _go,
                onOpenProfile: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DoctorProfileScreen()),
                  );
                },
              ),
              const DoctorPatientsScreen(),
              const DoctorChatsScreen(),
              const DoctorAppointmentsScreen(),
            ],
          ),
          bottomNavigationBar: AppNavBar(
            destinations: destinations,
            index: _index,
            onChanged: _go,
            accent: AppColors.clinicAccent,
          ),
        ),
      ),
    );
  }
}
