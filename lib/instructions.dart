import 'models.dart';

/// What a pharmacy sticker says about taking a medicine. Anything the sticker
/// doesn't mention is null.
class Instructions {
  const Instructions({this.dose, this.perDay, this.anchors, this.food, this.days});

  /// As printed, for example "1 טבליה" or "2 tablets".
  final String? dose;
  final int? perDay;

  /// Only set when the sticker names the times ("morning", "בערב").
  final Set<Anchor>? anchors;
  final FoodRelation? food;

  /// How long the course lasts.
  final int? days;

  bool get isEmpty => dose == null && perDay == null && food == null && days == null;

  /// The times to remind at: the ones the sticker names when they match the
  /// count, otherwise the usual times for that many a day.
  Set<Anchor>? get times {
    final named = anchors;
    if (named != null && (perDay == null || named.length == perDay)) return named;
    final n = perDay;
    if (n == null) return null;
    return switch (n) {
      1 => {Anchor.breakfast},
      2 => {Anchor.breakfast, Anchor.dinner},
      3 => {Anchor.breakfast, Anchor.lunch, Anchor.dinner},
      4 => {Anchor.breakfast, Anchor.lunch, Anchor.dinner, Anchor.bedtime},
      _ => Anchor.values.toSet(),
    };
  }
}

const _units = r'טבליות|טבליה|טבלייה|כמוסות|כמוסה|קפליות|קפליה|כדורים|כדור|טיפות|מ"ל|'
    r'tablets?|tabs?|capsules?|caps?|pills?|drops|ml';
final _quantity = RegExp(r'כמות|quantity|qty', caseSensitive: false);
final _liquid = RegExp(r'טיפות|מ"ל|drops|ml', caseSensitive: false);
final _dose = RegExp('(\\d+(?:[.,]\\d+)?|חצי|half)\\s*($_units)', caseSensitive: false);

final _timesHe = RegExp(r'(\d+)\s*(?:x\s*)?פע(?:ם|מים)\s*(?:ב|ל)?יום');
final _onceHe = RegExp(r'פעם\s*(?:אחת\s*)?(?:ב|ל)יום');
final _twiceHe = RegExp(r'פעמיים\s*(?:ב|ל)יום');
final _everyHoursHe = RegExp(r'כל\s*(\d+)\s*שעות');
final _timesEn = RegExp(r'(\d+)\s*(?:x|times)\s*(?:a|per|each)?\s*day|(\d+)\s*times\s*daily',
    caseSensitive: false);
final _onceEn = RegExp(r'\bonce\s*(?:a|per|each)?\s*(?:day|daily)\b', caseSensitive: false);
final _twiceEn = RegExp(r'\btwice\s*(?:a|per|each)?\s*(?:day|daily)\b', caseSensitive: false);
final _everyHoursEn = RegExp(r'every\s*(\d+)\s*hours?', caseSensitive: false);

final _days = RegExp(
    r'(?:לתקופה\s*של|למשך|במשך|for)\s*(\d+)?\s*'
    r'(ימים|יום|שבועיים|שבועות|שבוע|חודשיים|חודשים|חודש|days?|weeks?|months?|a week|a month)',
    caseSensitive: false);

final _anchorWords = <Anchor, RegExp>{
  Anchor.wake: RegExp(r'השכמה|קימה|on waking', caseSensitive: false),
  Anchor.breakfast: RegExp(r'בוקר|morning|breakfast', caseSensitive: false),
  Anchor.lunch: RegExp(r'צהר(?:י)?ים|noon|lunch', caseSensitive: false),
  Anchor.dinner: RegExp(r'ערב|evening|dinner|supper', caseSensitive: false),
  Anchor.bedtime: RegExp(r'לפני\s*השינה|לילה|bedtime|at night', caseSensitive: false),
};

final _foodBefore = RegExp(
    r'לפני\s*(?:ה)?(?:אוכל|ארוחה|ארוחות)|קיבה\s*ריקה|before\s*(?:food|meals?)|empty stomach',
    caseSensitive: false);
final _foodAfter = RegExp(
    r'(?:אחרי|לאחר)\s*(?:ה)?(?:אוכל|ארוחה|ארוחות)|after\s*(?:food|meals?)',
    caseSensitive: false);
final _foodWith = RegExp(
    r'(?:עם|בזמן|בעת)\s*(?:ה)?(?:אוכל|ארוחה|ארוחות)|with\s*(?:food|meals?)',
    caseSensitive: false);

/// Reads the instructions out of a pharmacy sticker's text, in Hebrew or
/// English. Lines may be split anywhere, so they are read as one run of text.
Instructions parseInstructions(String text) {
  final t = text
      .replaceAll(RegExp('[״”“]'), '"')
      .replaceAll(RegExp('[׳’]'), "'")
      .replaceAll(RegExp(r'\s+'), ' ');

  // Skip the pack size ("כמות: 84 TAB"): a dose is a few pills, not dozens.
  final dose = _dose.allMatches(t).where((m) {
    final before = t.substring((m.start - 10).clamp(0, m.start), m.start);
    if (_quantity.hasMatch(before)) return false;
    final n = double.tryParse(m[1]!.replaceAll(',', '.'));
    return n == null || n <= 10 || _liquid.hasMatch(m[2]!);
  }).firstOrNull?.group(0)?.trim();

  int? perDay;
  if (_twiceHe.hasMatch(t) || _twiceEn.hasMatch(t)) {
    perDay = 2;
  } else if (_timesHe.firstMatch(t) case final m?) {
    perDay = int.parse(m[1]!);
  } else if (_timesEn.firstMatch(t) case final m?) {
    perDay = int.parse(m[1] ?? m[2]!);
  } else if (_onceHe.hasMatch(t) || _onceEn.hasMatch(t)) {
    perDay = 1;
  } else if ((_everyHoursHe.firstMatch(t) ?? _everyHoursEn.firstMatch(t)) case final m?) {
    final hours = int.parse(m[1]!);
    if (hours > 0) perDay = (24 / hours).round();
  }
  if (perDay != null && (perDay < 1 || perDay > Anchor.values.length)) perDay = null;

  final named = {
    for (final MapEntry(key: a, value: re) in _anchorWords.entries)
      if (re.hasMatch(t)) a,
  };

  final food = _foodBefore.hasMatch(t)
      ? FoodRelation.before
      : _foodWith.hasMatch(t)
          ? FoodRelation.withFood
          : _foodAfter.hasMatch(t)
              ? FoodRelation.after
              : null;

  int? days;
  if (_days.firstMatch(t) case final m?) {
    final unit = m[2]!.toLowerCase();
    // "שבועיים" is two weeks; "למשך שבוע" is one.
    final n = m[1] != null ? int.parse(m[1]!) : (unit.endsWith('יים') ? 2 : 1);
    days = unit.contains('שבוע') || unit.contains('week')
        ? n * 7
        : unit.contains('חודש') || unit.contains('month')
            ? n * 30
            : n;
  }

  return Instructions(
    dose: dose,
    perDay: perDay,
    anchors: named.isEmpty ? null : named,
    food: food,
    days: days,
  );
}
