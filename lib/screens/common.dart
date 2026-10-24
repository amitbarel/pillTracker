import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../describe.dart';

const muted = Color(0xFF5B6461);
const warn = Color(0xFFB4480E);
const warnTint = Color(0xFFFCEBDD);
const accentTint = Color(0xFFE3F1EF);

/// The photo of the box, or a placeholder.
class MedicinePhoto extends StatelessWidget {
  const MedicinePhoto({super.key, this.path, this.size = 56, this.radius = 12});

  final String? path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = path;
    final file = p == null ? null : File(p);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: file != null && file.existsSync()
            ? Image.file(file, fit: BoxFit.cover, cacheWidth: (size * 3).round())
            : ColoredBox(
                color: accentTint,
                child: Icon(Icons.medication,
                    size: size * 0.55, color: Theme.of(context).colorScheme.primary),
              ),
      ),
    );
  }
}

/// A short coloured label for a dose's state.
class DoseStateLabel extends StatelessWidget {
  const DoseStateLabel({super.key, required this.state, this.log});

  final DoseState state;
  final IntakeLog? log;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    const style = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    switch (state) {
      case DoseState.taken:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check, color: primary, size: 22),
          const SizedBox(width: 4),
          Text(s.f('takenAt', {'time': clock(log!.at)}),
              style: style.copyWith(color: primary)),
        ]);
      case DoseState.skipped:
        return Text(s['skipped'], style: style.copyWith(color: muted));
      case DoseState.missed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: warnTint, borderRadius: BorderRadius.circular(99)),
          child: Text(s['missed'], style: style.copyWith(color: warn)),
        );
      case DoseState.due:
        return Text(s['due'], style: style.copyWith(color: warn));
      case DoseState.upcoming:
        return Text(s['upcoming'],
            style: const TextStyle(fontSize: 16, color: muted));
    }
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              ?trailing,
            ]),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!,
                    style: const TextStyle(fontSize: 18, color: muted)),
              ),
          ],
        ),
      );
}
