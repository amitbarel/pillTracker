import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:pill_tracker/l10n.dart';
import 'package:pill_tracker/main.dart';
import 'package:pill_tracker/models.dart';
import 'package:pill_tracker/notifications.dart';
import 'package:pill_tracker/schedule.dart';
import 'package:pill_tracker/scope.dart';
import 'package:pill_tracker/screens/dose_screen.dart';
import 'package:pill_tracker/screens/edit_medicine_screen.dart';
import 'package:pill_tracker/screens/today_screen.dart';
import 'package:pill_tracker/store.dart';

/// Renders every screen in English and Hebrew on a small phone, so layout
/// overflows and missing texts show up as failures.
void main() {
  /// Calls the app made to the notifications plugin, newest last.
  final calls = <MethodCall>[];

  setUpAll(() async {
    await initializeDateFormatting();
    tzdata.initializeTimeZones();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
      calls.add(call);
      return switch (call.method) {
        'getActiveNotifications' || 'pendingNotificationRequests' => <Object>[],
        _ => true,
      };
    });
  });

  setUp(calls.clear);

  Future<AppState> sampleState() async {
    final state = AppState.memory();
    final today = dateOnly(DateTime.now());
    await state.saveMedicine(Medicine(
      id: state.newMedicineId(),
      name: 'Fictivol 500 mg',
      dose: '2 pills',
      anchors: Preset.three.anchors,
      startDate: today.subtract(const Duration(days: 5)),
      endDate: today.add(const Duration(days: 5)),
    ));
    await state.saveMedicine(Medicine(
      id: state.newMedicineId(),
      name: 'Examplor 10 mg',
      anchors: {Anchor.wake},
      startDate: today.subtract(const Duration(days: 5)),
      notes: 'Blood thinner after the knee surgery',
    ));
    final first = dosesForDay(state.routine, state.medicines,
        today.subtract(const Duration(days: 1)));
    await state.record(first.first.key, IntakeStatus.taken);
    return state;
  }

  /// A phone-shaped screen, so the form's chips aren't hidden under Save.
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget app(AppState state, String lang, Widget home) => Scope(
        state: state,
        reminders: Reminders(state),
        child: MaterialApp(
          theme: buildTheme(),
          locale: Locale(lang),
          supportedLocales: S.supported,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      );

  for (final lang in ['en', 'he']) {
    testWidgets('Given two medicines, When every tab is opened in $lang, Then nothing overflows', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = await sampleState();
      await tester.pumpWidget(app(state, lang, const HomeScreen()));
      await tester.pumpAndSettle();
      // The list builds lazily, so scroll it all the way to lay out every dose.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('Fictivol 500 mg'), findsWidgets);
      for (final icon in [
        Icons.medication_outlined,
        Icons.calendar_month_outlined,
        Icons.wb_sunny_outlined,
      ]) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Given two medicines, When add, edit and alarm screens open in $lang, Then nothing overflows', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = await sampleState();
      await tester.pumpWidget(app(state, lang, const EditMedicineScreen()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
          app(state, lang, EditMedicineScreen(medicine: state.medicines.first)));
      await tester.pumpAndSettle();
      final dose = dosesForDay(state.routine, state.medicines, DateTime.now()).first;
      await tester.pumpWidget(app(state, lang, DoseScreen(dose: dose.key)));
      await tester.pumpAndSettle();
      expect(find.text(S(lang)['tookIt']), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given no name, When Save is tapped, Then it asks for one and saves nothing', (tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(state.medicines, isEmpty);
  });

  testWidgets('Given a name, When Save is tapped, Then a twice-a-day medicine is saved', (tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('nameField')), 'Testamol');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    final m = state.medicines.single;
    expect(m.name, 'Testamol');
    expect(m.anchors, Preset.twice.anchors);
    expect(m.food, FoodRelation.after);
    expect(m.dose, '1 pill');
  });

  testWidgets('Given no times chosen, When Save is tapped, Then it asks for a time', (tester) async {
    phoneSize(tester);
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Testamol');

    // Twice a day starts selected: untick both of its times.
    for (final a in [Anchor.breakfast, Anchor.dinner]) {
      final chip = find.byKey(Key('anchor.${a.name}'));
      await tester.dragUntilVisible(chip, find.byType(ListView), const Offset(0, -150));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
      await tester.tap(chip);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('Pick 2 times'), findsOneWidget);
    expect(state.medicines, isEmpty);
  });

  testWidgets('Given once a day, When another time is tapped, Then it replaces the first', (tester) async {
    phoneSize(tester);
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Testamol');
    await tester.tap(find.text('Once a day'));
    await tester.pumpAndSettle();

    final dinner = find.byKey(const Key('anchor.dinner'));
    await tester.dragUntilVisible(dinner, find.byType(ListView), const Offset(0, -150));
    await tester.ensureVisible(dinner);
    await tester.pumpAndSettle();
    await tester.tap(dinner);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(state.medicines.single.anchors, {Anchor.dinner});
  });

  testWidgets('Given twice a day with two times chosen, Then a third cannot be added', (tester) async {
    phoneSize(tester);
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();

    final lunch = find.byKey(const Key('anchor.lunch'));
    await tester.dragUntilVisible(lunch, find.byType(ListView), const Offset(0, -150));
    await tester.ensureVisible(lunch);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(lunch).onSelected, isNull);

    // Untick dinner, and lunch can be picked instead.
    await tester.tap(find.byKey(const Key('anchor.dinner')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(lunch).onSelected, isNotNull);
  });

  testWidgets('Given once a day, When a time of my own is set on the clock, Then it replaces the routine time', (tester) async {
    phoneSize(tester);
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Testamol');
    await tester.tap(find.text('Once a day'));
    await tester.pumpAndSettle();

    final other = find.byKey(const Key('otherTime'));
    await tester.dragUntilVisible(other, find.byType(ListView), const Offset(0, -150));
    await tester.ensureVisible(other);
    await tester.pumpAndSettle();
    await tester.tap(other);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // The clock opens at 9:00.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clock.9:00')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    final m = state.medicines.single;
    expect(m.anchors, isEmpty);
    expect(m.clockTimes, const [TimeOfDay(hour: 9, minute: 0)]);
  });

  testWidgets('Given twice a day with two times chosen, Then another time of my own cannot be added', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(app(AppState.memory(), 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    final other = find.byKey(const Key('otherTime'));
    await tester.dragUntilVisible(other, find.byType(ListView), const Offset(0, -150));
    expect(tester.widget<ActionChip>(other).onPressed, isNull);
  });

  testWidgets('Given some days, When Monday and Thursday are picked, Then only those days are saved', (tester) async {
    phoneSize(tester);
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Testamol');

    Future<void> tap(Finder f) async {
      await tester.dragUntilVisible(f, find.byType(ListView), const Offset(0, -150));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tap(find.byKey(const Key('someDays')));
    // Some days starts with today ticked: untick it, keep only Monday and Thursday.
    final today = DateTime.now().weekday;
    if (today != DateTime.monday && today != DateTime.thursday) {
      await tap(find.byKey(Key('day.$today')));
    }
    for (final d in [DateTime.monday, DateTime.thursday]) {
      if (d != today) await tap(find.byKey(Key('day.$d')));
    }
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(state.medicines.single.days, {DateTime.monday, DateTime.thursday});
  });

  group('alarm screen', () {
    Future<(AppState, DoseKey)> open(WidgetTester tester) async {
      final state = await sampleState();
      final dose = dosesForDay(state.routine, state.medicines, DateTime.now()).first.key;
      await tester.pumpWidget(app(state, 'en', Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DoseScreen(dose: dose))),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (state, dose);
    }

    testWidgets('Given a ringing dose, When I took it is tapped, Then it is recorded and the screen closes', (tester) async {
      final (state, dose) = await open(tester);

      await tester.tap(find.byKey(const Key('doseTaken')));
      await tester.pumpAndSettle();

      expect(state.logFor(dose)!.status, IntakeStatus.taken);
      expect(find.byType(DoseScreen), findsNothing);
    });

    testWidgets('Given a ringing dose, When Skip is tapped, Then it is recorded as skipped', (tester) async {
      final (state, dose) = await open(tester);

      await tester.tap(find.byKey(const Key('doseSkip')));
      await tester.pumpAndSettle();

      expect(state.logFor(dose)!.status, IntakeStatus.skipped);
    });

    testWidgets('Given a ringing dose, When snoozed, Then nothing is recorded and a reminder is scheduled', (tester) async {
      final (state, dose) = await open(tester);
      calls.clear();

      await tester.tap(find.byKey(const Key('doseSnooze')));
      await tester.pumpAndSettle();

      expect(state.logFor(dose), isNull);
      final scheduled = calls.where((c) => c.method == 'zonedSchedule');
      expect(scheduled, hasLength(1));
      expect((scheduled.single.arguments as Map)['payload'], dose.toString());
    });
  });
  group('took it sheet', () {
    /// Yesterday's second dose of Fictivol: past and not answered yet.
    Future<(AppState, Dose)> open(WidgetTester tester) async {
      final state = await sampleState();
      final yesterday = dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      final dose = dosesForDay(state.routine, state.medicines, yesterday)
          .firstWhere((d) => state.logFor(d.key) == null);
      await tester.pumpWidget(app(state, 'en', Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDoseAnswers(context, dose, DoseState.missed),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (state, dose);
    }

    testWidgets('Given a missed dose, When I took it on time is tapped, Then it is logged at the dose time', (tester) async {
      final (state, dose) = await open(tester);

      await tester.tap(find.byKey(const Key('tookOnTime')));
      await tester.pumpAndSettle();

      final log = state.logFor(dose.key)!;
      expect(log.status, IntakeStatus.taken);
      expect(log.at, dose.time);
    });

    testWidgets('Given a missed dose, When I took it now is tapped, Then it is logged now', (tester) async {
      final (state, dose) = await open(tester);
      final before = DateTime.now();

      await tester.tap(find.byKey(const Key('tookNow')));
      await tester.pumpAndSettle();

      expect(state.logFor(dose.key)!.at.isBefore(before), isFalse);
    });

    testWidgets('Given a missed dose, When a time is picked on the clock, Then it is logged at that time', (tester) async {
      final (state, dose) = await open(tester);

      await tester.tap(find.byKey(const Key('tookAt')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The clock opens at the dose time, so OK keeps it.
      expect(state.logFor(dose.key)!.at, dose.time);
    });
  });
}
