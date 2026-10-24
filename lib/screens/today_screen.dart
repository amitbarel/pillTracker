import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';
import 'edit_medicine_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final state = Scope.of(context).state;
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

    final String? emptyText = state.medicines.isEmpty
        ? s['noMedicines']
        : doses.isEmpty
            ? s['nothingToday']
            : focus == null
                ? s['allDone']
                : null;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EditMedicineScreen())),
        icon: const Icon(Icons.add),
        label: Text(s['addMedicine']),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageTitle(
              s['today'],
              subtitle: dayTitle(s, now),
              trailing: Pill(state.routine.isWeekend(now)
                  ? s['weekendTimes']
                  : s['weekdayTimes']),
            ),
          ),
          if (doses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _Progress(
                  taken: states.values.where((s) => s == DoseState.taken).length,
                  total: doses.length,
                ),
              ),
            ),
          if (focus != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _FocusCard(key: ValueKey(focus.key), dose: focus, isNow: isNow),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(s['restOfToday']),
                  if (emptyText != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(emptyText, style: text.bodyLarge),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.builder(
              itemCount: doses.length,
              itemBuilder: (context, i) {
                final d = doses[i];
                final newPart = i == 0 || _part(doses[i - 1].time) != _part(d.time);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (newPart)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Text(s[_part(d.time)],
                            style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DoseTile(dose: d, state: states[d.key]!),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _part(DateTime t) => t.hour < 12
    ? 'morning'
    : t.hour < 17
        ? 'afternoon'
        : 'evening';

class _Progress extends StatelessWidget {
  const _Progress({required this.taken, required this.total});

  final int taken;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.f('takenToday', {'taken': taken, 'total': total}),
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : taken / total),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: AppColors.of(context).track,
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({super.key, required this.dose, required this.isNow});

  final Dose dose;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final m = dose.medicine;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = scheme.onPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((isNow ? s['now'] : s['next']).toUpperCase(),
                style: text.labelLarge!.copyWith(fontSize: 16, color: on, letterSpacing: 0.6)),
            const SizedBox(height: 12),
            Row(children: [
              MedicinePhoto(path: m.photoPath, size: 64, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: text.titleLarge!.copyWith(fontSize: 24, color: on)),
                    Text(
                      '${m.dose} · ${whenText(s, dose.anchor, m.food)} · ${clock(dose.time)}',
                      style: text.bodyLarge!.copyWith(color: on),
                    ),
                  ],
                ),
              ),
            ]),
            if (isNow) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('focusTaken'),
                    style: FilledButton.styleFrom(backgroundColor: on, foregroundColor: scheme.primary),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await scope.reminders.dismiss(dose.key);
                      await scope.state.record(dose.key, IntakeStatus.taken);
                    },
                    child: Text(s['tookIt']),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: on,
                    side: BorderSide(color: on.withValues(alpha: 0.7), width: 2),
                    minimumSize: const Size(100, 56),
                  ),
                  onPressed: () async {
                    await scope.reminders.dismiss(dose.key);
                    await scope.reminders.snoozeDose(dose.key);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(s['snoozed'])));
                    }
                  },
                  child: Text(s['later']),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// One dose in a list. Tapping it lets the person change the answer.
class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.dose, required this.state, this.compact = false});

  final Dose dose;
  final DoseState state;

  /// Puts the state under the name instead of beside it, for narrow lists.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scope = Scope.of(context);
    final m = dose.medicine;
    final label = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: DoseStateLabel(
        key: ValueKey(state),
        state: state,
        log: scope.state.logFor(dose.key),
      ),
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _changeAnswer(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            SizedBox(
              width: 62,
              child: Text(clock(dose.time), style: text.titleMedium),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: text.titleMedium!.copyWith(fontSize: 19)),
                  Text('${m.dose} · ${whenText(s, dose.anchor, m.food)}', style: text.bodyMedium),
                  if (compact) Padding(padding: const EdgeInsets.only(top: 4), child: label),
                ],
              ),
            ),
            if (!compact) ...[const SizedBox(width: 8), label],
          ]),
        ),
      ),
    );
  }

  Future<void> _changeAnswer(BuildContext context) async {
    final s = S.of(context);
    final scope = Scope.read(context);
    final answered = state == DoseState.taken || state == DoseState.skipped;
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
                  style: Theme.of(sheet).textTheme.titleLarge!.copyWith(fontSize: 22)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
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
                  child: Text(s['undo']),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
