import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Everything the app knows, saved as one JSON file on the phone.
class AppState extends ChangeNotifier {
  AppState._(this._file);

  final File? _file;

  List<Medicine> medicines = [];
  List<IntakeLog> logs = [];
  Routine routine = Routine.defaults;

  /// 'en' or 'he'; null follows the phone's language.
  String? languageCode;
  int _nextId = 1;

  /// Called after anything that affects reminders changes.
  VoidCallback? onScheduleChanged;

  static Future<AppState> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final state = AppState._(File('${dir.path}/pill_tracker.json'));
    await state._read();
    return state;
  }

  /// An in-memory state, for tests.
  @visibleForTesting
  factory AppState.memory() => AppState._(null);

  /// A state saved to [file], for tests.
  @visibleForTesting
  static Future<AppState> loadFrom(File file) async {
    final state = AppState._(file);
    await state._read();
    return state;
  }

  Future<void> _read() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      medicines = ((json['medicines'] as List?) ?? [])
          .map((m) => Medicine.fromJson((m as Map).cast<String, dynamic>()))
          .toList();
      logs = ((json['logs'] as List?) ?? [])
          .map((l) => IntakeLog.fromJson((l as Map).cast<String, dynamic>()))
          .toList();
      if (json['routine'] is Map) {
        routine = Routine.fromJson((json['routine'] as Map).cast<String, dynamic>());
      }
      languageCode = json['language'] as String?;
      _nextId = (json['nextId'] as int?) ??
          (medicines.isEmpty ? 1 : medicines.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1);
    } catch (e) {
      // Keep a copy of an unreadable file rather than silently losing it.
      debugPrint('Could not read saved data: $e');
      await file.copy('${file.path}.broken-${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': 1,
      'nextId': _nextId,
      'language': languageCode,
      'routine': routine.toJson(),
      'medicines': medicines.map((m) => m.toJson()).toList(),
      'logs': logs.map((l) => l.toJson()).toList(),
    }));
    await tmp.rename(file.path);
  }

  Future<void> _changed({bool schedule = false}) async {
    notifyListeners();
    await _save();
    if (schedule) onScheduleChanged?.call();
  }

  Medicine? medicine(int id) {
    for (final m in medicines) {
      if (m.id == id) return m;
    }
    return null;
  }

  int newMedicineId() => _nextId++;

  Future<void> saveMedicine(Medicine m) async {
    final i = medicines.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      medicines[i] = m;
    } else {
      medicines.add(m);
    }
    await _changed(schedule: true);
  }

  Future<void> deleteMedicine(Medicine m) async {
    medicines.removeWhere((x) => x.id == m.id);
    final photo = m.photoPath;
    if (photo != null) {
      try {
        await File(photo).delete();
      } catch (_) {}
    }
    await _changed(schedule: true);
  }

  Future<void> setRoutine(Routine r) async {
    routine = r;
    await _changed(schedule: true);
  }

  Future<void> setLanguage(String? code) async {
    languageCode = code;
    // Reminder text is written in the chosen language.
    await _changed(schedule: true);
  }

  IntakeLog? logFor(DoseKey key) {
    final k = key.toString();
    for (final l in logs) {
      if (l.doseKey == k) return l;
    }
    return null;
  }

  /// Records [status] for a dose, replacing any earlier answer for it.
  Future<void> record(DoseKey key, IntakeStatus status, {DateTime? at}) async {
    logs.removeWhere((l) => l.doseKey == key.toString());
    logs.add(IntakeLog(
      medicineId: key.medicineId,
      day: key.day,
      slot: key.slot,
      status: status,
      at: at ?? DateTime.now(),
    ));
    await _changed(schedule: true);
  }

  Future<void> clearRecord(DoseKey key) async {
    logs.removeWhere((l) => l.doseKey == key.toString());
    await _changed(schedule: true);
  }
}
