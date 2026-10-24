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
      name: 'Paracetamol 500 mg',
      dose: '2 pills',
      anchors: Preset.three.anchors,
      startDate: today.subtract(const Duration(days: 5)),
      endDate: today.add(const Duration(days: 5)),
    ));
    await state.saveMedicine(Medicine(
      id: state.newMedicineId(),
      name: 'Xarelto 10 mg',
      anchors: {Anchor.wake},
      startDate: today.subtract(const Duration(days: 5)),
      notes: 'Blood thinner after the knee surgery',
    ));
    final first = dosesForDay(state.routine, state.medicines,
        today.subtract(const Duration(days: 1)));
    await state.record(first.first.key, IntakeStatus.taken);
    return state;
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
      expect(find.text('Paracetamol 500 mg'), findsWidgets);
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

    await tester.enterText(find.byKey(const Key('nameField')), 'Acamol');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    final m = state.medicines.single;
    expect(m.name, 'Acamol');
    expect(m.anchors, Preset.twice.anchors);
    expect(m.food, FoodRelation.after);
    expect(m.dose, '1 pill');
  });

  testWidgets('Given no times chosen, When Save is tapped, Then it asks for a time', (tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Acamol');

    // Twice a day starts selected: untick both of its times.
    for (final a in [Anchor.breakfast, Anchor.dinner]) {
      final chip = find.byKey(Key('anchor.${a.name}'));
      await tester.scrollUntilVisible(chip, 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(chip);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one time'), findsOneWidget);
    expect(state.medicines, isEmpty);
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
}
