import 'package:flutter/material.dart';

import '../describe.dart';
import '../l10n.dart';
import '../theme.dart';

/// "Hello, Moshe" with today's date, shown for a moment when the app opens.
/// Tapping it goes straight on.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.name, required this.onDone});

  final String name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.alarm,
      child: InkWell(
        onTap: onDone,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: c.onAlarm,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(Icons.medication, size: 64, color: c.alarm),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      s.f('hello', {'name': name}),
                      key: const Key('hello'),
                      textAlign: TextAlign.center,
                      style: text.displayMedium!.copyWith(
                        color: c.onAlarm,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dayTitle(s, DateTime.now()),
                      textAlign: TextAlign.center,
                      style: text.titleMedium!.copyWith(
                        color: c.onAlarmMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
