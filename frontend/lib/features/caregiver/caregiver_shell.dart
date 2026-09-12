import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/voice_nav_host.dart';
import 'activity/caregiver_activity_screen.dart';
import 'dashboard/caregiver_dashboard_screen.dart';
import 'doctor/doctor_care_screen.dart';
import 'memory_profile/memory_profile_screen.dart';
import 'profile/caregiver_profile_screen.dart';
import 'progress/patient_progress_screen.dart';
import 'reminders/caregiver_reminders_screen.dart';
import 'reports/reports_screen.dart';
import 'safety/safe_zone_screen.dart';
import 'wellbeing/wellbeing_screen.dart';

import '../../app/routes/app_routes.dart';
import '../intake/welcome_screens.dart';
import '../../l10n/app_localizations.dart';

/// The caregiver application shell with a bottom navigation bar and drawer navigation.
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _handleLogout(BuildContext context) async {
    Navigator.of(context).maybePop();
    final AppState state = AppScope.read(context);
    final AuthService? service = AuthScope.maybeOf(context);
    await state.signOutAccount();
    state.setRole(AppRole.none);
    if (service != null) {
      try {
        await service.signOut();
      } catch (error) {
        debugPrint('CaregiverShell: sign out failed ($error)');
      }
    }
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  Future<void> _handleSwitchRole(BuildContext context) async {
    Navigator.of(context).maybePop();
    final AppState state = AppScope.read(context);
    state.setRole(AppRole.none);
    if (!context.mounted) return;
    Nav.rootTo(context, const WelcomeScreen());
  }

  // ── Navigation destinations ──────────────────────────────────────────────

  static const List<_NavDest> _destinations = <_NavDest>[
    _NavDest(
        label: 'Overview',
        icon: Icons.space_dashboard_outlined,
        activeIcon: Icons.space_dashboard_rounded),
    _NavDest(
        label: 'Patient Progress',
        icon: Icons.show_chart_outlined,
        activeIcon: Icons.show_chart_rounded),
    _NavDest(
        label: 'Cognitive Activities',
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights_rounded),
    _NavDest(
        label: 'Mood & Wellbeing',
        icon: Icons.sentiment_satisfied_outlined,
        activeIcon: Icons.sentiment_satisfied_alt_rounded),
    _NavDest(
        label: 'Memories & Family',
        icon: Icons.favorite_outline_rounded,
        activeIcon: Icons.favorite_rounded),
    _NavDest(
        label: 'Safety',
        icon: Icons.shield_outlined,
        activeIcon: Icons.shield_rounded),
    _NavDest(
        label: 'Doctor & Care',
        icon: Icons.medical_services_outlined,
        activeIcon: Icons.medical_services_rounded),
    _NavDest(
        label: 'Reports',
        icon: Icons.folder_open_outlined,
        activeIcon: Icons.folder_rounded),
    _NavDest(
        label: 'Reminders',
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded),
    _NavDest(
        label: 'Patient Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded),
  ];

  void _go(int i) {
    setState(() => _index = i);
    _scaffoldKey.currentState?.closeDrawer();
  }

  // ── Voice navigation ─────────────────────────────────────────────────────

  static const Set<VoiceDestination> _voiceDestinations =
      <VoiceDestination>{
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
      case VoiceDestination.dashboard:
      case VoiceDestination.home:
        _go(0);
      case VoiceDestination.patient:
        _go(1);
      case VoiceDestination.activityLog:
        _go(2);
      case VoiceDestination.reminders:
        _go(8);
      case VoiceDestination.profile:
        _go(9);
      case VoiceDestination.safeZone:
        _go(5);
      default:
        return false;
    }
    return true;
  }

  // ── Screen pages ─────────────────────────────────────────────────────────

  Widget _page(int i) => switch (i) {
        0 => CaregiverDashboardScreen(onOpenTab: _go),
        1 => const PatientProgressScreen(),
        2 => const CaregiverActivityScreen(),
        3 => const WellbeingScreen(),
        4 => const MemoryProfileScreen(),
        5 => const SafeZoneScreen(),
        6 => const DoctorCareScreen(),
        7 => const ReportsScreen(),
        8 => const CaregiverRemindersScreen(),
        9 => const CaregiverProfileScreen(),
        _ => const CaregiverDashboardScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _CaregiverDrawer(
        patient: state.patient,
        caregiverName: 'Priya',
        index: _index,
        destinations: _destinations,
        onSelect: _go,
        onSignOut: () => _handleSwitchRole(context),
        onLogOut: () => _handleLogout(context),
      ),
      bottomNavigationBar: _CaregiverBottomNavBar(
        currentIndex: _index,
        onSelectIndex: _go,
      ),
      body: VoiceNavHost(
        destinations: _voiceDestinations,
        onNavigate: _onVoiceNavigate,
        accent: AppColors.primary,
        child: Column(
          children: <Widget>[
            // ── Top app bar with hamburger ──────────────────────────────
            SafeArea(
              bottom: false,
              child: _CaregiverTopAppBar(
                title: _destinations[_index].label,
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                onHomeTap: _index != 0 ? () => _go(0) : null,
                state: state,
              ),
            ),
            // ── Page body ───────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _index,
                children: List<Widget>.generate(
                    _destinations.length, (int i) => _page(i)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top app bar ───────────────────────────────────────────────────────────────

class _CaregiverTopAppBar extends StatelessWidget {
  const _CaregiverTopAppBar({
    required this.title,
    required this.onMenuTap,
    this.onHomeTap,
    required this.state,
  });
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback? onHomeTap;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: <Widget>[
          RoundIconButton(
            icon: Icons.menu_rounded,
            size: 34,
            onPressed: onMenuTap,
            tooltip: 'Open navigation',
          ),
          if (onHomeTap != null) ...<Widget>[
            const SizedBox(width: 2),
            RoundIconButton(
              icon: Icons.home_rounded,
              size: 34,
              onPressed: onHomeTap!,
              tooltip: 'Overview dashboard',
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: AppText.h3.wght(800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Notification bell (mock badge)
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              RoundIconButton(
                icon: Icons.notifications_outlined,
                size: 34,
                tooltip: 'Notifications',
                onPressed: () {},
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: AppColors.terracotta,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('3',
                        style: AppText.caption
                            .tint(Colors.white)
                            .copyWith(fontSize: 9)),
                  ),
                ),
              ),
            ],
          ),
          // Connectivity indicator
          if (state.offline)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: SyncStatusChip(label: 'Offline', isOffline: true),
            )
          else if (state.pendingSync > 0)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: SyncStatusChip(
                  label: 'Syncing…', isOffline: false),
            ),
        ],
      ),
    );
  }
}

// ── Navigation Drawer ─────────────────────────────────────────────────────────

class _CaregiverDrawer extends StatelessWidget {
  const _CaregiverDrawer({
    required this.patient,
    required this.caregiverName,
    required this.index,
    required this.destinations,
    required this.onSelect,
    required this.onSignOut,
    required this.onLogOut,
  });

  final dynamic patient; // Patient
  final String caregiverName;
  final int index;
  final List<_NavDest> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      width: 280,
      child: Column(
        children: <Widget>[
          // ── Drawer header ────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: _DrawerHeader(
                patient: patient, caregiverName: caregiverName),
          ),
          const Divider(color: AppColors.hairline, height: 1),
          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: <Widget>[
                for (int i = 0; i < destinations.length; i++)
                  _NavItem(
                    dest: destinations[i],
                    selected: index == i,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.hairline, height: 1),
          // ── Footer ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListRow(
                  leading: const SoftIcon(
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.inkMuted,
                      size: 38),
                  title: 'Switch Role',
                  subtitle: 'Return to role selector',
                  onTap: onSignOut,
                ),
                const SizedBox(height: 4),
                ListRow(
                  leading: const SoftIcon(
                      icon: Icons.logout_rounded,
                      color: AppColors.danger,
                      size: 38),
                  title: 'Log Out',
                  subtitle: 'Sign out of your account',
                  onTap: onLogOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.patient, required this.caregiverName});
  final dynamic patient;
  final String caregiverName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, 14),
      color: AppColors.primaryTint.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const BrandMark(size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text('SmaranSaathi', style: AppText.h3.tint(AppColors.primaryDeep)),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text('CARING FOR', style: AppText.overline),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              SceneImage(
                sceneId: patient.portraitScene as String,
                size: 44,
                circle: true,
                borderColor: Colors.white,
                borderWidth: 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(patient.name as String,
                        style: AppText.body.wght(700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${patient.age} years · ${patient.location}',
                        style: AppText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Caregiver: $caregiverName', style: AppText.caption),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.dest, required this.selected, required this.onTap});
  final _NavDest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? AppColors.primary : AppColors.inkSoft;
    final Color bg =
        selected ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent;

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Corners.r(Corners.md),
        ),
        child: Row(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? dest.activeIcon : dest.icon,
                key: ValueKey<bool>(selected),
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                dest.label,
                style: AppText.body
                    .wght(selected ? 700 : 500)
                    .tint(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _NavDest {
  const _NavDest(
      {required this.label,
      required this.icon,
      required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _CaregiverBottomNavBar extends StatelessWidget {
  const _CaregiverBottomNavBar({
    required this.currentIndex,
    required this.onSelectIndex,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // Home first. The dashboard is where a caregiver actually lives
              // and it was previously reachable only through the drawer.
              _BottomNavItem(
                icon: Icons.space_dashboard_outlined,
                activeIcon: Icons.space_dashboard_rounded,
                label: AppLocalizations.of(context).caregiverNavDashboard,
                selected: currentIndex == 0,
                color: AppColors.plum,
                onTap: () => onSelectIndex(0),
              ),
              _BottomNavItem(
                icon: Icons.shield_outlined,
                activeIcon: Icons.shield_rounded,
                label: 'Safe Zone',
                selected: currentIndex == 5,
                color: AppColors.primary,
                onTap: () => onSelectIndex(5),
              ),
              _BottomNavItem(
                icon: Icons.medical_services_outlined,
                activeIcon: Icons.medical_services_rounded,
                label: 'Doctors',
                selected: currentIndex == 6,
                color: AppColors.secondary,
                onTap: () => onSelectIndex(6),
              ),
              _BottomNavItem(
                icon: Icons.insert_chart_outlined_rounded,
                activeIcon: Icons.insert_chart_rounded,
                label: 'Reports',
                selected: currentIndex == 7,
                color: AppColors.seriesTeal,
                onTap: () => onSelectIndex(7),
              ),
              _BottomNavItem(
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Reminders',
                selected: currentIndex == 8,
                color: AppColors.terracotta,
                onTap: () => onSelectIndex(8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = selected ? color : AppColors.inkMuted;

    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: Corners.r(Corners.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: activeColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppText.caption.sized(10).wght(selected ? 800 : 600).tint(activeColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
