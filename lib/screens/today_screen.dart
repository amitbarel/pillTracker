import 'package:flutter/material.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../scope.dart';
import 'common.dart';
import 'edit_medicine_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final state = scope.state;
    final now = DateTime.now();
    final doses = dosesForDay(state.routine, state.medicines, now);
    final states = {
      for (final d in doses) d.key: doseState(d, state.logFor(d.key), now),
    };

    // The card at the top: the earliest dose still waiting for an answer, or
    // else the next one coming up.
    Dose? focus;
    for (final d in doses) {
      final st = states[d.key]!;
      if (st == DoseState.due || st == DoseState.missed) {
        focus = d;
        break;
      }
    }
    final isNow = focus != null;
    focus ??= doses.where((d) => states[d.key] == DoseState.upcoming).firstOrNull;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const EditMedicineScreen())),
        icon: const Icon(Icons.add),
        label: Text(s['addMedicine'],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          PageTitle(
            s['today'],
            subtitle: dayTitle(s, now),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: accentTint, borderRadius: BorderRadius.circular(99)),
              child: Text(
                state.routine.isWeekend(now)
                    ? s['weekendTimes']
                    : s['weekdayTimes'],
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
          if (focus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _FocusCard(dose: focus, isNow: isNow),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(s['restOfToday']),
                if (state.medicines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(s['noMedicines'],
                        style: const TextStyle(fontSize: 18, color: muted)),
                  )
                else if (doses.isEmpty)
                  Text(s['nothingToday'],
                      style: const TextStyle(fontSize: 18, color: muted))
                else if (focus == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(s['allDone'],
                        style: const TextStyle(fontSize: 18, color: muted)),
                  ),
                for (final d in doses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DoseTile(dose: d, state: states[d.key]!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.dose, required this.isNow});

  final Dose dose;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final m = dose.medicine;
    final primary = Theme.of(context).colorScheme.primary;
    const white = Colors.white;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: primary, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((isNow ? s['now'] : s['next']).toUpperCase(),
              style: const TextStyle(
                  color: white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6)),
          const SizedBox(height: 12),
          Row(children: [
            MedicinePhoto(path: m.photoPath, size: 64, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          color: white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Text(
                      '${m.dose} · ${whenText(s, dose.anchor, m.food)} · ${clock(dose.time)}',
                      style: const TextStyle(color: white, fontSize: 18)),
                ],
              ),
            ),
          ]),
          if (isNow) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: white, foregroundColor: primary),
                  onPressed: () async {
                    await scope.reminders.dismiss(dose.key);
                    await scope.state.record(dose.key, IntakeStatus.taken);
                  },
                  child: Text(s['tookIt']),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: white,
                    side: const BorderSide(color: Colors.white70, width: 2),
                    minimumSize: const Size(100, 56)),
                onPressed: () async {
                  await scope.reminders.dismiss(dose.key);
                  await scope.reminders.snoozeDose(dose.key);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s['snoozed'])));
                  }
                },
                child: Text(s['later']),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// One dose in a list. Tapping it lets the person change the answer.
class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.dose, required this.state});

  final Dose dose;
  final DoseState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final m = dose.medicine;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _changeAnswer(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            SizedBox(
              width: 62,
              child: Text(clock(dose.time),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold)),
                  Text('${m.dose} · ${whenText(s, dose.anchor, m.food)}',
                      style: const TextStyle(fontSize: 16, color: muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DoseStateLabel(state: state, log: scope.state.logFor(dose.key)),
          ]),
        ),
      ),
    );
  }

  Future<void> _changeAnswer(BuildContext context) async {
    final s = S.of(context);
    final scope = Scope.of(context);
    final answered =
        state == DoseState.taken || state == DoseState.skipped;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${dose.medicine.name} · ${clock(dose.time)}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  Navigator.pop(sheet);
                  await scope.reminders.dismiss(dose.key);
                  await scope.state.record(dose.key, IntakeStatus.taken);
                },
                label: Text(s['tookIt']),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await scope.reminders.dismiss(dose.key);
                  await scope.state.record(dose.key, IntakeStatus.skipped);
                },
                child: Text(s['skip']),
              ),
              if (answered) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await scope.state.clearRecord(dose.key);
                  },
                  child: Text(s['undo'], style: const TextStyle(fontSize: 18)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
