import 'package:flutter/material.dart';

/// Points in the day a dose can be tied to. The actual clock time comes from
/// the person's routine, which differs between weekdays and weekends.
enum Anchor {
  wake,
  breakfast,
  lunch,
  dinner,
  bedtime;

  bool get isMeal =>
      this == Anchor.breakfast || this == Anchor.lunch || this == Anchor.dinner;
}

enum FoodRelation {
  before(-30),
  withFood(0),
  after(30),
  any(0);

  const FoodRelation(this.offsetMinutes);

  /// Minutes relative to the meal time. Only applies to meal anchors.
  final int offsetMinutes;
}

/// Common instructions from the doctor, mapped to the anchors they mean.
enum Preset {
  once({Anchor.breakfast}),
  twice({Anchor.breakfast, Anchor.dinner}),
  three({Anchor.breakfast, Anchor.lunch, Anchor.dinner}),
  four({Anchor.breakfast, Anchor.lunch, Anchor.dinner, Anchor.bedtime}),
  bedtime({Anchor.bedtime});

  const Preset(this.anchors);
  final Set<Anchor> anchors;

  static Preset? matching(Set<Anchor> anchors) {
    for (final p in Preset.values) {
      if (p.anchors.length == anchors.length &&
          p.anchors.containsAll(anchors)) {
        return p;
      }
    }
    return null;
  }
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
TimeOfDay _fromMinutes(int m) {
  final wrapped = ((m % 1440) + 1440) % 1440;
  return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
}

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
TimeOfDay _parse(String s) {
  final parts = s.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// The times of one kind of day (weekday or weekend).
class DayRoutine {
  const DayRoutine(this.times);

  final Map<Anchor, TimeOfDay> times;

  TimeOfDay operator [](Anchor a) => times[a]!;

  DayRoutine withTime(Anchor a, TimeOfDay t) =>
      DayRoutine({...times, a: t});

  DayRoutine shiftedBy(int minutes) => DayRoutine({
        for (final e in times.entries)
          e.key: _fromMinutes(_minutes(e.value) + minutes),
      });

  Map<String, dynamic> toJson() =>
      {for (final e in times.entries) e.key.name: _fmt(e.value)};

  factory DayRoutine.fromJson(Map<String, dynamic> json, DayRoutine fallback) =>
      DayRoutine({
        for (final a in Anchor.values)
          a: json[a.name] is String ? _parse(json[a.name]) : fallback[a],
      });

  static const weekdayDefault = DayRoutine({
    Anchor.wake: TimeOfDay(hour: 6, minute: 0),
    Anchor.breakfast: TimeOfDay(hour: 6, minute: 30),
    Anchor.lunch: TimeOfDay(hour: 13, minute: 0),
    Anchor.dinner: TimeOfDay(hour: 19, minute: 0),
    Anchor.bedtime: TimeOfDay(hour: 22, minute: 0),
  });
}

class Routine {
  const Routine({
    required this.weekday,
    required this.weekend,
    required this.weekendDays,
  });

  final DayRoutine weekday;
  final DayRoutine weekend;

  /// DateTime.weekday values (1 = Monday … 7 = Sunday).
  final Set<int> weekendDays;

  static final defaults = Routine(
    weekday: DayRoutine.weekdayDefault,
    weekend: DayRoutine.weekdayDefault.shiftedBy(60),
    // Sunday to Thursday is the working week in Israel.
    weekendDays: const {DateTime.friday, DateTime.saturday},
  );

  DayRoutine forDay(DateTime day) =>
      weekendDays.contains(day.weekday) ? weekend : weekday;

  bool isWeekend(DateTime day) => weekendDays.contains(day.weekday);

  Routine copyWith({
    DayRoutine? weekday,
    DayRoutine? weekend,
    Set<int>? weekendDays,
  }) =>
      Routine(
        weekday: weekday ?? this.weekday,
        weekend: weekend ?? this.weekend,
        weekendDays: weekendDays ?? this.weekendDays,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday.toJson(),
        'weekend': weekend.toJson(),
        'weekendDays': weekendDays.toList()..sort(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    final d = Routine.defaults;
    return Routine(
      weekday: DayRoutine.fromJson(
          (json['weekday'] as Map?)?.cast<String, dynamic>() ?? {}, d.weekday),
      weekend: DayRoutine.fromJson(
          (json['weekend'] as Map?)?.cast<String, dynamic>() ?? {}, d.weekend),
      weekendDays: ((json['weekendDays'] as List?) ?? d.weekendDays.toList())
          .cast<int>()
          .toSet(),
    );
  }
}

class Medicine {
  Medicine({
    required this.id,
    required this.name,
    this.photoPath,
    this.dose = '1 pill',
    required this.anchors,
    this.food = FoodRelation.after,
    this.notes = '',
    required this.startDate,
    this.endDate,
  });

  final int id;
  String name;
  String? photoPath;
  String dose;
  Set<Anchor> anchors;
  FoodRelation food;
  String notes;

  /// Date-only values (time is midnight).
  DateTime startDate;
  DateTime? endDate;

  bool isActiveOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(startDate)) return false;
    if (endDate != null && d.isAfter(endDate!)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
        'dose': dose,
        'anchors': Anchor.values
            .where(anchors.contains)
            .map((a) => a.name)
            .toList(),
        'food': food.name,
        'notes': notes,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as int,
        name: json['name'] as String,
        photoPath: json['photoPath'] as String?,
        dose: (json['dose'] as String?) ?? '1 pill',
        anchors: ((json['anchors'] as List?) ?? [])
            .map((n) => Anchor.values.byName(n as String))
            .toSet(),
        food: FoodRelation.values.byName((json['food'] as String?) ?? 'after'),
        notes: (json['notes'] as String?) ?? '',
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
      );
}

enum IntakeStatus { taken, skipped }

class IntakeLog {
  IntakeLog({
    required this.medicineId,
    required this.day,
    required this.anchor,
    required this.status,
    required this.at,
  });

  final int medicineId;

  /// The day the dose belonged to (date only).
  final DateTime day;
  final Anchor anchor;
  final IntakeStatus status;

  /// When it was actually marked.
  final DateTime at;

  String get doseKey => DoseKey(medicineId, day, anchor).toString();

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'day': day.toIso8601String(),
        'anchor': anchor.name,
        'status': status.name,
        'at': at.toIso8601String(),
      };

  factory IntakeLog.fromJson(Map<String, dynamic> json) => IntakeLog(
        medicineId: json['medicineId'] as int,
        day: DateTime.parse(json['day'] as String),
        anchor: Anchor.values.byName(json['anchor'] as String),
        status: IntakeStatus.values.byName(json['status'] as String),
        at: DateTime.parse(json['at'] as String),
      );
}

class DoseKey {
  DoseKey(this.medicineId, DateTime day, this.anchor) : day = dateOnly(day);
  final int medicineId;
  final DateTime day;
  final Anchor anchor;

  static DoseKey? tryParse(String? s) {
    final parts = s?.split('|');
    if (parts == null || parts.length != 3) return null;
    final id = int.tryParse(parts[0]);
    final ymd = parts[1].split('-').map(int.tryParse).toList();
    final anchor = Anchor.values.where((a) => a.name == parts[2]).firstOrNull;
    if (id == null || ymd.length != 3 || ymd.contains(null) || anchor == null) {
      return null;
    }
    return DoseKey(id, DateTime(ymd[0]!, ymd[1]!, ymd[2]!), anchor);
  }

  @override
  String toString() =>
      '$medicineId|${day.year}-${day.month}-${day.day}|${anchor.name}';

  @override
  bool operator ==(Object other) =>
      other is DoseKey && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
