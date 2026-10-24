import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'describe.dart';
import 'l10n.dart';
import 'models.dart';
import 'schedule.dart';
import 'store.dart';

/// What the person pressed on a reminder.
class ReminderAction {
  ReminderAction(this.dose, this.action);

  final DoseKey dose;

  /// One of [Reminders.taken], [Reminders.snooze], [Reminders.skip], or null
  /// when the reminder itself was tapped (or shown full screen).
  final String? action;
}

/// Schedules and answers the alarm-style reminders.
///
/// Reminders are scheduled one by one for the next [daysAhead] days instead
/// of as repeating alarms, so weekday and weekend times, course end dates and
/// doses already taken early are all respected. They are rescheduled whenever
/// anything changes, and every time the app opens or a reminder is answered.
class Reminders {
  Reminders(this.state);

  final AppState state;
  final _plugin = FlutterLocalNotificationsPlugin();

  static const taken = 'taken';
  static const snooze = 'snooze';
  static const skip = 'skip';

  static const daysAhead = 14;
  static const snoozeMinutes = 10;

  /// Ids at or above this are snoozes and the test alarm, which a reschedule
  /// leaves alone.
  static const _keepFrom = 2000000000;
  static const _keepAliveId = 1999999999;
  static const _testId = 2147480000;

  static const _channelId = 'medicine_alarms_v1';

  final _actions = ValueNotifier<ReminderAction?>(null);

  /// The latest reminder the person interacted with.
  ValueListenable<ReminderAction?> get actions => _actions;

  void clearAction() => _actions.value = null;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Could not read the time zone, using UTC: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      _onResponse(response);
    }

    state.onScheduleChanged = reschedule;
  }

  void _onResponse(NotificationResponse r) {
    final key = DoseKey.tryParse(r.payload);
    if (key == null) return;
    final action = r.actionId;
    _actions.value = ReminderAction(
        key, action == null || action.isEmpty ? null : action);
  }

  /// Asks for everything reminders need. Safe to call repeatedly.
  Future<void> requestPermissions() async {
    final android = _android;
    if (android != null) {
      await android.requestNotificationsPermission();
      if (await android.canScheduleExactNotifications() != true) {
        await android.requestExactAlarmsPermission();
      }
      await android.requestFullScreenIntentPermission();
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, sound: true, badge: true);
  }

  Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? true;

  Future<bool> exactAlarmsAllowed() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  S get _s {
    final code = state.languageCode ?? Platform.localeName.split(RegExp('[_-]')).first;
    return S.forCode(code == 'iw' ? 'he' : code);
  }

  NotificationDetails _details(S s, {String? photoPath}) {
    final photo = photoPath != null && File(photoPath).existsSync()
        ? FilePathAndroidBitmap(photoPath)
        : null;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        s['channelName'],
        channelDescription: s['channelDescription'],
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        autoCancel: false,
        // FLAG_INSISTENT: keep ringing until answered.
        additionalFlags: Int32List.fromList([4]),
        timeoutAfter: const Duration(minutes: 30).inMilliseconds,
        largeIcon: photo,
        styleInformation: photo == null
            ? null
            : BigPictureStyleInformation(photo, hideExpandedLargeIcon: true),
        actions: [
          AndroidNotificationAction(taken, s['tookIt'], showsUserInterface: true),
          AndroidNotificationAction(snooze, s['snooze'], showsUserInterface: true),
          AndroidNotificationAction(skip, s['skip'], showsUserInterface: true),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  bool _busy = false;
  bool _again = false;

  /// Cancels and re-creates every upcoming reminder.
  Future<void> reschedule() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _reschedule();
      } while (_again);
    } catch (e, st) {
      debugPrint('Rescheduling failed: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  Future<void> _reschedule() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id < _keepFrom) await _plugin.cancel(id: p.id);
    }

    final s = _s;
    final now = DateTime.now();
    final today = dateOnly(now);
    for (var offset = 0; offset < daysAhead; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      for (final dose in dosesForDay(state.routine, state.medicines, day)) {
        if (!dose.time.isAfter(now)) continue;
        if (state.logFor(dose.key) != null) continue;
        await _schedule(
          id: dose.medicine.id * 10000 + offset * 10 + dose.medicine.slotIndex(dose.slot),
          when: dose.time,
          dose: dose.key,
          medicine: dose.medicine,
          s: s,
        );
      }
    }

    if (state.medicines.isNotEmpty) {
      // If the app is never opened, reminders would run out. Nudge first.
      final nudge = DateTime(today.year, today.month, today.day + daysAhead - 1, 12);
      await _plugin.zonedSchedule(
        id: _keepAliveId,
        scheduledDate: tz.TZDateTime.from(nudge, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channelId, s['channelName']),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: s['keepAliveTitle'],
        body: s['keepAliveBody'],
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required DoseKey dose,
    required Medicine medicine,
    required S s,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details(s, photoPath: medicine.photoPath),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      title: medicine.name,
      body: s.f('notificationBody', {
        'dose': medicine.dose,
        'when': whenText(s, dose.slot, medicine.food),
      }),
      payload: dose.toString(),
    );
  }

  Future<void> snoozeDose(DoseKey dose) async {
    final m = state.medicine(dose.medicineId);
    if (m == null) return;
    await _schedule(
      id: _keepFrom + m.id * 10 + m.slotIndex(dose.slot),
      when: DateTime.now().add(const Duration(minutes: snoozeMinutes)),
      dose: dose,
      medicine: m,
      s: _s,
    );
  }

  /// Removes a reminder that is showing, and any snooze for it.
  Future<void> dismiss(DoseKey dose) async {
    final index = state.medicine(dose.medicineId)?.slotIndex(dose.slot) ?? 0;
    await _plugin.cancel(id: _keepFrom + dose.medicineId * 10 + index);
    final active = await _android?.getActiveNotifications() ?? [];
    for (final n in active) {
      if (n.payload == dose.toString() && n.id != null) {
        await _plugin.cancel(id: n.id!);
      }
    }
  }

  Future<void> testAlarm() async {
    final s = _s;
    await _plugin.zonedSchedule(
      id: _testId,
      scheduledDate:
          tz.TZDateTime.from(DateTime.now().add(const Duration(minutes: 1)), tz.local),
      notificationDetails: _details(s),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      title: s['testAlarmTitle'],
      body: s['testAlarmBody'],
    );
  }
}
