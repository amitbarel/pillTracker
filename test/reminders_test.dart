import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_tracker/models.dart';
import 'package:pill_tracker/notifications.dart';
import 'package:pill_tracker/store.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var pending = <Map<String, Object?>>[];

  setUpAll(() {
    tzdata.initializeTimeZones();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
      calls.add(call);
      return switch (call.method) {
        'pendingNotificationRequests' => pending,
        'getActiveNotifications' => <Object>[],
        _ => true,
      };
    });
  });

  setUp(() {
    calls.clear();
    pending = [];
  });

  Iterable<Map> scheduled() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => c.arguments as Map);
  bool isDose(Map a) => (a['payload'] as String?)?.isNotEmpty ?? false;

  Future<AppState> withMedicine(Set<Anchor> anchors, {DateTime? end}) async {
    final state = AppState.memory();
    await state.saveMedicine(Medicine(
      id: 7,
      name: 'Paracetamol',
      anchors: anchors,
      startDate: DateTime(2020),
      endDate: end,
    ));
    return state;
  }

  group('Reminders.reschedule', () {
    test('Given a once-a-day medicine, When rescheduled, Then 13-14 doses and one nudge are scheduled', () async {
      final state = await withMedicine({Anchor.breakfast});

      await Reminders(state).reschedule();

      final doses = scheduled().where(isDose);
      // Today's dose may already have passed.
      expect(doses.length, inInclusiveRange(Reminders.daysAhead - 1, Reminders.daysAhead));
      expect(doses.every((a) => (a['title'] as String) == 'Paracetamol'), isTrue);
      expect(scheduled().where((a) => !isDose(a)), hasLength(1));
    });

    test('Given a dose already taken, When rescheduled, Then that dose does not ring', () async {
      final state = await withMedicine({Anchor.bedtime});
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final key = DoseKey(7, tomorrow, Anchor.bedtime);
      await state.record(key, IntakeStatus.taken);
      calls.clear();

      await Reminders(state).reschedule();

      expect(scheduled().map((a) => a['payload']), isNot(contains(key.toString())));
    });

    test('Given a course ending tomorrow, When rescheduled, Then nothing rings after it', () async {
      final now = DateTime.now();
      final end = DateTime(now.year, now.month, now.day + 1);
      final state = await withMedicine({Anchor.breakfast, Anchor.dinner}, end: end);

      await Reminders(state).reschedule();

      final doses = scheduled().where(isDose);
      expect(doses.length, lessThanOrEqualTo(4));
    });

    test('Given old reminders and a snooze, When rescheduled, Then old ones are cancelled and the snooze kept', () async {
      final state = AppState.memory();
      pending = [
        {'id': 70011, 'title': 'old'},
        {'id': 2000000071, 'title': 'snoozed'},
      ];

      await Reminders(state).reschedule();

      final cancelled = calls.where((c) => c.method == 'cancel').map((c) => (c.arguments as Map)['id']);
      expect(cancelled, [70011]);
    });
  });
}
