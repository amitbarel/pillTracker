import 'package:flutter/material.dart';

import 'models.dart';

/// One expected dose on a specific day.
class Dose {
  Dose(this.medicine, this.day, this.anchor, this.time);

  final Medicine medicine;
  final DateTime day;
  final Anchor anchor;
  final DateTime time;

  DoseKey get key => DoseKey(medicine.id, day, anchor);
}

/// Clock time of [anchor] for [medicine] on [day], following the routine.
DateTime doseTime(Routine routine, Medicine medicine, DateTime day, Anchor anchor) {
  final TimeOfDay base = routine.forDay(day)[anchor];
  final offset = anchor.isMeal ? medicine.food.offsetMinutes : 0;
  return DateTime(day.year, day.month, day.day, base.hour, base.minute)
      .add(Duration(minutes: offset));
}

/// All doses due on [day], sorted by time.
List<Dose> dosesForDay(Routine routine, List<Medicine> medicines, DateTime day) {
  final d = dateOnly(day);
  final doses = <Dose>[
    for (final m in medicines)
      if (m.isActiveOn(d))
        for (final a in Anchor.values)
          if (m.anchors.contains(a)) Dose(m, d, a, doseTime(routine, m, d, a)),
  ];
  doses.sort((a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : a.medicine.name.compareTo(b.medicine.name);
  });
  return doses;
}

enum DoseState { upcoming, due, taken, skipped, missed }

/// A dose counts as missed once it is this late with nothing recorded.
const missedAfter = Duration(hours: 2);

DoseState doseState(Dose dose, IntakeLog? log, DateTime now) {
  if (log != null) {
    return log.status == IntakeStatus.taken ? DoseState.taken : DoseState.skipped;
  }
  if (now.isBefore(dose.time)) return DoseState.upcoming;
  if (now.isBefore(dose.time.add(missedAfter))) return DoseState.due;
  return DoseState.missed;
}

/// Which day a reminder for [anchor] belongs to when it is answered at [now].
/// A bedtime dose answered just after midnight still belongs to yesterday.
DateTime doseDayFor(Routine routine, Medicine medicine, Anchor anchor, DateTime now) {
  final today = dateOnly(now);
  final todayTime = doseTime(routine, medicine, today, anchor);
  if (now.isBefore(todayTime.subtract(const Duration(hours: 3)))) {
    return today.subtract(const Duration(days: 1));
  }
  return today;
}
