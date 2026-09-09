import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/daily.dart';

/// Manages instant & scheduled pop-up heads-up banner notifications on the phone.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initializes the local notification plugin with high importance settings.
  ///
  /// Returns false when the platform has no notification channel at all — a
  /// widget test, a desktop build, a device that refused the permission. The
  /// caller carries on without the banner rather than failing.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
      );

      await _plugin.initialize(settings);

      // Create high-priority notification channel for pop-up banners with
      // sound & vibration.
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'smaran_saathi_reminders_channel',
        'SmaranSaathi Reminder Popups',
        description:
            'Heads-up pop-up banner alerts for medicine and activity reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.requestNotificationsPermission();

      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('LocalNotificationService: unavailable ($error)');
      return false;
    }
  }

  /// Displays an immediate Heads-Up Pop-Up Banner notification on screen.
  Future<void> showPopUpNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await initialize()) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'smaran_saathi_reminders_channel',
      'SmaranSaathi Reminder Popups',
      channelDescription: 'Heads-up pop-up banner alerts for medicine and activity reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SmaranSaathi Reminder',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // A banner that cannot be shown must never take the caller down with it.
    // The safe-zone alert in particular has already been recorded in state and
    // drawn on screen by the time this runs; losing the notification is a
    // degraded alert, losing the exception handling is a lost one.
    try {
      await _plugin.show(id, title, body, details);
    } catch (error) {
      debugPrint('LocalNotificationService: show failed ($error)');
    }
  }

  /// Schedules a pop-up heads-up banner notification at the reminder time.
  void scheduleReminderNotification(Reminder reminder) {
    unawaited(initialize());

    final DateTime now = DateTime.now();
    final int nowMinutes = now.hour * 60 + now.minute;
    int diffMinutes = reminder.minutesFromMidnight - nowMinutes;

    if (diffMinutes <= 0) {
      // If time has passed today, schedule for same time tomorrow
      diffMinutes += 1440;
    }

    final Duration delay = Duration(minutes: diffMinutes);

    Timer(delay, () {
      final String glyph = reminder.kind.glyph;
      final String companionNote = switch (reminder.kind) {
        ReminderKind.medicine => 'Time for your medicine to stay healthy!',
        ReminderKind.hydration => 'Time for a fresh glass of water!',
        ReminderKind.cognitive => 'Mitra is ready for your daily brain activity!',
        ReminderKind.appointment => 'You have an important appointment scheduled.',
        ReminderKind.routine => 'Time for your daily routine activity.',
        ReminderKind.social => 'Time to connect with family or friends!',
      };

      final String detail = reminder.detail.isNotEmpty ? '\nNote: ${reminder.detail}' : '';

      showPopUpNotification(
        id: reminder.id.hashCode,
        title: '🌸 $glyph ${reminder.title} (${reminder.time})',
        body: 'Namaste! Mitra here.\n$companionNote$detail',
      );
    });
  }
}
