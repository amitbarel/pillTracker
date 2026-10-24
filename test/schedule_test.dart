import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_tracker/models.dart';
import 'package:pill_tracker/schedule.dart';

void main() {
  // Most tests use a Saturday and Sunday weekend, so Friday has weekday times.
  final routine = Routine.defaults
      .copyWith(weekendDays: {DateTime.saturday, DateTime.sunday});
  // Friday 23 and Saturday 24 October 2026.
  final friday = DateTime(2026, 10, 23);
  final saturday = DateTime(2026, 10, 24);

  Medicine med({
    int id = 1,
    Set<Anchor>? anchors,
    FoodRelation food = FoodRelation.after,
    DateTime? start,
    DateTime? end,
    Set<int>? days,
    DateTime? addedAt,
  }) =>
      Medicine(
        id: id,
        name: 'Fictivol',
        anchors: anchors ?? Preset.twice.anchors,
        food: food,
        startDate: start ?? DateTime(2026, 10, 1),
        endDate: end,
        days: days,
        addedAt: addedAt,
      );

  test('Given the defaults, Then the weekend is Friday and Saturday, an hour later', () {
    final d = Routine.defaults;
    expect(d.isWeekend(DateTime(2026, 10, 22)), isFalse); // Thursday
    expect(d.isWeekend(friday), isTrue);
    expect(d.isWeekend(saturday), isTrue);
    expect(d.isWeekend(DateTime(2026, 10, 25)), isFalse); // Sunday
    expect(d.weekday[Anchor.wake], const TimeOfDay(hour: 6, minute: 0));
    expect(d.weekend[Anchor.wake], const TimeOfDay(hour: 7, minute: 0));
  });

  test('twice a day after food rings 30 minutes after breakfast and dinner', () {
    final weekday = dosesForDay(routine, [med()], friday).map((d) => d.time);
    expect(weekday, [DateTime(2026, 10, 23, 7, 0), DateTime(2026, 10, 23, 19, 30)]);

    final weekend = dosesForDay(routine, [med()], saturday).map((d) => d.time);
    expect(weekend, [DateTime(2026, 10, 24, 8, 0), DateTime(2026, 10, 24, 20, 30)]);
  });

  test('before food is 30 minutes early, waking and bedtime ignore food', () {
    final m = med(anchors: {Anchor.wake, Anchor.lunch, Anchor.bedtime}, food: FoodRelation.before);
    final times = dosesForDay(routine, [m], friday).map((d) => d.time);
    expect(times, [
      DateTime(2026, 10, 23, 6, 0),
      DateTime(2026, 10, 23, 12, 30),
      DateTime(2026, 10, 23, 22, 0),
    ]);
  });

  test('custom weekend days', () {
    expect(routine.isWeekend(friday), isFalse);
    expect(routine.isWeekend(DateTime(2026, 10, 25)), isTrue);
  });

  test('courses only run between their start and end dates', () {
    final m = med(start: friday, end: saturday);
    expect(dosesForDay(routine, [m], DateTime(2026, 10, 22)), isEmpty);
    expect(dosesForDay(routine, [m], friday), hasLength(2));
    expect(dosesForDay(routine, [m], saturday), hasLength(2));
    expect(dosesForDay(routine, [m], DateTime(2026, 10, 25)), isEmpty);
  });

  test('a medicine for some days of the week only has doses on those days', () {
    final m = med(days: {DateTime.friday, DateTime.monday});
    expect(dosesForDay(routine, [m], friday), hasLength(2));
    expect(dosesForDay(routine, [m], saturday), isEmpty);
    expect(dosesForDay(routine, [m], DateTime(2026, 10, 26)), hasLength(2)); // Monday
    expect(dosesForDay(routine, [med()], saturday), hasLength(2));
  });

  test('a medicine added in the afternoon has no missed morning dose that day', () {
    final m = med(start: friday, addedAt: DateTime(2026, 10, 23, 14));
    final today = dosesForDay(routine, [m], friday);
    expect(today.map((d) => d.slot), [const Slot.anchor(Anchor.dinner)]);
    expect(dosesForDay(routine, [m], saturday), hasLength(2));
  });

  test('a set time rings at exactly that time, weekdays and weekends, whatever the food', () {
    final m = Medicine(
      id: 3,
      name: 'Testamol',
      anchors: {Anchor.dinner},
      clockTimes: const [TimeOfDay(hour: 9, minute: 0)],
      startDate: DateTime(2026, 10, 1),
    );
    for (final day in [friday, saturday]) {
      final doses = dosesForDay(routine, [m], day);
      expect(doses.first.time, DateTime(day.year, day.month, day.day, 9));
      expect(doses.first.slot, const Slot.clock(TimeOfDay(hour: 9, minute: 0)));
    }
    expect(m.perDay, 2);
    expect(m.slotIndex(const Slot.clock(TimeOfDay(hour: 9, minute: 0))), Anchor.values.length);
  });

  test('set times are kept earliest first without repeats', () {
    final m = med()
      ..clockTimes = sortedTimes(const [
        TimeOfDay(hour: 21, minute: 0),
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 21, minute: 0),
      ]);
    expect(m.clockTimes, const [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 21, minute: 0)]);
  });

  test('doses of several medicines are sorted by time', () {
    final a = med(id: 1, anchors: {Anchor.dinner});
    final b = med(id: 2, anchors: {Anchor.wake});
    final doses = dosesForDay(routine, [a, b], friday);
    expect(doses.map((d) => d.medicine.id), [2, 1]);
  });

  test('state: upcoming, due, missed, and answered', () {
    final dose = dosesForDay(routine, [med()], friday).first; // 7:00
    expect(doseState(dose, null, DateTime(2026, 10, 23, 6, 59)), DoseState.upcoming);
    expect(doseState(dose, null, DateTime(2026, 10, 23, 7, 30)), DoseState.due);
    expect(doseState(dose, null, DateTime(2026, 10, 23, 9, 1)), DoseState.missed);
    final log = IntakeLog(
      medicineId: 1,
      day: friday,
      slot: const Slot.anchor(Anchor.breakfast),
      status: IntakeStatus.taken,
      at: DateTime(2026, 10, 23, 9, 30),
    );
    expect(doseState(dose, log, DateTime(2026, 10, 23, 10)), DoseState.taken);
  });

  test('a bedtime dose answered after midnight belongs to the day before', () {
    final m = med(anchors: {Anchor.bedtime});
    expect(doseDayFor(routine, m, const Slot.anchor(Anchor.bedtime), DateTime(2026, 10, 24, 0, 20)), friday);
    expect(doseDayFor(routine, m, const Slot.anchor(Anchor.bedtime), DateTime(2026, 10, 23, 22, 5)), friday);
  });

  test('dose keys round-trip', () {
    final key = DoseKey(12, DateTime(2026, 1, 5, 13, 40), const Slot.anchor(Anchor.dinner));
    final parsed = DoseKey.tryParse(key.toString());
    expect(parsed, key);
    expect(parsed!.day, DateTime(2026, 1, 5));
    expect(DoseKey.tryParse('nonsense'), isNull);
    final clock = DoseKey(12, DateTime(2026, 1, 5), const Slot.clock(TimeOfDay(hour: 9, minute: 5)));
    expect(clock.toString(), '12|2026-1-5|at09:05');
    expect(DoseKey.tryParse(clock.toString()), clock);
    expect(DoseKey.tryParse('12|2026-1-5|at25:00'), isNull);
    expect(DoseKey.tryParse(null), isNull);
  });

  test('medicines and routines survive saving', () {
    final m = med(end: saturday, days: {5, 1}, addedAt: DateTime(2026, 10, 1, 9))
      ..photoPath = '/x.jpg';
    final back = Medicine.fromJson(m.toJson());
    expect(back.days, {1, 5});
    expect(back.addedAt, DateTime(2026, 10, 1, 9));
    expect(Medicine.fromJson(med().toJson()).days, isNull);
    final timed = med()..clockTimes = const [TimeOfDay(hour: 9, minute: 30)];
    expect(Medicine.fromJson(timed.toJson()).clockTimes, const [TimeOfDay(hour: 9, minute: 30)]);

    // History saved before set times existed still reads.
    final old = IntakeLog.fromJson({
      'medicineId': 1,
      'day': friday.toIso8601String(),
      'anchor': 'breakfast',
      'status': 'taken',
      'at': friday.toIso8601String(),
    });
    expect(old.slot, const Slot.anchor(Anchor.breakfast));
    expect(back.anchors, m.anchors);
    expect(back.endDate, saturday);
    expect(back.photoPath, '/x.jpg');

    final r = routine.copyWith(
      weekday: routine.weekday.withTime(Anchor.lunch, const TimeOfDay(hour: 12, minute: 15)),
      weekendDays: {5, 6},
    );
    final rb = Routine.fromJson(r.toJson());
    expect(rb.weekday[Anchor.lunch], const TimeOfDay(hour: 12, minute: 15));
    expect(rb.weekendDays, {5, 6});
    expect(rb.weekend[Anchor.wake], const TimeOfDay(hour: 7, minute: 0));
  });

  test('presets are recognised from the chosen times', () {
    expect(Preset.matching({Anchor.breakfast, Anchor.dinner}), Preset.twice);
    expect(Preset.matching({Anchor.wake}), isNull);
  });
}
