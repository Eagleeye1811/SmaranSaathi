import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/daily.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/voice_nav_host.dart';
import 'dashboard/caregiver_dashboard_screen.dart';
import 'doctor/doctor_care_screen.dart';
import 'memory_profile/memory_profile_screen.dart';
import 'profile/caregiver_profile_screen.dart';
import 'reminders/caregiver_reminders_screen.dart';
import 'reports/reports_screen.dart';
import 'safety/safe_zone_screen.dart';
import 'wellbeing/wellbeing_screen.dart';

import '../../l10n/app_localizations.dart';

/// The caregiver application shell.
///
/// Every destination is on the bottom bar. There is no drawer: it held the
/// same list one scroll further away, and the two items that only lived there
/// — the caregiver's own profile, and the way out of the account — were the
/// ones people could not find. Signing out now belongs to that profile page,
/// which the bar reaches in one tap.
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;

  // ── Navigation destinations ──────────────────────────────────────────────

  static const List<_NavDest> _destinations = <_NavDest>[
    _NavDest(
        label: 'Overview',
        icon: Icons.space_dashboard_outlined,
        activeIcon: Icons.space_dashboard_rounded),
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
    // The caregiver's own page, not the patient's — it holds their name and
    // relation, the patient-facing accessibility settings they control, and
    // the way out of the account.
    _NavDest(
        label: 'My Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded),
  ];

  void _go(int i) => setState(() => _index = i);

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
      // "show me the patient" lands on their profile, and "the activity log"
      // on the dashboard: the progress and activity analytics that used to
      // answer both now sit on the dashboard itself.
      case VoiceDestination.patient:
        _go(7);
      case VoiceDestination.activityLog:
        _go(0);
      case VoiceDestination.reminders:
        _go(6);
      case VoiceDestination.profile:
        _go(7);
      case VoiceDestination.safeZone:
        _go(3);
      default:
        return false;
    }
    return true;
  }

  // ── Screen pages ─────────────────────────────────────────────────────────

  Widget _page(int i) => switch (i) {
        0 => CaregiverDashboardScreen(onOpenTab: _go),
        1 => const WellbeingScreen(),
        2 => const MemoryProfileScreen(),
        3 => const SafeZoneScreen(),
        4 => const DoctorCareScreen(),
        5 => const ReportsScreen(),
        6 => const CaregiverRemindersScreen(),
        7 => CaregiverProfileScreen(onOpenTab: _go),
        _ => const CaregiverDashboardScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
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
            // ── Top app bar ─────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: _CaregiverTopAppBar(
                title: _destinations[_index].label,
                state: state,
                index: _index,
                onGo: _go,
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
    required this.state,
    required this.index,
    required this.onGo,
  });

  final String title;
  final AppState state;

  /// The destination currently showing, so the header can mark its own two.
  final int index;
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, 12, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppText.h3.wght(800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
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

          // ── Reminders and the account ───────────────────────────────
          //
          // Top right rather than on the bar: both are reached for at a
          // moment — "mark the tablets done", "log out" — rather than
          // browsed, and taking them off the bar leaves five destinations,
          // which is what a thumb can pick between on a small phone.
          const SizedBox(width: 4),
          _HeaderAction(
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            selected: index == 6,
            tooltip: 'Reminders',
            // The count of what is still owed today, so the header answers
            // the question without being opened.
            badge: state.reminders.where((Reminder r) => !r.done).length,
            onTap: () => onGo(6),
          ),
          const SizedBox(width: 6),
          _HeaderAction(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            selected: index == 7,
            tooltip: 'My profile',
            onTap: () => onGo(7),
          ),
        ],
      ),
    );
  }
}

/// A round header button, marked when its own page is showing.
///
/// One colour for both, and it is the app's own: these are a matched pair
/// sitting side by side, so giving them a colour each made the header look
/// like two unrelated controls that happened to be adjacent.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  static const Color color = AppColors.primary;

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  /// Drawn as a dot in the corner when non-zero; no number, because the
  /// number is on the page and a two-digit badge on a 38 px circle is not
  /// readable anyway.
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AnimatedContainer(
              duration: Motion.quick,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? color : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : AppColors.hairline,
                ),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 19,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
            if (badge > 0 && !selected)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
              for (final _BottomDest d in destinations(context))
                _BottomNavItem(
                  icon: d.icon,
                  activeIcon: d.activeIcon,
                  label: d.label,
                  selected: currentIndex == d.index,
                  color: d.color,
                  onTap: () => onSelectIndex(d.index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bar's five destinations, in the order a caregiver's day runs: today,
  /// who is around them, where they are, who is treating them, the record.
  ///
  /// Reminders and the caregiver's own profile sit in the header instead —
  /// both are things you reach for at a moment rather than places you browse,
  /// and five is what a thumb can pick between on a 360 px phone. Mood &
  /// Wellbeing opens from the mood tile on the dashboard.
  static List<_BottomDest> destinations(BuildContext context) => <_BottomDest>[
        _BottomDest(
          index: 0,
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          label: AppLocalizations.of(context).caregiverNavDashboard,
          color: AppColors.plum,
        ),
        const _BottomDest(
          index: 2,
          icon: Icons.groups_2_outlined,
          activeIcon: Icons.groups_2_rounded,
          label: 'Family',
          color: AppColors.terracotta,
        ),
        const _BottomDest(
          index: 3,
          icon: Icons.location_on_outlined,
          activeIcon: Icons.location_on_rounded,
          label: 'Safe Zone',
          color: AppColors.primary,
        ),
        const _BottomDest(
          index: 4,
          icon: Icons.medical_services_outlined,
          activeIcon: Icons.medical_services_rounded,
          label: 'Doctors',
          color: AppColors.secondary,
        ),
        const _BottomDest(
          index: 5,
          icon: Icons.insert_chart_outlined_rounded,
          activeIcon: Icons.insert_chart_rounded,
          label: 'Reports',
          color: AppColors.seriesTeal,
        ),
      ];
}

@immutable
class _BottomDest {
  const _BottomDest({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });

  /// Index into `CaregiverShell._destinations`.
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
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
