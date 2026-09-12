import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/app_nav_bar.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../widgets/patient_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// "Today" — reminders and interactive status check-in.
///
/// Refactored to include:
/// 1. Interactive Companion Card at the top (Zomato/Uber notification-style status updater).
/// 2. Reminders creation option with a beautiful, theme-consistent Time Slider.
/// 3. Clear grid of exactly 6 categories with FittedBox to prevent text cutoffs or wrapping.
/// 4. Dynamic companion reactions based on the selected reminder category and time.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _activeMessageIndex = 0;
  double _companionScale = 1.0;

  // List of motivational interactive greetings / tips (shortened to prevent wrapping)
  final List<String> _companionTips = <String>[
    'You are doing great today!',
    'Remember to drink water!',
    'Saathi is here with you.',
    'Take your meds on time!'
  ];

  void _interactWithCompanion() {
    setState(() {
      _companionScale = 1.15;
      _activeMessageIndex = (_activeMessageIndex + 1) % 4;
    });
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _companionScale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    final List<Reminder> reminders = state.reminders;

    final String dateLabel = _formattedDate(l);
    final List<String> companionTips = _companionTips;

    final String notificationHeadline = l.todayStatusLabel;
    const IconData notificationIcon = Icons.today_rounded;
    const Color notificationColor = AppColors.primary;

    return MotifBackground(
      opacity: 0.035,
      washColors: <Color>[
        AppColors.primaryTint.withValues(alpha: 0.9),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: <Widget>[
              const PatientTopBar(showExit: false),

              // ── Interactive Companion Status Card (Zomato/Uber style) ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, Insets.md),
                child: FadeInUp(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: Corners.r(Corners.lg),
                      border: Border.all(color: AppColors.hairline.withValues(alpha: 0.8)),
                      boxShadow: AppColors.softShadow(y: 4, blur: 16, opacity: 0.08),
                    ),
                    padding: const EdgeInsets.all(Insets.md),
                    child: Row(
                      children: <Widget>[
                        // Pulsing Companion Avatar
                        GestureDetector(
                          onTap: _interactWithCompanion,
                          child: AnimatedScale(
                            scale: _companionScale,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutBack,
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                const Companion(
                                  state: CompanionState.happy,
                                  size: 64,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Live Status Block
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: notificationColor.withValues(alpha: 0.1),
                                  borderRadius: Corners.r(Corners.pill),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(notificationIcon, size: 12, color: notificationColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      notificationHeadline,
                                      style: AppText.label.sized(10.5).wght(800).tint(notificationColor),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  companionTips[_activeMessageIndex],
                                  key: ValueKey<int>(_activeMessageIndex),
                                  style: AppText.caption.sized(12.5),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Reminders Timeline header ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.todayRemindersTitle,
                            style: AppText.patientTitle.sized(24),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: AppText.caption.sized(12.5).wght(600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l.todayDoneCount(state.remindersDone, state.remindersTotal),
                      style: AppText.body.wght(700).tint(AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 80),
                  children: <Widget>[
                    if (state.offline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: OfflineBanner(pending: state.pendingSync),
                      ),

                    if (reminders.isEmpty)
                      FadeInUp(
                        delayMs: 80,
                        child: _EmptyRemindersCard(l: l),
                      )
                    else
                      for (int i = 0; i < reminders.length; i++)
                        FadeInUp(
                          delayMs: 80 + i * 30,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ReminderRow(
                              reminder: reminders[i],
                              onToggle: () => state.toggleReminder(reminders[i].id),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddReminderSheet(context, state),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 6,
            icon: const Icon(Icons.add_alarm_rounded, size: 24),
            label: Text(l.todayCreateReminderButton,
                style: AppText.body.wght(800).tint(Colors.white)),
          ),
        ),
      ),
    );
  }

  // ── Show Add Reminder Modal Sheet ──────────────────────────────────────────
  void _showAddReminderSheet(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AddReminderSheet(
          onAdd: (title, timeStr, minutes, kind, detail, smsEnabled) {
            state.addReminder(title, timeStr, minutes, kind, detail: detail, smsEnabled: smsEnabled);
          },
        );
      },
    );
  }

  static String _formattedDate(AppLocalizations l) {
    final DateTime now = DateTime.now();
    final List<String> days = <String>[
      l.todayWeekdayMonday,
      l.todayWeekdayTuesday,
      l.todayWeekdayWednesday,
      l.todayWeekdayThursday,
      l.todayWeekdayFriday,
      l.todayWeekdaySaturday,
      l.todayWeekdaySunday,
    ];
    final List<String> months = <String>[
      l.todayMonthJanuary,
      l.todayMonthFebruary,
      l.todayMonthMarch,
      l.todayMonthApril,
      l.todayMonthMay,
      l.todayMonthJune,
      l.todayMonthJuly,
      l.todayMonthAugust,
      l.todayMonthSeptember,
      l.todayMonthOctober,
      l.todayMonthNovember,
      l.todayMonthDecember,
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}

class _EmptyRemindersCard extends StatelessWidget {
  const _EmptyRemindersCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.todayAllClear, style: AppText.bodyLarge.wght(800).tint(AppColors.primaryDeep)),
                const SizedBox(height: 4),
                Text(l.todayNoRemindersEnjoy, style: AppText.bodySmall.tint(AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.onAdd});

  final void Function(
    String title,
    String timeStr,
    int minutesFromMidnight,
    ReminderKind kind,
    String detail,
    bool smsEnabled,
  ) onAdd;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  ReminderKind _selectedKind = ReminderKind.medicine;
  bool _smsEnabled = true;

  // Defaults to 8:00 AM
  TimeOfDay _pickedTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  int get _minutesFromMidnight => _pickedTime.hour * 60 + _pickedTime.minute;

  String get _timeDisplay {
    final int h = _pickedTime.hourOfPeriod == 0 ? 12 : _pickedTime.hourOfPeriod;
    final String m = _pickedTime.minute.toString().padLeft(2, '0');
    final String period = _pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
              surface: Colors.white,
              secondary: AppColors.accent,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteColor: AppColors.primaryTint,
              hourMinuteTextColor: AppColors.primaryDeep,
              dayPeriodBorderSide: const BorderSide(color: AppColors.primary),
              dayPeriodColor: AppColors.primaryTint,
              dayPeriodTextColor: AppColors.primaryDeep,
              dialBackgroundColor: AppColors.background,
              dialHandColor: AppColors.primary,
              dialTextColor: AppColors.ink,
              entryModeIconColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.xl)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _pickedTime = picked);
    }
  }

  void _submit() {
    final String title = _nameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).todayReminderNameRequired)),
      );
      return;
    }
    widget.onAdd(
      title,
      _timeDisplay,
      _minutesFromMidnight,
      _selectedKind,
      _detailController.text.trim(),
      _smsEnabled,
    );
    Navigator.of(context).pop();
  }

  String _getCompanionReaction() {
    final AppLocalizations l = AppLocalizations.of(context);
    final int hour = _pickedTime.hour;
    String timeOfDay = l.todayTimeOfDayMorning;
    if (hour >= 18) {
      timeOfDay = l.todayTimeOfDayEvening;
    } else if (hour >= 12) {
      timeOfDay = l.todayTimeOfDayAfternoon;
    }
    return switch (_selectedKind) {
      ReminderKind.medicine => l.todayReactionMedicine(timeOfDay),
      ReminderKind.hydration => l.todayReactionHydration(timeOfDay),
      ReminderKind.cognitive => l.todayReactionCognitive(timeOfDay),
      ReminderKind.appointment => l.todayReactionAppointment(timeOfDay),
      ReminderKind.routine => l.todayReactionRoutine(timeOfDay),
      ReminderKind.social => l.todayReactionSocial(timeOfDay),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool isDayTime = _pickedTime.hour >= 6 && _pickedTime.hour < 18;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: Insets.gutter,
        right: Insets.gutter,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.todayCreateNewReminderTitle, style: AppText.patientTitle.sized(24)),
            const SizedBox(height: 20),

            // ── Reminder Name ──────────────────────────────────────────
            Text(l.todayReminderNameLabel, style: AppText.body.wght(800)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l.todayReminderNameHint,
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Category Chips ─────────────────────────────────────────
            Text(l.todayCategoryLabel, style: AppText.body.wght(800)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: <Widget>[
                _categoryCard(ReminderKind.medicine, l.todayCategoryMedicines, '💊'),
                _categoryCard(ReminderKind.hydration, l.todayCategoryHydration, '💧'),
                _categoryCard(ReminderKind.cognitive, l.todayCategoryDailyActivity, '🧠'),
                _categoryCard(ReminderKind.appointment, l.todayCategoryAppointment, '📅'),
                _categoryCard(ReminderKind.routine, l.todayCategoryDailyRoutine, '🛌'),
                _categoryCard(ReminderKind.social, l.todayCategorySocialActivity, '🤝'),
              ],
            ),
            const SizedBox(height: 24),

            // ── Clock Time Picker ─────────────────────────────────────
            Text(l.todaySetTimeLabel, style: AppText.body.wght(800)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: Corners.r(Corners.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDayTime
                        ? <Color>[AppColors.accentTint, AppColors.primaryTint]
                        : <Color>[AppColors.plumTint, AppColors.primaryTint],
                  ),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  boxShadow: AppColors.softShadow(y: 4, blur: 14, opacity: 0.05),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: <Widget>[
                    // Clock icon ring
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: AppColors.softShadow(y: 2, blur: 8, opacity: 0.08),
                      ),
                      child: Icon(
                        isDayTime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                        color: isDayTime ? AppColors.accent : AppColors.secondary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _timeDisplay,
                            style: AppText.display
                                .sized(36)
                                .wght(900)
                                .tint(AppColors.primaryDeep),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.todayTapToChangeTime,
                            style: AppText.caption
                                .tint(AppColors.inkSoft)
                                .sized(11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: Corners.r(Corners.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.schedule_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            l.actionEdit,
                            style: AppText.caption.wght(800).tint(Colors.white).sized(12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Quick preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _presetChip('🌅 ${l.todayPreset8am}', const TimeOfDay(hour: 8, minute: 0)),
                _presetChip('☀️ ${l.todayPreset1230pm}', const TimeOfDay(hour: 12, minute: 30)),
                _presetChip('🌆 ${l.todayPreset5pm}', const TimeOfDay(hour: 17, minute: 0)),
                _presetChip('🌙 ${l.todayPreset9pm}', const TimeOfDay(hour: 21, minute: 0)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Companion Speech Bubble ────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryTint.withValues(alpha: 0.6),
                borderRadius: Corners.r(Corners.md),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  const Companion(state: CompanionState.happy, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _getCompanionReaction(),
                      style: AppText.body
                          .wght(700)
                          .tint(AppColors.primaryDeep)
                          .sized(13.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Notes ─────────────────────────────────────────────────
            Text(l.todayNotesLabel, style: AppText.body.wght(800)),
            const SizedBox(height: 8),
            TextField(
              controller: _detailController,
              decoration: InputDecoration(
                hintText: l.todayNotesHint,
                fillColor: Colors.white,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.md),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── SMS Alert Toggle ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: Corners.r(Corners.md),
                border: Border.all(
                  color: _smsEnabled
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.hairline,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _smsEnabled
                          ? AppColors.primaryTint
                          : AppColors.hairline.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sms_rounded,
                      size: 18,
                      color: _smsEnabled ? AppColors.primary : AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.todaySmsAlertLabel,
                          style: AppText.body.wght(800).sized(14),
                        ),
                        Text(
                          l.todaySmsAlertNote,
                          style: AppText.caption
                              .tint(AppColors.inkSoft)
                              .sized(11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _smsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (bool v) => setState(() => _smsEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Action Buttons ─────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: BigButton(
                    label: l.actionCancel,
                    outlined: true,
                    height: 56,
                    color: AppColors.inkMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BigButton(
                    label: l.todaySaveReminderButton,
                    height: 56,
                    color: AppColors.primary,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(ReminderKind kind, String label, String emoji) {
    final bool isSelected = _selectedKind == kind;
    final Color tintColor = switch (kind) {
      ReminderKind.medicine   => AppColors.terracotta,
      ReminderKind.hydration  => AppColors.secondary,
      ReminderKind.cognitive  => AppColors.primary,
      ReminderKind.appointment => AppColors.plum,
      ReminderKind.routine    => AppColors.accent,
      ReminderKind.social     => AppColors.indigo,
    };
    return GestureDetector(
      onTap: () => setState(() => _selectedKind = kind),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? tintColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(
            color: isSelected ? tintColor : AppColors.hairline,
            width: isSelected ? 2.2 : 1.2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: AppText.body
                      .wght(isSelected ? 800 : 600)
                      .sized(13.0)
                      .tint(isSelected ? tintColor : AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, TimeOfDay time) {
    final bool isSelected =
        _pickedTime.hour == time.hour && _pickedTime.minute == time.minute;
    return GestureDetector(
      onTap: () => setState(() => _pickedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : Colors.white,
          borderRadius: Corners.r(Corners.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.35),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppText.caption
              .wght(800)
              .tint(AppColors.primary)
              .sized(11.5),
        ),
      ),
    );
  }
}


