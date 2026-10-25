import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';
import 'models.dart';

String anchorName(S s, Anchor a) => s['anchor.${a.name}'];
String foodName(S s, FoodRelation f) => s['food.${f.name}'];
String presetName(S s, Preset p) => s['preset.${p.name}'];

/// A sound's name: the phone's own name for it, or ours for the app's tones.
String soundName(S s, AlarmSound? sound) => switch (sound) {
      null => s['sound.notification'],
      AlarmSound(kind: SoundKind.app, :final title) => s['sound.$title'],
      AlarmSound(:final title) => title,
    };

/// "after breakfast", "On waking", "at 9:00" …
String whenText(S s, Slot slot, FoodRelation food) {
  final anchor = slot.anchor;
  if (anchor == null) return s.f('atClock', {'time': clockOfDay(slot.time!)});
  if (!anchor.isMeal) return anchorName(s, anchor);
  final meal = s['meal.${anchor.name}'];
  return switch (food) {
    FoodRelation.before => s.f('when.before', {'meal': meal}),
    FoodRelation.withFood => s.f('when.withFood', {'meal': meal}),
    FoodRelation.after => s.f('when.after', {'meal': meal}),
    FoodRelation.any => anchorName(s, anchor),
  };
}

/// "Twice a day, after food", "Once a day · 9:00"
String instructionText(S s, Medicine m) {
  final preset = m.clockTimes.isEmpty ? Preset.matching(m.anchors) : null;
  final named = [
    for (final a in Anchor.values)
      if (m.anchors.contains(a)) anchorName(s, a),
    for (final t in m.clockTimes) clockOfDay(t),
  ].join(', ');
  final often = Preset.values
      .where((p) => p != Preset.bedtime && p.anchors.length == m.perDay)
      .firstOrNull;
  final when = preset != null
      ? presetName(s, preset)
      : m.anchors.isEmpty && often != null
          ? '${presetName(s, often)} · $named'
          : named;
  final hasMeal = m.anchors.any((a) => a.isMeal);
  final days = m.days == null ? '' : '${weekdaysText(s, m.days!)} · ';
  if (!hasMeal || m.food == FoodRelation.any) return '$days$when';
  final food = foodName(s, m.food);
  return '$days$when, ${s.isHebrew ? food : food.toLowerCase()}';
}

/// The week as the person reads it: Sunday first.
const weekOrder = [
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

/// Short name of a weekday (DateTime.monday..sunday): "Sun", "יום א׳".
String weekdayName(S s, int weekday) =>
    // 7 January 2024 was a Sunday.
    DateFormat.E(s.languageCode).format(DateTime(2024, 1, 7 + weekday % 7));

/// "Every Sunday" for one day, else "Sun, Tue, Thu".
String weekdaysText(S s, Set<int> days) {
  if (days.length == 1) {
    final day = DateFormat.EEEE(s.languageCode).format(DateTime(2024, 1, 7 + days.single % 7));
    return s.f('everyDay', {'day': day});
  }
  return [for (final d in weekOrder) if (days.contains(d)) weekdayName(s, d)].join(', ');
}

String clock(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
String clockOfDay(TimeOfDay t) =>
    '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

String dayTitle(S s, DateTime d) =>
    DateFormat.MMMMEEEEd(s.languageCode).format(d);

String shortDate(S s, DateTime d) => DateFormat.MMMd(s.languageCode).format(d);
