import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  bool? _notifications;
  bool? _alarms;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  Future<void> _checkPermissions() async {
    final r = Scope.read(context).reminders;
    final n = await r.notificationsAllowed();
    final a = await r.exactAlarmsAllowed();
    if (mounted) {
      setState(() {
        _notifications = n;
        _alarms = a;
      });
    }
  }

  Future<void> _editTime(Anchor anchor, bool weekend) async {
    final state = Scope.read(context).state;
    final routine = state.routine;
    final day = weekend ? routine.weekend : routine.weekday;
    final picked = await pickClockTime(context, day[anchor]);
    if (picked == null) return;
    final updated = day.withTime(anchor, picked);
    await state.setRoutine(weekend
        ? routine.copyWith(weekend: updated)
        : routine.copyWith(weekday: updated));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final state = scope.state;
    final routine = state.routine;
    final primary = Theme.of(context).colorScheme.primary;
    final text = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final time = text.titleMedium!.copyWith(fontWeight: FontWeight.w500);
    final column = text.labelLarge!.copyWith(fontSize: 16, color: c.muted);
    // The week starts on Sunday: 31 Dec 2023 was one.
    final sunday = DateTime(2023, 12, 31);

    String rowLabel(Anchor a) =>
        a == Anchor.wake ? s['routine.wake'] : anchorName(s, a);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageTitle(s['myDay'], subtitle: s['routineIntro']),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(children: [
                    const SizedBox(),
                    Center(
                        child: Text(s['weekdays'],
                            style: column)),
                    Center(
                        child: Text(s['weekends'],
                            style: column)),
                  ]),
                  for (final a in Anchor.values)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(rowLabel(a),
                            style: text.bodyLarge),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.ink,
                            side: BorderSide(color: c.line),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _editTime(a, false),
                          child: Text(clockOfDay(routine.weekday[a]),
                              style: time),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.accentTint,
                            foregroundColor: primary,
                            minimumSize: const Size(64, 52),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _editTime(a, true),
                          child: Text(clockOfDay(routine.weekend[a]),
                              style: time),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton(
            onPressed: () => state.setRoutine(
                routine.copyWith(weekend: routine.weekday.shiftedBy(60))),
            child: Text(s['shiftWeekend']),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SectionTitle(s['whichWeekend']),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final day in [for (var i = 0; i < 7; i++) sunday.add(Duration(days: i))])
              FilterChip(
                showCheckmark: false,
                label: Text(DateFormat.E(s.languageCode).format(day)),
                selected: routine.weekendDays.contains(day.weekday),
                onSelected: (on) {
                  final days = {...routine.weekendDays};
                  on ? days.add(day.weekday) : days.remove(day.weekday);
                  state.setRoutine(routine.copyWith(weekendDays: days));
                },
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SectionTitle(s['reliability']),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(children: [
              _permissionTile(s, s['allowNotifications'], _notifications),
              _permissionTile(s, s['allowAlarms'], _alarms),
              ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: Text(s['batteryTip'], style: text.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.alarm),
                  onPressed: () async {
                    await scope.reminders.testAlarm();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(s['testAlarmSet'])));
                    }
                  },
                  label: Text(s['testAlarm']),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SectionTitle(s['language']),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: '', label: Text(s['systemLanguage'])),
              const ButtonSegment(value: 'en', label: Text('English')),
              const ButtonSegment(value: 'he', label: Text('עברית')),
            ],
            selected: {state.languageCode ?? ''},
            onSelectionChanged: (v) =>
                state.setLanguage(v.first.isEmpty ? null : v.first),
          ),
        ),
      ],
    );
  }

  Widget _permissionTile(S s, String title, bool? allowed) {
    final primary = Theme.of(context).colorScheme.primary;
    final c = AppColors.of(context);
    return ListTile(
      leading: Icon(
        allowed == false ? Icons.error_outline : Icons.check_circle_outline,
        color: allowed == false ? c.warn : primary,
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: allowed == true ? Text(s['allowed']) : null,
      trailing: allowed == false
          ? FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () async {
                await Scope.of(context).reminders.requestPermissions();
                await _checkPermissions();
              },
              child: const Icon(Icons.arrow_forward),
            )
          : null,
    );
  }
}
