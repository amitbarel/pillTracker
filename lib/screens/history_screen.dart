import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../scope.dart';
import '../store.dart';
import 'common.dart';
import 'today_screen.dart';

const historyDays = 30;

/// Past doses of one day, with what happened to each.
class DayRecord {
  DayRecord(this.day, this.doses);
  final DateTime day;
  final List<(Dose, DoseState)> doses;

  int get taken => doses.where((d) => d.$2 == DoseState.taken).length;

  /// Doses whose time has come, so "4 of 5" doesn't count the evening early.
  int get due => doses.where((d) => d.$2 != DoseState.upcoming).length;
}

List<DayRecord> buildHistory(AppState state, DateTime now, {int days = historyDays}) {
  final today = dateOnly(now);
  return [
    for (var i = 0; i < days; i++)
      () {
        final day = DateTime(today.year, today.month, today.day - i);
        final doses = dosesForDay(state.routine, state.medicines, day);
        return DayRecord(day, [
          for (final d in doses) (d, doseState(d, state.logFor(d.key), now)),
        ]);
      }(),
  ].where((r) => r.due > 0).toList();
}

String historyText(S s, AppState state, List<DayRecord> records) {
  final b = StringBuffer();
  for (final r in records) {
    b.writeln('${dayTitle(s, r.day)} (${s.f('ofDoses', {'taken': r.taken, 'total': r.due})})');
    for (final (dose, st) in r.doses) {
      final status = switch (st) {
        DoseState.upcoming => null,
        DoseState.taken => s.f('takenAt', {'time': clock(state.logFor(dose.key)!.at)}),
        DoseState.skipped => s['skipped'],
        DoseState.due || DoseState.missed => s['missed'],
      };
      if (status == null) continue;
      b.writeln('${clock(dose.time)}  ${dose.medicine.name} (${dose.medicine.dose}): $status');
    }
    b.writeln();
  }
  return b.toString().trim();
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = Scope.of(context).state;
    final now = DateTime.now();
    final records = buildHistory(state, now);
    final week = records.where((r) => now.difference(r.day).inDays < 7);
    final taken = week.fold(0, (n, r) => n + r.taken);
    final total = week.fold(0, (n, r) => n + r.due);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageTitle(s['history'],
            subtitle: total == 0
                ? null
                : s.f('last7', {'taken': taken, 'total': total})),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(s['nothingYet'],
                style: const TextStyle(fontSize: 18, color: muted)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(ShareParams(
                  text: historyText(s, state, records),
                  subject: s['history'])),
              label: Text(s['shareHistory']),
            ),
          ),
        for (final r in records)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(dayTitle(s, r.day),
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.bold)),
                        ),
                        Text(s.f('ofDoses', {'taken': r.taken, 'total': r.due}),
                            style: TextStyle(
                                fontSize: 16,
                                color: r.taken == r.due ? muted : warn,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    for (final (dose, st) in r.doses)
                      if (st != DoseState.upcoming)
                        DoseTile(dose: dose, state: st),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
