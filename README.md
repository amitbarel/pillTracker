# Pill Tracker

A simple medicine reminder for Android, in Hebrew and English.

- **Add a medicine by photo.** Take a picture of the box and tap the name the
  app reads off it. Reading happens on the phone, with no internet: Google
  ML Kit for English and Tesseract for Hebrew (Android only for now). The
  name can always be edited.
- **Plain instructions.** "Twice a day", "after food", for how many days.
- **Weekday and weekend times.** Doses are tied to wake-up, meals and bedtime.
  Set those once for weekdays and once for weekends (an hour later by
  default) and every reminder follows. The weekend is Friday and Saturday
  by default and can be changed.
- **Alarms that ring.** Reminders use Android's alarm-clock scheduling, show
  over the lock screen with the photo of the box, keep ringing until
  answered, and survive restarts. Buttons: I took it / In 10 min / Skip.
- **History.** What was taken, skipped or missed each day, shareable with the
  doctor as text.

Everything stays on the phone. There is no account and no server.

## Installing on the phone

Each push to `main` builds the app on GitHub and puts it on the
[latest release](../../releases/tag/latest). On the phone, open that page,
download `pill-tracker.apk`, and allow installing from the browser when asked.
Updates install the same way, over the old version, keeping all data, as long
as the build is signed with the same key (see Signing).

After installing, open **My day** and tap **Ring a test alarm**. If it doesn't
ring on time, turn off battery optimisation for the app in the phone's
settings (see [dontkillmyapp.com](https://dontkillmyapp.com) for the phone's
brand).

## Signing

Release builds are signed with the key in the repository secrets
`PILL_KEYSTORE_BASE64`, `PILL_KEYSTORE_PASSWORD`, `PILL_KEY_ALIAS` and
`PILL_KEY_PASSWORD`. Without them the build uses a throwaway debug key, and
each new build would need the old app uninstalled first.

## Development

```sh
flutter pub get
flutter test
flutter run
```

Code map: `lib/models.dart` (medicines, routine, intake log),
`lib/schedule.dart` (when each dose is due), `lib/notifications.dart`
(alarms), `lib/ocr.dart` (reading the box), `lib/l10n.dart` (texts),
`lib/screens/`.

The code is iPhone-ready, but iOS builds need a Mac (or a cloud build service)
and an Apple Developer account, and alarms that break through silent mode need
AlarmKit on iOS 26. Not done yet.
