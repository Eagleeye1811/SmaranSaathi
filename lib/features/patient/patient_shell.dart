import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/app_nav_bar.dart';
import 'games/game_hub_screen.dart';
import 'home/patient_home_screen.dart';
import 'memories/memory_wallet_screen.dart';
import 'profile/patient_profile_screen.dart';
import 'today/today_screen.dart';

/// The patient application: five destinations, large targets, no nesting.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  static const List<NavDestination> _destinations = <NavDestination>[
    NavDestination('Home', Icons.home_outlined, Icons.home_rounded),
    NavDestination('Games', Icons.extension_outlined, Icons.extension_rounded),
    NavDestination('Memories', Icons.favorite_outline_rounded, Icons.favorite_rounded),
    NavDestination('Today', Icons.today_outlined, Icons.today_rounded),
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
          PatientHomeScreen(onOpenTab: _go),
          const GameHubScreen(),
          const MemoryWalletScreen(),
          const TodayScreen(),
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
