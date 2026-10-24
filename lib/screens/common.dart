import 'dart:io';

import 'package:flutter/material.dart';

import '../describe.dart';
import '../l10n.dart';
import '../models.dart';
import '../schedule.dart';
import '../theme.dart';

/// The photo of the box, or a placeholder.
///
/// Give [heroTag] where the same medicine's photo appears on the next screen,
/// so it flies across instead of popping in.
class MedicinePhoto extends StatelessWidget {
  const MedicinePhoto({
    super.key,
    this.path,
    this.size = 56,
    this.radius = 12,
    this.heroTag,
  });

  final String? path;
  final double size;
  final double radius;
  final Object? heroTag;

  static Object tagFor(int medicineId) => 'medicine-photo-$medicineId';

  @override
  Widget build(BuildContext context) {
    final p = path;
    final file = p == null ? null : File(p);
    final scheme = Theme.of(context).colorScheme;
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: file != null && file.existsSync()
            ? Image.file(file, fit: BoxFit.cover, cacheWidth: (size * 3).round())
            : ColoredBox(
                color: AppColors.of(context).accentTint,
                child: Icon(Icons.medication, size: size * 0.55, color: scheme.primary),
              ),
      ),
    );
    final tag = heroTag;
    return tag == null ? photo : Hero(tag: tag, child: photo);
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
    final c = AppColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 16);
    switch (state) {
      case DoseState.taken:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check, color: primary, size: 22),
          const SizedBox(width: 4),
          Text(s.f('takenAt', {'time': clock(log!.at)}),
              style: style.copyWith(color: primary)),
        ]);
      case DoseState.skipped:
        return Text(s['skipped'], style: style.copyWith(color: c.muted));
      case DoseState.missed:
        return DecoratedBox(
          decoration: BoxDecoration(color: c.warnTint, borderRadius: BorderRadius.circular(99)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(s['missed'], style: style.copyWith(color: c.warn)),
          ),
        );
      case DoseState.due:
        return Text(s['due'], style: style.copyWith(color: c.warn));
      case DoseState.upcoming:
        return Text(s['upcoming'],
            style: style.copyWith(color: c.muted, fontWeight: FontWeight.w400));
    }
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: text.headlineMedium)),
            ?trailing,
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: text.bodyMedium!.copyWith(fontSize: 18)),
            ),
        ],
      ),
    );
  }
}

/// A rounded badge, like "Weekend times".
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.of(context).accentTint,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontSize: 15, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
}
