import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/app_nav_bar.dart';
import '../../core/widgets/voice_nav_host.dart';
import '../../l10n/app_localizations.dart';
// assistant_screen is still referenced by HealthDashboardScreen internally
// but is no longer used as the companion destination in the shell.
import 'asha/asha_screen.dart';
import 'games/game_hub_screen.dart';
import 'health/care_plan_screen.dart';
import 'health/cognitive_profile_screen.dart';
import 'health/health_dashboard_screen.dart';
import 'health/report_screen.dart';
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
  /// Four destinations: Home, Activities, Wellness, Asha.
  /// Asha is a persistent nav tab rather than a pushed screen so the patient
  /// can reach their companion from anywhere with one large tap target.
  static const int _destinationCount = 4;

  /// Localised, so the bar reads in whatever language the app is set to.
  /// 'Asha' is a proper name and is not translated.
  static List<NavDestination> _destinationsFor(AppLocalizations l) => <NavDestination>[
        NavDestination(l.patientNavHome, Icons.home_outlined, Icons.home_rounded),
        NavDestination(
            l.patientNavActivities, Icons.extension_outlined, Icons.extension_rounded),
        NavDestination(l.patientNavWellness, Icons.spa_outlined, Icons.spa_rounded),
        const NavDestination(
            'Asha', Icons.record_voice_over_outlined, Icons.record_voice_over_rounded),
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
        // Switch to the Asha tab (index 3) — same as tapping it in the bar.
        _go(3);
      case VoiceDestination.profile:
        Nav.open(context, const PatientProfileScreen());
      case VoiceDestination.memories:
        Nav.open(context, const AshaScreen());
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
    return VoiceNavHost(
      destinations: _voiceDestinations,
      onNavigate: _onVoiceNavigate,
      accent: AppColors.primary,
      showFloatingMic: false,
      child: Scaffold(
        backgroundColor: state.highContrast ? Colors.white : AppColors.background,
        body: ReturnHomeBanner(
          child: IndexedStack(
            index: _index,
            children: <Widget>[
              HealthDashboardScreen(onOpenTab: (int tabIndex) {
                // Dashboard tab indices (from action cards):
                //   0 → Home, 1 → Today (pushed), 2 → Activities,
                //   3 → Wellness, 4 → Asha.
                // Everything above 1 shifts down by one to skip the
                // non-tab Reminders/Today screen (shell indices 0..3).
                if (tabIndex == 1) {
                  Nav.open(context, const TodayScreen());
                } else {
                  final int target = tabIndex > 1 ? tabIndex - 1 : tabIndex;
                  _go(target.clamp(0, _destinationCount - 1));
                }
              }),
              const GameHubScreen(),
              const WellnessCornerScreen(),
              AshaScreen(embedded: true, active: _index == 3),
            ],
          ),
        ),
        bottomNavigationBar: AppNavBar(
          destinations: destinations,
          index: _index,
          onChanged: _go,
          large: true,
          accent: AppColors.primary,
        ),
      ),
    );
  }
}
