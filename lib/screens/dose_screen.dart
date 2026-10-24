import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';

/// Shown when a reminder rings or is tapped: big photo, big buttons.
class DoseScreen extends StatelessWidget {
  const DoseScreen({super.key, required this.dose});

  final DoseKey dose;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final m = scope.state.medicine(dose.medicineId);
    if (m == null) return const SizedBox.shrink();
    final time = doseTime(scope.state.routine, m, dose.day, dose.anchor);
    final log = scope.state.logFor(dose);
    final photo = m.photoPath;
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final white = c.onAlarm;
    final soft = text.bodyLarge!.copyWith(color: c.onAlarmMuted);

    Future<void> answer(Future<void> Function() action) async {
      await scope.reminders.dismiss(dose);
      await action();
      if (context.mounted) Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: c.alarm,
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
                  icon: Icon(Icons.close, color: white, size: 30),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
              Text(s['timeForMedicine'],
                  textAlign: TextAlign.center,
                  style: soft.copyWith(fontSize: 22)),
              Text(clock(time),
                  textAlign: TextAlign.center,
                  style: text.displayLarge!.copyWith(color: white)),
              Text(
                  '${dayTitle(s, dose.day)} · ${whenText(s, dose.anchor, m.food)}',
                  textAlign: TextAlign.center,
                  style: soft),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(24)),
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
                        Expanded(
                          child: Center(
                            child: MedicinePhoto(size: 140, radius: 28),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(m.name,
                          style: text.titleLarge!.copyWith(fontSize: 28, color: c.ink)),
                      Text(s.f('take', {'dose': m.dose}),
                          style: text.bodyLarge!.copyWith(fontSize: 22)),
                      if (m.notes.isNotEmpty)
                        Text(m.notes,
                            style: text.bodyMedium!.copyWith(fontSize: 17)),
                      if (log != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            log.status == IntakeStatus.taken
                                ? s.f('takenAt', {'time': clock(log.at)})
                                : s['skipped'],
                            style: text.labelLarge!.copyWith(
                                fontSize: 18, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('doseTaken'),
                style: FilledButton.styleFrom(
                  backgroundColor: white,
                  foregroundColor: c.alarm,
                  minimumSize: const Size.fromHeight(76),
                  textStyle: text.labelLarge!.copyWith(fontSize: 26),
                ),
                icon: const Icon(Icons.check, size: 32),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  answer(() => scope.state.record(dose, IntakeStatus.taken));
                },
                label: Text(s['tookIt']),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('doseSnooze'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: white,
                      side: BorderSide(color: c.onAlarmMuted, width: 2),
                      minimumSize: const Size.fromHeight(60),
                    ),
                    onPressed: () =>
                        answer(() => scope.reminders.snoozeDose(dose)),
                    child: Text(s['remindIn10'], textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const Key('doseSkip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: white,
                    side: BorderSide(color: c.onAlarmMuted.withValues(alpha: 0.35), width: 2),
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
