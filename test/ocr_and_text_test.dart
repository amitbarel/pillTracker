import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_tracker/describe.dart';
import 'package:pill_tracker/l10n.dart';
import 'package:pill_tracker/models.dart';
import 'package:pill_tracker/ocr.dart';

void main() {
  group('name candidates', () {
    test('the biggest print wins and a strength below it is joined', () {
      final lines = [
        TextLine('Rx only', 10),
        TextLine('FICTIVOL', 60),
        TextLine('500 MG', 30),
        TextLine('20 tablets', 20),
        TextLine('Pain relief', 18),
        TextLine('EXP 03/2027', 8),
      ];
      expect(nameCandidates(lines), ['Fictivol 500 mg', 'Pain relief']);
    });

    test('duplicates and junk are dropped', () {
      final lines = [
        TextLine('Testamol', 50),
        TextLine('TESTAMOL', 40),
        TextLine('12', 45),
        TextLine('Film-coated', 30),
      ];
      expect(nameCandidates(lines), ['Testamol']);
    });

    test('Given unsure or garbled lines, Then they are skipped', () {
      final names = nameCandidates([
        TextLine('lIlI1| IIl', 90), // Hebrew read as Latin
        TextLine('XRTZQ', 80), // no vowels
        TextLine('Dummofen', 70, confidence: 0.3),
        TextLine('Mockalgin', 50, confidence: 0.9),
        TextLine('Placebone', 30),
      ]);
      expect(names, ['Mockalgin', 'Placebone']);
    });

    test('Given a Hebrew box, Then the Hebrew name and its strength are found', () {
      final names = nameCandidates([
        TextLine('מוקלגין', 80, confidence: 0.9),
        TextLine('500 מ"ג', 40, confidence: 0.85),
        TextLine('20 טבליות', 30, confidence: 0.9),
        TextLine('ןםפךצ', 60, confidence: 0.4), // English read as Hebrew
      ]);
      expect(names.first, 'מוקלגין 500 מ"ג');
      expect(names, isNot(contains('20 טבליות')));
      expect(names, isNot(contains('ןםפךצ')));
    });

    test('Given a Hebrew box read with noise, Then its name comes first', () {
      // A made-up box, misread the way the Hebrew reader misreads real ones.
      final names = nameCandidates([
        TextLine('| דוגמזול פארמקו', 80, confidence: 0.84),
        TextLine('\\במת |ב> 9', 71, confidence: 0.29),
        TextLine('דוגמזול 0', 91, confidence: 0.57),
        TextLine('טבליות בשחרור מושהה', 42, confidence: 0.92),
        TextLine('בעל הרישום: פארמקו בע"מ [', 27, confidence: 0.88),
        TextLine('ת.ד. 1, עיר לדוגמה, 1234567', 61, confidence: 0.55),
        TextLine('השש |', 85, confidence: 0.35),
        TextLine('pharmaco', 50, confidence: 0.95),
      ]);
      expect(names.first, 'דוגמזול פארמקו');
    });

    test('nothing readable gives no candidates', () {
      expect(nameCandidates([TextLine('---', 50)]), isEmpty);
    });
  });

  test('every English text has a Hebrew translation and the reverse', () {
    expect(S.he.keys.toSet(), S.en.keys.toSet());
  });

  test('placeholders survive translation', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in S.en.keys) {
      final en = placeholder.allMatches(S.en[key]!).map((m) => m[1]).toSet();
      final he = placeholder.allMatches(S.he[key]!).map((m) => m[1]).toSet();
      expect(he, en, reason: key);
    }
  });

  test('instructions read naturally', () {
    final m = Medicine(
      id: 1,
      name: 'x',
      anchors: Preset.twice.anchors,
      food: FoodRelation.after,
      startDate: DateTime(2026),
    );
    expect(instructionText(const S('en'), m), 'Twice a day, after food');
    expect(instructionText(const S('he'), m), 'פעמיים ביום, אחרי האוכל');
    expect(whenText(const S('en'), const Slot.anchor(Anchor.dinner), FoodRelation.before), 'before dinner');
    expect(whenText(const S('en'), const Slot.anchor(Anchor.wake), FoodRelation.before), 'On waking');
    const nine = Slot.clock(TimeOfDay(hour: 9, minute: 0));
    expect(whenText(const S('en'), nine, FoodRelation.after), 'at 9:00');
    expect(whenText(const S('he'), nine, FoodRelation.after), 'בשעה 9:00');
    final timed = Medicine(
      id: 2,
      name: 'x',
      anchors: {},
      clockTimes: const [TimeOfDay(hour: 9, minute: 0)],
      startDate: DateTime(2026),
    );
    expect(instructionText(const S('en'), timed), 'Once a day · 9:00');
  });
}
