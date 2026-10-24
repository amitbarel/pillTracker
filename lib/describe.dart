import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';
import 'models.dart';

String anchorName(S s, Anchor a) => s['anchor.${a.name}'];
String foodName(S s, FoodRelation f) => s['food.${f.name}'];
String presetName(S s, Preset p) => s['preset.${p.name}'];

/// "after breakfast", "On waking", "Bedtime" …
String whenText(S s, Anchor anchor, FoodRelation food) {
  if (!anchor.isMeal) return anchorName(s, anchor);
  final meal = s['meal.${anchor.name}'];
  return switch (food) {
    FoodRelation.before => s.f('when.before', {'meal': meal}),
    FoodRelation.withFood => s.f('when.withFood', {'meal': meal}),
    FoodRelation.after => s.f('when.after', {'meal': meal}),
    FoodRelation.any => anchorName(s, anchor),
  };
}

/// "Twice a day, after food"
String instructionText(S s, Medicine m) {
  final preset = Preset.matching(m.anchors);
  final when = preset != null
      ? presetName(s, preset)
      : Anchor.values
          .where(m.anchors.contains)
          .map((a) => anchorName(s, a))
          .join(', ');
  final hasMeal = m.anchors.any((a) => a.isMeal);
  if (!hasMeal || m.food == FoodRelation.any) return when;
  final food = foodName(s, m.food);
  return '$when, ${s.isHebrew ? food : food.toLowerCase()}';
}

String clock(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
String clockOfDay(TimeOfDay t) =>
    '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

String dayTitle(S s, DateTime d) =>
    DateFormat.MMMMEEEEd(s.languageCode).format(d);

String shortDate(S s, DateTime d) => DateFormat.MMMd(s.languageCode).format(d);
