import 'dart:async';

import 'package:flutter/material.dart';

import '../describe.dart';
import '../device.dart';
import '../l10n.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';

/// The person's name, the alarm sound, checks that alarms can ring, and the
/// language.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notifications;
  bool? _alarms;
  late final TextEditingController _name;
  Timer? _saveName;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: Scope.read(context).state.userName);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  @override
  void dispose() {
    // Save a name still being typed when the tab changes.
    if (_saveName?.isActive ?? false) {
      _saveName!.cancel();
      Scope.read(context).state.setUserName(_name.text);
    }
    _name.dispose();
    super.dispose();
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

  /// Saves the name once typing pauses, not on every letter.
  void _onNameChanged(String name) {
    final state = Scope.read(context).state;
    _saveName?.cancel();
    _saveName = Timer(const Duration(milliseconds: 600), () => state.setUserName(name));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = Scope.of(context);
    final state = scope.state;
    final text = Theme.of(context).textTheme;

    Widget section(String title) =>
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: SectionTitle(title));
    Widget padded(Widget child) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PageTitle(s['settings']),
        padded(
          TextField(
            key: const Key('userName'),
            controller: _name,
            style: text.titleMedium!.copyWith(fontWeight: FontWeight.w400),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: s['yourName'], helperText: s['yourNameHint']),
            onChanged: _onNameChanged,
            onSubmitted: (name) {
              _saveName?.cancel();
              state.setUserName(name);
            },
          ),
        ),
        section(s['alarmSound']),
        padded(Text(s['alarmSoundHint'], style: text.bodyMedium)),
        const SizedBox(height: 10),
        padded(const _SoundPicker()),
        section(s['reliability']),
        padded(
          Card(
            child: Column(
              children: [
                _permissionTile(s, s['allowNotifications'], _notifications),
                _permissionTile(s, s['allowAlarms'], _alarms),
                ListTile(
                  leading: const Icon(Icons.battery_alert_outlined),
                  title: Text(s['batteryTip'], style: text.bodyMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    icon: const Icon(Icons.alarm),
                    onPressed: () async {
                      await scope.reminders.testAlarm();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(s['testAlarmSet'])));
                      }
                    },
                    label: Text(s['testAlarm']),
                  ),
                ),
              ],
            ),
          ),
        ),
        section(s['language']),
        padded(
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: '', label: Text(s['systemLanguage'])),
              const ButtonSegment(value: 'en', label: Text('English')),
              const ButtonSegment(value: 'he', label: Text('עברית')),
            ],
            selected: {state.languageCode ?? ''},
            onSelectionChanged: (v) => state.setLanguage(v.first.isEmpty ? null : v.first),
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

/// A dropdown of the phone's own sounds, with the app's tones first. Picking
/// one plays it.
class _SoundPicker extends StatefulWidget {
  const _SoundPicker();

  @override
  State<_SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends State<_SoundPicker> {
  List<AlarmSound> _phone = const [];

  @override
  void initState() {
    super.initState();
    Device.phoneSounds().then((sounds) {
      if (mounted) setState(() => _phone = sounds);
    });
  }

  static IconData _icon(AlarmSound? sound) => switch (sound?.kind) {
    null || SoundKind.notification => Icons.notifications_outlined,
    SoundKind.app => Icons.music_note_outlined,
    SoundKind.alarm => Icons.alarm,
    SoundKind.ringtone => Icons.ring_volume_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = Scope.of(context).state;
    final chosen = state.alarmSound;
    // By uri; '' is the phone's notification sound.
    final sounds = <String, AlarmSound?>{
      '': null,
      for (final t in AlarmSound.appTones) t.uri: t,
      for (final p in _phone) p.uri: p,
    };
    // A sound chosen earlier may since have been removed from the phone.
    if (chosen != null) sounds.putIfAbsent(chosen.uri, () => chosen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownMenu<String>(
          key: const Key('soundPicker'),
          initialSelection: chosen?.uri ?? '',
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: false,
          menuHeight: 380,
          leadingIcon: Icon(_icon(chosen)),
          textStyle: Theme.of(context).textTheme.bodyLarge,
          dropdownMenuEntries: [
            for (final MapEntry(key: uri, value: sound) in sounds.entries)
              DropdownMenuEntry(
                value: uri,
                label: soundName(s, sound),
                leadingIcon: Icon(_icon(sound)),
              ),
          ],
          onSelected: (uri) {
            if (uri == null) return;
            final sound = sounds[uri];
            Device.play(sound);
            state.setAlarmSound(sound);
          },
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const Key('playSound'),
          onPressed: () => Device.play(chosen),
          icon: const Icon(Icons.play_arrow),
          label: Text(s['playSound']),
        ),
      ],
    );
  }
}
