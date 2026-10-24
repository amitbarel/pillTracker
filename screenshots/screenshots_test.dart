// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the main screens to PNGs with the real fonts, for reviewing the UI
// without a phone. Not part of the normal test run:
//
//   flutter test screenshots --update-goldens
//
// Images land in screenshots/out/.
import 'dart:io';

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

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await _loadFont('Rubik', [
      'assets/fonts/Rubik-Regular.ttf',
      'assets/fonts/Rubik-Medium.ttf',
      'assets/fonts/Rubik-Bold.ttf',
    ]);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
    await _loadFont('MaterialIcons',
        ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async => switch (call.method) {
                  'getActiveNotifications' || 'pendingNotificationRequests' => <Object>[],
                  _ => true,
                });
  });

  Future<AppState> sample(String lang) async {
    final he = lang == 'he';
    final state = AppState.memory();
    final today = dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    await state.saveMedicine(Medicine(
      id: state.newMedicineId(),
      name: he ? 'קסרלטו 10 מ״ג' : 'Xarelto 10 mg',
      dose: he ? 'כדור אחד' : '1 pill',
      anchors: {Anchor.wake},
      startDate: start,
    ));
    await state.saveMedicine(Medicine(
      id: state.newMedicineId(),
      name: he ? 'אקמול 500 מ״ג' : 'Paracetamol 500 mg',
      dose: he ? '2 כדורים' : '2 pills',
      anchors: Preset.three.anchors,
      startDate: start,
      endDate: today.add(const Duration(days: 4)),
    ));
    await state.saveMedicine(Medicine(
      id: state.newMedicineId(),
      name: he ? 'צלקוקסיב 200 מ״ג' : 'Celecoxib 200 mg',
      dose: he ? 'כמוסה אחת' : '1 capsule',
      anchors: Preset.twice.anchors,
      startDate: start,
    ));
    // A week of history: everything taken a few minutes late, one miss.
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final doses = dosesForDay(state.routine, state.medicines, day);
      for (final (n, d) in doses.indexed) {
        if (d.time.isAfter(DateTime.now())) continue;
        if (i == 1 && n == 3) continue;
        if (i == 0 && d == doses.where((x) => !x.time.isAfter(DateTime.now())).last) continue;
        await state.record(d.key, IntakeStatus.taken, at: d.time.add(Duration(minutes: 3 + n)));
      }
    }
    return state;
  }

  Widget app(AppState state, String lang, Widget home) => Scope(
        state: state,
        reminders: Reminders(state),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: Locale(lang),
          supportedLocales: S.supported,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      );

  for (final lang in ['en', 'he']) {
    testWidgets('screens $lang', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final state = await sample(lang);

      await tester.pumpWidget(app(state, lang, const HomeScreen()));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${lang}_1_today.png'));
      final tabs = [
        (Icons.medication_outlined, 'medicines'),
        (Icons.calendar_month_outlined, 'history'),
        (Icons.wb_sunny_outlined, 'myday'),
      ];
      for (final (i, (icon, name)) in tabs.indexed) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${lang}_${i + 2}_$name.png'));
      }
      // My day is open: the clock for changing a time.
      await tester.tap(find.text('6:00'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${lang}_4b_timepicker.png'));
      await tester.tap(find.byType(TextButton).first); // Cancel
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(state, lang, EditMedicineScreen(medicine: state.medicines[1])));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${lang}_5_edit.png'));

      // Once a day: one time only.
      await tester.pumpWidget(app(state, lang, EditMedicineScreen(medicine: state.medicines[0])));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${lang}_5b_once.png'));

      final dose = dosesForDay(state.routine, state.medicines, DateTime.now())[1];
      await tester.pumpWidget(app(state, lang, DoseScreen(dose: dose.key)));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${lang}_6_alarm.png'));
    });
  }
}
