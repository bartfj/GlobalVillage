import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

enum CheckInReminderKind { firstCheckIn, keepStreak, restartStreak }

class CheckInReminder {
  const CheckInReminder(this.kind, this.scheduledAt);

  final CheckInReminderKind kind;
  final DateTime scheduledAt;
}

/// Beijing 20:00 is 12:00 UTC. UTC deadlines remain stable when the device
/// travels, and use calendar-day arithmetic across month and year boundaries.
List<CheckInReminder> planCheckInReminders({
  required DateTime now,
  required DateTime? optedInAt,
  required String? latestCheckInDay,
}) {
  if (optedInAt == null) return const [];

  final latest = latestCheckInDay == null
      ? null
      : DateTime.tryParse('${latestCheckInDay}T00:00:00Z');
  if (latest == null ||
      latest.toIso8601String().substring(0, 10) != latestCheckInDay) {
    final beijing = optedInAt.toUtc().add(const Duration(hours: 8));
    var first = DateTime.utc(beijing.year, beijing.month, beijing.day, 12);
    if (!first.isAfter(optedInAt)) first = first.add(const Duration(days: 1));
    return [
      if (first.isAfter(now))
        CheckInReminder(CheckInReminderKind.firstCheckIn, first),
    ];
  }

  final keep = DateTime.utc(latest.year, latest.month, latest.day + 1, 12);
  final restart = keep.add(const Duration(days: 1));
  return [
    if (keep.isAfter(now))
      CheckInReminder(CheckInReminderKind.keepStreak, keep),
    if (restart.isAfter(now))
      CheckInReminder(CheckInReminderKind.restartStreak, restart),
  ];
}

/// Owns only the two check-in notifications on this device.
class CheckInReminders {
  CheckInReminders({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _upcomingId = 24001;
  static const _restartId = 24002;
  static const _ids = [_upcomingId, _restartId];
  static const _payloadPrefix = 'check-in/';
  static const _channelId = 'check_in_reminders';

  final _notifications = FlutterLocalNotificationsPlugin();
  final DateTime Function() _clock;
  Future<void> _pending = Future<void>.value();
  bool _reconciled = false;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Returns whether a check-in notification launched a terminated app.
  Future<bool> initialize(VoidCallback onTap) async {
    if (!isSupported) return false;
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_check_in_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (_isCheckInTap(response)) onTap();
      },
    );
    final launch = await _notifications.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true &&
        _isCheckInTap(launch?.notificationResponse);
  }

  bool _isCheckInTap(NotificationResponse? response) =>
      _ids.contains(response?.id) &&
      (response?.payload?.startsWith(_payloadPrefix) ?? false);

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _android?.requestNotificationsPermission();
    } else {
      await _ios?.requestPermissions(alert: true, sound: true);
    }
    return hasPermission();
  }

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _android;
      if (await android?.areNotificationsEnabled() != true) return false;
      final channels = await android?.getNotificationChannels();
      return channels?.every(
            (channel) =>
                channel.id != _channelId ||
                channel.importance != Importance.none,
          ) ??
          true;
    }
    return (await _ios?.checkPermissions())?.isEnabled ?? false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  Future<void> cancel() => _enqueue(_cancelAll);

  Future<void> _cancelAll() async {
    if (!isSupported) return;
    for (final id in _ids) {
      await _notifications.cancel(id);
    }
  }

  /// Apply the most recent local snapshot without recreating matching alarms.
  /// Serializing pending operations keeps logout and completion from racing.
  Future<void> reconcile({
    required DateTime? optedInAt,
    required String? latestCheckInDay,
    required bool isEnglish,
  }) => _enqueue(() async {
    if (!isSupported) return;
    if (optedInAt == null || !await hasPermission()) {
      await _cancelAll();
      _reconciled = true;
      return;
    }
    final plan = planCheckInReminders(
      now: _clock(),
      optedInAt: optedInAt,
      latestCheckInDay: latestCheckInDay,
    );
    // The Android cache can survive a reboot after the OS has cleared its alarms.
    // Re-arm future reminders on cold launch so expired ones are never replayed.
    final useCache =
        defaultTargetPlatform != TargetPlatform.android || _reconciled;
    final existing = useCache
        ? {
            for (final request
                in await _notifications.pendingNotificationRequests())
              request.id: request.payload,
          }
        : const <int, String?>{};
    final desired = {
      for (final reminder in plan)
        if (reminder.kind == CheckInReminderKind.restartStreak)
          _restartId: reminder
        else
          _upcomingId: reminder,
    };
    for (final id in _ids) {
      final reminder = desired[id];
      if (reminder == null) {
        await _notifications.cancel(id);
        continue;
      }
      final payload =
          '$_payloadPrefix${reminder.kind.name}/'
          '${reminder.scheduledAt.millisecondsSinceEpoch}/${isEnglish ? 'en' : 'zh'}';
      if (existing[id] == payload) continue;
      await _notifications.cancel(id);
      if (reminder.scheduledAt.isAfter(_clock())) {
        await _schedule(id, reminder, isEnglish, payload);
      }
    }
    _reconciled = true;
  });

  Future<void> _schedule(
    int id,
    CheckInReminder reminder,
    bool isEnglish,
    String payload,
  ) {
    final body = switch (reminder.kind) {
      CheckInReminderKind.firstCheckIn =>
        isEnglish
            ? 'Finish a session today to start your streak.'
            : '今天完成一轮学习，就能开始打卡。',
      CheckInReminderKind.keepStreak =>
        isEnglish
            ? 'One more session today will keep your streak going.'
            : '今天还差一轮学习，就能延续打卡。',
      CheckInReminderKind.restartStreak =>
        isEnglish
            ? 'Come back for a session when you have time and start again today.'
            : '有空就回来练一轮，从今天重新开始。',
    };
    return _notifications.zonedSchedule(
      id,
      isEnglish ? 'Learning check-in' : '学习打卡',
      body,
      tz.TZDateTime.from(reminder.scheduledAt, tz.UTC),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          isEnglish ? 'Learning reminders' : '学习提醒',
        ),
        iOS: const DarwinNotificationDetails(presentBadge: false),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
