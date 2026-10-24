import 'package:flutter/material.dart';

import '../describe.dart';
import '../l10n.dart';
import '../scope.dart';
import 'common.dart';
import 'edit_medicine_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final medicines = Scope.of(context).state.medicines;
    final today = DateTime.now();
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
          PageTitle(s['medicines']),
          if (medicines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(s['noMedicines'],
                  style: const TextStyle(fontSize: 18, color: muted)),
            ),
          for (final m in medicines)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => EditMedicineScreen(medicine: m))),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      MedicinePhoto(path: m.photoPath, size: 72),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('${m.dose} · ${instructionText(s, m)}',
                                style: const TextStyle(fontSize: 16)),
                            if (m.endDate != null)
                              Text(
                                s.f('untilDate',
                                    {'date': shortDate(s, m.endDate!)}),
                                style: TextStyle(
                                    fontSize: 16,
                                    color: m.isActiveOn(today) ? muted : warn),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
