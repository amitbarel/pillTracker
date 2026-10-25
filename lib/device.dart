import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// The bits of Android the plugins don't cover, from MainActivity.kt. Each
/// does nothing where that code isn't there (tests, other platforms).
class Device {
  static const _sound = MethodChannel('pill_tracker/sound');
  static const _screen = MethodChannel('pill_tracker/screen');

  /// The phone's alarm, notification and ringtone sounds, as its own sound
  /// pickers list them.
  static Future<List<AlarmSound>> phoneSounds() async {
    try {
      final list = await _sound.invokeListMethod<Map>('list') ?? [];
      return [
        for (final m in list)
          AlarmSound(
            m['uri'] as String,
            m['title'] as String,
            kind: SoundKind.values.byName(m['kind'] as String),
          ),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Could not list the sounds: $e');
      return const [];
    }
  }

  /// Plays [sound] for a few seconds, as an alarm would; null plays the
  /// phone's notification sound.
  static Future<void> play(AlarmSound? sound) async {
    try {
      await _sound.invokeMethod<void>('play', {'uri': sound?.uri});
    } on MissingPluginException {
      // Nothing to play on.
    } on PlatformException catch (e) {
      debugPrint('Could not play the sound: $e');
    }
  }

  /// An alarm shows the app over the lock screen; once it is answered the
  /// app goes back behind the lock.
  static Future<void> alarmClosed() async {
    try {
      await _screen.invokeMethod<void>('alarmClosed');
    } on MissingPluginException {
      // Nothing to hide.
    }
  }
}
