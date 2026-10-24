import 'dart:io';

import 'package:flutter/material.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../scope.dart';

/// Shown when a reminder rings or is tapped: big photo, big buttons.
class DoseScreen extends StatelessWidget {
  const DoseScreen({super.key, required this.dose});

  final DoseKey dose;

  static const _ground = Color(0xFF0B3D39);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final m = scope.state.medicine(dose.medicineId);
    if (m == null) return const SizedBox.shrink();
    final time = doseTime(scope.state.routine, m, dose.day, dose.anchor);
    final log = scope.state.logFor(dose);
    final photo = m.photoPath;
    const white = Colors.white;

    Future<void> answer(Future<void> Function() action) async {
      await scope.reminders.dismiss(dose);
      await action();
      if (context.mounted) Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: _ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: white, size: 30),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
              Text(s['timeForMedicine'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 22)),
              Text(clock(time),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      height: 1.1)),
              Text(
                  '${dayTitle(s, dose.day)} · ${whenText(s, dose.anchor, m.food)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: white, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photo != null && File(photo).existsSync())
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: Image.file(File(photo), fit: BoxFit.cover),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(height: 12),
                      Text(m.name,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      Text(s.f('take', {'dose': m.dose}),
                          style: const TextStyle(fontSize: 22)),
                      if (m.notes.isNotEmpty)
                        Text(m.notes,
                            style: const TextStyle(
                                fontSize: 17, color: Color(0xFF5B6461))),
                      if (log != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            log.status == IntakeStatus.taken
                                ? s.f('takenAt', {'time': clock(log.at)})
                                : s['skipped'],
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: white,
                  foregroundColor: _ground,
                  minimumSize: const Size.fromHeight(76),
                  textStyle: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.check, size: 32),
                onPressed: () => answer(
                    () => scope.state.record(dose, IntakeStatus.taken)),
                label: Text(s['tookIt']),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: white,
                      side: const BorderSide(color: Colors.white70, width: 2),
                      minimumSize: const Size.fromHeight(60),
                    ),
                    onPressed: () =>
                        answer(() => scope.reminders.snoozeDose(dose)),
                    child: Text(s['remindIn10'], textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: white,
                    side: const BorderSide(color: Colors.white38, width: 2),
                    minimumSize: const Size(100, 60),
                  ),
                  onPressed: () => answer(
                      () => scope.state.record(dose, IntakeStatus.skipped)),
                  child: Text(s['skip']),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
