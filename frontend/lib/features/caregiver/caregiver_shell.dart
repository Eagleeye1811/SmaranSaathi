import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/daily.dart';
import '../../core/services/app_state.dart';
import '../../core/voice/voice_nav_intent.dart';
import '../../core/widgets/brand.dart';
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

  @override
  void initState() {
    super.initState();
    // Once per time the caregiver lands on this shell (fresh login, or
    // returning to the app), not once per tab switch — `initState` only
    // fires when this State is created, and switching tabs below just
    // changes `_index` on the same instance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePromptForCaregiverNote(AppScope.of(context));
    });
  }

  /// Nudges the caregiver to add at least one note or concern check-in this
  /// cycle — without this, a patient could finish all 7 activities with the
  /// doctor's weekly report carrying no caregiver input at all, simply
  /// because the notes card in Reports is easy to miss.
  Future<void> _maybePromptForCaregiverNote(AppState state) async {
    if (state.concernUpdatesThisCycle.isNotEmpty || state.notesThisCycle.isNotEmpty) return;

    final TextEditingController controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('A quick note for the doctor?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              "Have you noticed anything — better or worse — in how ${state.patient.shortName} "
              "has been doing? A quick note helps their doctor, and takes a moment.",
              style: AppText.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Seemed a bit more forgetful about names this week',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: Corners.r(Corners.md)),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              state.addCaregiverNote(controller.text);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save note'),
          ),
        ],
      ),
    );
  }

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

    return VoiceNavHost(
      destinations: _voiceDestinations,
      onNavigate: _onVoiceNavigate,
      accent: AppColors.primary,
      showFloatingMic: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _CaregiverBottomNavBar(
          currentIndex: _index,
          onSelectIndex: _go,
        ),
        body: Column(
          children: <Widget>[
            // ── Header ──────────────────────────────────────────────────
            //
            // One line: the brand, and the two things reached for at a
            // moment — reminders, the account — rather than browsed. A page
            // title used to sit here too, but it only repeated the name the
            // bar below already shows selected.
            //
            // Opaque on purpose, not just bordered: Android's default
            // stretch-overscroll effect paints a dragged list's content
            // outside its own normal bounds while the drag is active, and a
            // transparent header let that bleed straight through it — the
            // caregiver's own greeting appeared to scroll up behind the
            // brand row. A solid fill stops that fully.
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
              child: SafeArea(
                bottom: false,
                child: BrandHeaderBar(
                  trailing: _CaregiverHeaderActions(
                    state: state,
                    index: _index,
                    onGo: _go,
                  ),
                ),
              ),
            ),
            // ── Page body ───────────────────────────────────────────────
            //
            // Clipped to its own bounds for the same reason the header
            // above is opaque now: the stretch-overscroll effect otherwise
            // paints past the top of this box, over the header, regardless
            // of what the header itself looks like.
            Expanded(
              child: ClipRect(
                child: IndexedStack(
                  index: _index,
                  children: List<Widget>.generate(
                      _destinations.length, (int i) => _page(i)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header actions ─────────────────────────────────────────────────────────

/// The right-hand cluster of the caregiver header: a connectivity chip when
/// there is something to say, then reminders and the account.
///
/// Off the bottom bar rather than on it — both are reached for at a moment
/// rather than browsed, and taking them off the bar leaves five destinations,
/// which is what a thumb can pick between on a small phone.
class _CaregiverHeaderActions extends StatelessWidget {
  const _CaregiverHeaderActions({
    required this.state,
    required this.index,
    required this.onGo,
  });

  final AppState state;

  /// The destination currently showing, so the header can mark its own two.
  final int index;
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (state.offline)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: SyncStatusChip(label: 'Offline', isOffline: true),
          )
        else if (state.pendingSync > 0)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: SyncStatusChip(label: 'Syncing…', isOffline: false),
          ),
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
    final VoiceNavHostState? voiceNav = VoiceNavScope.maybeOf(context);
    const double bulge = 22.0;
    const double micDiameter = 64.0;
    final List<_BottomDest> dests = destinations(context);

    final Widget barContent = Container(
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
            children: <Widget>[
              // Left side: Dashboard, Family
              for (int i = 0; i < 2 && i < dests.length; i++)
                _BottomNavItem(
                  icon: dests[i].icon,
                  activeIcon: dests[i].activeIcon,
                  label: dests[i].label,
                  selected: currentIndex == dests[i].index,
                  color: dests[i].color,
                  onTap: () => onSelectIndex(dests[i].index),
                ),
              if (voiceNav != null) const SizedBox(width: 74),
              // Right side: Doctors, Reports
              for (int i = 2; i < dests.length; i++)
                _BottomNavItem(
                  icon: dests[i].icon,
                  activeIcon: dests[i].activeIcon,
                  label: dests[i].label,
                  selected: currentIndex == dests[i].index,
                  color: dests[i].color,
                  onTap: () => onSelectIndex(dests[i].index),
                ),
            ],
          ),
        ),
      ),
    );

    if (voiceNav == null) {
      return barContent;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: bulge),
          child: barContent,
        ),
        Positioned(
          top: 0,
          child: VoiceMicButton(
            accent: AppColors.primary,
            diameter: micDiameter,
            iconSize: 32,
            elevation: 6,
            borderWidth: 4.0,
            borderColor: Colors.white,
            onTap: voiceNav.openPanel,
          ),
        ),
      ],
    );
  }

  /// The bar's four destinations, arranged symmetrically around the center mic:
  /// Left: Dashboard, Family
  /// Center: Voice Mic
  /// Right: Doctors, Reports
  static List<_BottomDest> destinations(BuildContext context) => <_BottomDest>[
        _BottomDest(
          index: 0,
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          label: AppLocalizations.of(context).caregiverNavDashboard,
          color: AppColors.primary,
        ),
        const _BottomDest(
          index: 2,
          icon: Icons.groups_2_outlined,
          activeIcon: Icons.groups_2_rounded,
          label: 'Family',
          color: AppColors.primary,
        ),
        const _BottomDest(
          index: 4,
          icon: Icons.medical_services_outlined,
          activeIcon: Icons.medical_services_rounded,
          label: 'Doctors',
          color: AppColors.primary,
        ),
        const _BottomDest(
          index: 5,
          icon: Icons.insert_chart_outlined_rounded,
          activeIcon: Icons.insert_chart_rounded,
          label: 'Reports',
          color: AppColors.primary,
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
