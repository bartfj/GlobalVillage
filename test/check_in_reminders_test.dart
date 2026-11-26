import 'package:english_village/core/services/check_in_reminders.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final optedIn = DateTime.utc(2026, 11, 19, 10);

  test('schedules a streak reminder and one return at 20:00 Beijing time', () {
    final plan = planCheckInReminders(
      now: DateTime.utc(2026, 11, 20, 0),
      optedInAt: optedIn,
      latestCheckInDay: '2026-11-20',
    );

    expect(plan.map((reminder) => reminder.kind), [
      CheckInReminderKind.keepStreak,
      CheckInReminderKind.restartStreak,
    ]);
    expect(plan.map((reminder) => reminder.scheduledAt), [
      DateTime.utc(2026, 11, 21, 12),
      DateTime.utc(2026, 11, 22, 12),
    ]);
  });

  test('drops a past streak reminder and pauses after the return deadline', () {
    List<CheckInReminder> at(DateTime time) => planCheckInReminders(
      now: time,
      optedInAt: optedIn,
      latestCheckInDay: '2026-11-20',
    );

    expect(
      at(DateTime.utc(2026, 11, 21, 12)).single.kind,
      CheckInReminderKind.restartStreak,
    );
    expect(at(DateTime.utc(2026, 11, 22, 12)), isEmpty);
  });

  test('a new completion replaces both of the previous deadlines', () {
    final plan = planCheckInReminders(
      now: DateTime.utc(2026, 11, 22, 11),
      optedInAt: optedIn,
      latestCheckInDay: '2026-11-22',
    );

    expect(plan.map((reminder) => reminder.scheduledAt), [
      DateTime.utc(2026, 11, 23, 12),
      DateTime.utc(2026, 11, 24, 12),
    ]);
  });

  test('a learner without a check-in is only reminded once per opt-in', () {
    final enabledAfterEight = DateTime.utc(2026, 11, 20, 13);
    List<CheckInReminder> at(DateTime time) => planCheckInReminders(
      now: time,
      optedInAt: enabledAfterEight,
      latestCheckInDay: null,
    );

    final reminder = at(DateTime.utc(2026, 11, 21, 0)).single;
    expect(reminder.kind, CheckInReminderKind.firstCheckIn);
    expect(reminder.scheduledAt, DateTime.utc(2026, 11, 21, 12));
    expect(at(DateTime.utc(2026, 11, 22, 0)), isEmpty);
  });

  test('turning notifications off removes both pending reminders', () {
    expect(
      planCheckInReminders(
        now: DateTime.utc(2026, 11, 20, 0),
        optedInAt: null,
        latestCheckInDay: '2026-11-20',
      ),
      isEmpty,
    );
  });

  test('the first reminder uses the Beijing date after UTC 16:00', () {
    final enabled = DateTime.utc(2026, 11, 20, 16, 30);
    final reminder = planCheckInReminders(
      now: enabled,
      optedInAt: enabled,
      latestCheckInDay: null,
    ).single;

    expect(reminder.scheduledAt, DateTime.utc(2026, 11, 21, 12));
  });

  group('Android notification plugin', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger = binding.defaultBinaryMessenger;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'replaces a previous day and clears both alarms when disabled',
      () async {
        final pending = <int, String>{};
        final scheduled = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'areNotificationsEnabled':
              return true;
            case 'getNotificationChannels':
              return <Object>[];
            case 'pendingNotificationRequests':
              return [
                for (final entry in pending.entries)
                  {'id': entry.key, 'payload': entry.value},
              ];
            case 'cancel':
              pending.remove((call.arguments as Map)['id']);
            case 'zonedSchedule':
              final args = call.arguments as Map;
              final id = args['id'] as int;
              final payload = args['payload'] as String;
              pending[id] = payload;
              scheduled.add(payload);
            default:
              fail('Unexpected notification method ${call.method}');
          }
          return null;
        });

        final enabled = DateTime.utc(2099, 10, 20);
        CheckInReminders newService() =>
            CheckInReminders(clock: () => DateTime.utc(2099, 10, 21));
        var service = newService();
        Future<void> reconcile(String day) => service.reconcile(
          optedInAt: enabled,
          latestCheckInDay: day,
          isEnglish: false,
        );
        await reconcile('2099-10-20');
        final previous = pending.values.toSet();
        expect(previous, hasLength(2));

        await reconcile('2099-10-20');
        expect(scheduled, hasLength(2));

        service = newService();
        await reconcile('2099-10-20');
        expect(scheduled, hasLength(4));

        await reconcile('2099-10-21');
        expect(pending, hasLength(2));
        expect(pending.values.toSet().intersection(previous), isEmpty);

        await service.cancel();
        expect(pending, isEmpty);
      },
    );

    test('recognizes a cold start from a check-in notification', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {
            'notificationLaunchedApp': true,
            'notificationResponse': {
              'notificationResponseType': 0,
              'notificationId': 24001,
              'payload': 'check-in/keepStreak/stamp/zh',
            },
          };
        }
        fail('Unexpected notification method ${call.method}');
      });

      final service = CheckInReminders();
      expect(
        await service.initialize(() => fail('Expected a cold tap')),
        isTrue,
      );
    });
  });
}
