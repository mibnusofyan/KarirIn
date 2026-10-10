import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// `--dart-define=REMINDER_DEMO_MINUTES=2` makes follow-up reminders fire minutes (not 7 days) after a status
/// change, so a demo or test can show the notification arriving.
const _demoMinutes = int.fromEnvironment('REMINDER_DEMO_MINUTES');

/// When a follow-up reminder for a status set at [now] fires: 7 days later at 09.00.
DateTime followUpAt(DateTime now) =>
    _demoMinutes > 0 ? now.add(const Duration(minutes: _demoMinutes)) : DateTime(now.year, now.month, now.day + 7, 9);

/// Payloads of tapped notifications: `job:<id>` (new job) or `tracker` (follow-up reminder). The app routes them.
final notificationTaps = StreamController<String>.broadcast();

/// Follow-up reminders as notifications scheduled on the device (no server needed, works offline), plus showing
/// push messages that arrive while the app is open.
abstract interface class ReminderScheduler {
  /// Creates the notification channels and reports a notification that launched the app. Safe to call repeatedly.
  Future<void> init();

  /// Shows a notification now (used for push messages received in the foreground).
  Future<void> show({required String title, required String body, required String payload});

  /// Asks for the notification permission (Android 13+). Returns whether reminders can be shown.
  Future<bool> requestPermission();

  /// Schedules [application]'s reminder, replacing any earlier one; past reminders are skipped.
  Future<void> schedule(JobApplication application);
  Future<void> cancel(String applicationId);
  Future<void> cancelAll();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> init() async {}

  @override
  Future<void> show({required String title, required String body, required String payload}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(JobApplication application) async {}

  @override
  Future<void> cancel(String applicationId) async {}

  @override
  Future<void> cancelAll() async {}
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Pengingat lamaran',
      channelDescription: 'Pengingat tindak lanjut dan persiapan wawancara dari pelacak lamaran',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _newJobs = NotificationDetails(
    android: AndroidNotificationDetails(
      'new_jobs',
      'Lowongan baru yang cocok',
      channelDescription: 'Lowongan baru dengan Match Score Sangat Cocok untuk profilmu',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) notificationTaps.add(r.payload!);
      },
    );
    // Push messages arriving in the background use this channel (AndroidManifest default_notification_channel_id).
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'new_jobs',
            'Lowongan baru yang cocok',
            description: 'Lowongan baru dengan Match Score Sangat Cocok untuk profilmu',
            importance: Importance.high,
          ),
        );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && payload != null) notificationTaps.add(payload);
  }();

  @override
  Future<void> init() => _init();

  @override
  Future<void> show({required String title, required String body, required String payload}) async {
    await _init();
    await _plugin.show(id: payload.hashCode & 0x7fffffff, title: title, body: body, notificationDetails: _newJobs, payload: payload);
  }

  /// Stable notification id per application.
  static int _id(String applicationId) => applicationId.hashCode & 0x7fffffff;

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> schedule(JobApplication a) async {
    await _init();
    await _plugin.cancel(id: _id(a.id));
    final at = a.reminderAt;
    if (at == null || a.remind == null || !a.status.isActive || at.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _id(a.id),
        // An absolute instant, so the device's time zone does not matter.
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: a.remind,
        body: '${a.title} di ${a.company}. Buka KarirIn untuk memperbarui status lamaran.',
        payload: 'tracker',
      );
    } catch (e) {
      debugPrint('Reminder: $e');
    }
  }

  @override
  Future<void> cancel(String applicationId) async {
    await _init();
    await _plugin.cancel(id: _id(applicationId));
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}
