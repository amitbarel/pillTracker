import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_tracker/models.dart';
import 'package:pill_tracker/store.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pill_store_test');
    file = File('${dir.path}/pill_tracker.json');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Medicine paracetamol(AppState state) => Medicine(
        id: state.newMedicineId(),
        name: 'Paracetamol',
        anchors: Preset.twice.anchors,
        startDate: DateTime(2026, 10, 1),
      );

  group('AppState persistence', () {
    test('Given no saved file, When loaded, Then it starts empty with default times', () async {
      final state = await AppState.loadFrom(file);

      expect(state.medicines, isEmpty);
      expect(state.logs, isEmpty);
      expect(state.routine.weekday[Anchor.wake], const TimeOfDay(hour: 6, minute: 0));
      expect(state.languageCode, isNull);
    });

    test('Given saved medicines, logs, routine and language, When reloaded, Then all come back', () async {
      final state = await AppState.loadFrom(file);
      final m = paracetamol(state);
      await state.saveMedicine(m);
      final key = DoseKey(m.id, DateTime(2026, 10, 24), Anchor.breakfast);
      await state.record(key, IntakeStatus.taken, at: DateTime(2026, 10, 24, 8, 5));
      await state.setRoutine(state.routine.copyWith(weekendDays: {5, 6}));
      await state.setLanguage('he');

      final reloaded = await AppState.loadFrom(file);

      expect(reloaded.medicines.single.name, 'Paracetamol');
      expect(reloaded.logFor(key)!.at, DateTime(2026, 10, 24, 8, 5));
      expect(reloaded.routine.weekendDays, {5, 6});
      expect(reloaded.languageCode, 'he');
    });

    test('Given a saved medicine, When reloaded, Then new ids do not collide with it', () async {
      final state = await AppState.loadFrom(file);
      final first = paracetamol(state);
      await state.saveMedicine(first);

      final reloaded = await AppState.loadFrom(file);

      expect(reloaded.newMedicineId(), isNot(first.id));
    });

    test('Given a corrupt file, When loaded, Then it starts empty and keeps a backup', () async {
      file.writeAsStringSync('{not json');

      final state = await AppState.loadFrom(file);

      expect(state.medicines, isEmpty);
      final backups = dir.listSync().where((f) => f.path.contains('.broken-'));
      expect(backups, hasLength(1));
      expect(File(backups.single.path).readAsStringSync(), '{not json');
    });
  });

  group('AppState answers', () {
    test('Given a dose marked taken, When marked skipped, Then only the latest answer is kept', () async {
      final state = AppState.memory();
      final key = DoseKey(1, DateTime(2026, 10, 24), Anchor.dinner);

      await state.record(key, IntakeStatus.taken);
      await state.record(key, IntakeStatus.skipped);

      expect(state.logs, hasLength(1));
      expect(state.logFor(key)!.status, IntakeStatus.skipped);
    });

    test('Given an answered dose, When cleared, Then it has no answer', () async {
      final state = AppState.memory();
      final key = DoseKey(1, DateTime(2026, 10, 24), Anchor.dinner);
      await state.record(key, IntakeStatus.taken);

      await state.clearRecord(key);

      expect(state.logFor(key), isNull);
    });

    test('Given any change, When saved, Then reminders are asked to reschedule', () async {
      final state = AppState.memory();
      var calls = 0;
      state.onScheduleChanged = () => calls++;

      await state.saveMedicine(paracetamol(state));
      await state.record(DoseKey(1, DateTime(2026, 10, 24), Anchor.dinner), IntakeStatus.taken);
      await state.setRoutine(state.routine);

      expect(calls, 3);
    });

    test('Given a medicine with a photo, When deleted, Then the photo file is removed', () async {
      final state = AppState.memory();
      final photo = File('${dir.path}/box.jpg')..writeAsBytesSync([1, 2, 3]);
      final m = paracetamol(state)..photoPath = photo.path;
      await state.saveMedicine(m);

      await state.deleteMedicine(m);

      expect(state.medicines, isEmpty);
      expect(photo.existsSync(), isFalse);
    });
  });
}
