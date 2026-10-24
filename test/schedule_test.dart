import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_tracker/models.dart';
import 'package:pill_tracker/schedule.dart';

void main() {
  final routine = Routine.defaults;
  // Friday 23 and Saturday 24 October 2026.
  final friday = DateTime(2026, 10, 23);
  final saturday = DateTime(2026, 10, 24);

  Medicine med({
    int id = 1,
    Set<Anchor>? anchors,
    FoodRelation food = FoodRelation.after,
    DateTime? start,
    DateTime? end,
  }) =>
      Medicine(
        id: id,
        name: 'Paracetamol',
        anchors: anchors ?? Preset.twice.anchors,
        food: food,
        startDate: start ?? DateTime(2026, 10, 1),
        endDate: end,
      );

  test('weekend times are an hour later by default', () {
    expect(routine.isWeekend(friday), isFalse);
    expect(routine.isWeekend(saturday), isTrue);
    expect(routine.weekday[Anchor.wake], const TimeOfDay(hour: 6, minute: 0));
    expect(routine.weekend[Anchor.wake], const TimeOfDay(hour: 7, minute: 0));
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
    final israel = routine.copyWith(weekendDays: {DateTime.friday, DateTime.saturday});
    expect(israel.isWeekend(friday), isTrue);
    expect(israel.isWeekend(DateTime(2026, 10, 25)), isFalse);
  });

  test('courses only run between their start and end dates', () {
    final m = med(start: friday, end: saturday);
    expect(dosesForDay(routine, [m], DateTime(2026, 10, 22)), isEmpty);
    expect(dosesForDay(routine, [m], friday), hasLength(2));
    expect(dosesForDay(routine, [m], saturday), hasLength(2));
    expect(dosesForDay(routine, [m], DateTime(2026, 10, 25)), isEmpty);
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
      anchor: Anchor.breakfast,
      status: IntakeStatus.taken,
      at: DateTime(2026, 10, 23, 9, 30),
    );
    expect(doseState(dose, log, DateTime(2026, 10, 23, 10)), DoseState.taken);
  });

  test('a bedtime dose answered after midnight belongs to the day before', () {
    final m = med(anchors: {Anchor.bedtime});
    expect(doseDayFor(routine, m, Anchor.bedtime, DateTime(2026, 10, 24, 0, 20)), friday);
    expect(doseDayFor(routine, m, Anchor.bedtime, DateTime(2026, 10, 23, 22, 5)), friday);
  });

  test('dose keys round-trip', () {
    final key = DoseKey(12, DateTime(2026, 1, 5, 13, 40), Anchor.dinner);
    final parsed = DoseKey.tryParse(key.toString());
    expect(parsed, key);
    expect(parsed!.day, DateTime(2026, 1, 5));
    expect(DoseKey.tryParse('nonsense'), isNull);
    expect(DoseKey.tryParse(null), isNull);
  });

  test('medicines and routines survive saving', () {
    final m = med(end: saturday)..photoPath = '/x.jpg';
    final back = Medicine.fromJson(m.toJson());
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
