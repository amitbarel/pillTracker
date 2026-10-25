import 'package:flutter/material.dart';

import 'l10n.dart';

/// What changed in one version, shown once after updating to it.
class Release {
  const Release(this.number, {required this.en, required this.he});

  /// Matches the version name's middle number in pubspec.yaml (0.5.0 is 5).
  final int number;
  final List<String> en;
  final List<String> he;

  List<String> notes(S s) => s.isHebrew ? he : en;
}

/// Newest last. Add one for every version with something to tell.
const releases = [
  Release(
    5,
    en: [
      'A new Settings tab, with your name, the alarm sound, "Make sure alarms ring" and the language.',
      "Choose the alarm sound from your phone's own sounds.",
      'Add your name in Settings for a personal greeting when the app opens.',
      'The app stays behind the lock screen. Only a ringing reminder shows over it.',
    ],
    he: [
      'לשונית הגדרות חדשה: השם שלך, צליל ההתראה, בדיקת ההתראות והשפה.',
      'אפשר לבחור את צליל ההתראה מתוך הצלילים של הטלפון.',
      'הוספת שם בהגדרות מציגה ברכה אישית בפתיחת האפליקציה.',
      'האפליקציה כבר לא נפתחת מעל מסך הנעילה. רק תזכורת מצלצלת מופיעה שם.',
    ],
  ),
];

Release get currentRelease => releases.last;

/// The notes of [release] in a dialog, with one button to close it.
Future<void> showWhatsNew(BuildContext context, Release release) {
  return showDialog<void>(
    context: context,
    builder: (dialog) {
      final s = S.of(dialog);
      final theme = Theme.of(dialog);
      return AlertDialog(
        title: Text(s['whatsNew']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final note in release.notes(s))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2, end: 10),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(child: Text(note, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('whatsNewOk'),
            onPressed: () => Navigator.pop(dialog),
            child: Text(s['gotIt']),
          ),
        ],
      );
    },
  );
}
