import 'package:flutter_test/flutter_test.dart';
import 'package:pill_tracker/instructions.dart';
import 'package:pill_tracker/models.dart';

void main() {
  test('Given the Tadam-Mac sticker, Then it is once a day in the morning for 90 days', () {
    // What the Hebrew reader returned for Amit's photo, plus the English line.
    const text = '''
TADAM-MAC TAB 5MG (28)
1-60 )מ כמות-84 ה\\ד
לבליעה 1 טבליה * 1 פעם ביום לתקופה של 90
ימים (בוקר 1 טבליה)
רופא: דמיטרי 'חונוביץ
רוקח: תהליל סרסור 13%
מכב' פארם-קרית אונו 6''';
    final i = parseInstructions(text);
    expect(i.dose, '1 טבליה');
    expect(i.perDay, 1);
    expect(i.times, {Anchor.breakfast});
    expect(i.food, isNull);
    expect(i.days, 90);
  });

  test('Given Hebrew twice a day after food for a week, Then all of it is read', () {
    final i = parseInstructions('2 כמוסות פעמיים ביום אחרי האוכל למשך שבוע');
    expect(i.dose, '2 כמוסות');
    expect(i.perDay, 2);
    expect(i.times, {Anchor.breakfast, Anchor.dinner});
    expect(i.food, FoodRelation.after);
    expect(i.days, 7);
  });

  test('Given named times that match the count, Then those times are used', () {
    final i = parseInstructions('1 טבליה 2 פעמים ביום, בבוקר ולפני השינה');
    expect(i.times, {Anchor.breakfast, Anchor.bedtime});
  });

  test('Given English instructions, Then they are read too', () {
    final i = parseInstructions('Take 1 tablet 3 times a day before meals for 10 days');
    expect(i.dose, '1 tablet');
    expect(i.perDay, 3);
    expect(i.food, FoodRelation.before);
    expect(i.days, 10);
    expect(parseInstructions('every 8 hours').perDay, 3);
  });

  test('Given the pack size first, Then it is not taken as the dose', () {
    expect(parseInstructions('כמות: 84 TAB. 1 טבליה פעם ביום').dose, '1 טבליה');
  });

  test('Given text with no instructions, Then nothing is inferred', () {
    expect(parseInstructions('medomie בזאפיבראט').isEmpty, isTrue);
  });
}
