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
        TextLine('PARACETAMOL', 60),
        TextLine('500 MG', 30),
        TextLine('20 tablets', 20),
        TextLine('Pain relief', 18),
        TextLine('EXP 03/2027', 8),
      ];
      expect(nameCandidates(lines), ['Paracetamol 500 mg', 'Pain relief']);
    });

    test('duplicates and junk are dropped', () {
      final lines = [
        TextLine('Acamol', 50),
        TextLine('ACAMOL', 40),
        TextLine('12', 45),
        TextLine('Film-coated', 30),
      ];
      expect(nameCandidates(lines), ['Acamol']);
    });

    test('Given unsure or garbled lines, Then they are skipped', () {
      final names = nameCandidates([
        TextLine('lIlI1| IIl', 90), // Hebrew read as Latin
        TextLine('XRTZQ', 80), // no vowels
        TextLine('Nurofen', 70, confidence: 0.3),
        TextLine('Optalgin', 50, confidence: 0.9),
        TextLine('Dipyrone', 30),
      ]);
      expect(names, ['Optalgin', 'Dipyrone']);
    });

    test('Given a Hebrew box, Then the Hebrew name and its strength are found', () {
      final names = nameCandidates([
        TextLine('אופטלגין', 80, confidence: 0.9),
        TextLine('500 מ"ג', 40, confidence: 0.85),
        TextLine('20 טבליות', 30, confidence: 0.9),
        TextLine('ןםפךצ', 60, confidence: 0.4), // English read as Hebrew
      ]);
      expect(names.first, 'אופטלגין 500 מ"ג');
      expect(names, isNot(contains('20 טבליות')));
      expect(names, isNot(contains('ןםפךצ')));
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
    expect(whenText(const S('en'), Anchor.dinner, FoodRelation.before), 'before dinner');
    expect(whenText(const S('en'), Anchor.wake, FoodRelation.before), 'On waking');
  });
}
