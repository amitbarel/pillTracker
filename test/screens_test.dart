import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  setUpAll(() async {
    await initializeDateFormatting();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async => true);
  });

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
    testWidgets('all tabs render ($lang)', (tester) async {
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

    testWidgets('add, edit and alarm screens render ($lang)', (tester) async {
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

  testWidgets('saving a new medicine needs a name', (tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(app(state, 'en', const EditMedicineScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);
    expect(state.medicines, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'Acamol');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.medicines.single.name, 'Acamol');
    expect(state.medicines.single.anchors, Preset.twice.anchors);
  });
}
