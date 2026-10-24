import 'package:flutter/material.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';
import 'edit_medicine_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final medicines = Scope.of(context).state.medicines;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const EditMedicineScreen())),
        icon: const Icon(Icons.add),
        label: Text(s['addMedicine']),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: PageTitle(s['medicines'])),
          if (medicines.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Text(s['noMedicines'], style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.builder(
              itemCount: medicines.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MedicineCard(medicine: medicines[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final m = medicine;
    final end = m.endDate;
    final finished = end != null && !m.isActiveOn(DateTime.now());
    final large = largeText(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => EditMedicineScreen(medicine: m))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              MedicinePhoto(
                path: m.photoPath,
                size: large ? 48 : 72,
                heroTag: MedicinePhoto.tagFor(m.id),
              ),
              SizedBox(width: large ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: text.titleMedium),
                    Text(
                      '${m.dose} · ${instructionText(s, m)}',
                      style: text.bodyLarge!.copyWith(fontSize: 16),
                    ),
                    if (end != null)
                      Text(
                        s.f('untilDate', {'date': shortDate(s, end)}),
                        style: text.bodyMedium!.copyWith(color: finished ? c.warn : null),
                      ),
                  ],
                ),
              ),
              if (!large) Icon(Icons.chevron_right, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}
