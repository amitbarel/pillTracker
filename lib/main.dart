import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'device.dart';
import 'l10n.dart';
import 'models.dart';
import 'notifications.dart';
import 'screens/common.dart';
import 'screens/dose_screen.dart';
import 'screens/history_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'screens/welcome_screen.dart';
import 'scope.dart';
import 'store.dart';
import 'theme.dart';
import 'whats_new.dart';

export 'theme.dart' show buildTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final state = await AppState.load();
  final reminders = Reminders(state);
  await reminders.init();
  runApp(PillApp(state: state, reminders: reminders));
}

class PillApp extends StatefulWidget {
  const PillApp({super.key, required this.state, required this.reminders});

  final AppState state;
  final Reminders reminders;

  @override
  State<PillApp> createState() => _PillAppState();
}

class _PillAppState extends State<PillApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// The "Hello" screen, shown on opening when a name is set. An alarm that
  /// opened the app goes straight to the medicine instead.
  late bool _welcome =
      widget.state.userName.isNotEmpty && widget.reminders.actions.value == null;

  /// Set when an alarm opened the app: no greeting or news over it.
  bool _openedByAlarm = false;

  void _endWelcome() {
    if (!_welcome || !mounted) return;
    setState(() => _welcome = false);
    _showWhatsNew();
  }

  /// Tells about a new version once. A fresh install has nothing to compare
  /// with, so it starts from the current version silently.
  Future<void> _showWhatsNew() async {
    final state = widget.state;
    final release = currentRelease;
    if (_openedByAlarm || (state.seenRelease ?? 0) >= release.number) return;
    final fresh = state.seenRelease == null && state.medicines.isEmpty;
    await state.setSeenRelease(release.number);
    final context = _navigator.currentContext;
    if (fresh || context == null || !context.mounted) return;
    await showWhatsNew(context, release);
  }

  @override
  void initState() {
    super.initState();
    if (_welcome) Timer(const Duration(milliseconds: 2200), _endWelcome);
    WidgetsBinding.instance.addObserver(this);
    widget.reminders.actions.addListener(_onReminder);
    widget.state.addListener(_onState);
    _openedByAlarm = widget.reminders.actions.value != null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_welcome) _showWhatsNew();
      await widget.reminders.requestPermissions();
      await widget.reminders.reschedule();
      // An alarm may have opened the app before the first frame.
      _onReminder();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.reminders.actions.removeListener(_onReminder);
    widget.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      widget.reminders.reschedule();
      setState(() {});
    }
  }

  S get _s => S.forCode(_locale?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode);

  Locale? get _locale {
    final code = widget.state.languageCode;
    return code == null ? null : Locale(code);
  }

  Future<void> _onReminder() async {
    final r = widget.reminders.actions.value;
    final nav = _navigator.currentState;
    if (r == null || nav == null) return;
    widget.reminders.clearAction();
    _openedByAlarm = true;
    _endWelcome();
    final s = _s;
    switch (r.action) {
      case Reminders.taken:
        await widget.reminders.dismiss(r.dose);
        await widget.state.record(r.dose, IntakeStatus.taken);
        _toast(s['markedTaken']);
      case Reminders.skip:
        await widget.reminders.dismiss(r.dose);
        await widget.state.record(r.dose, IntakeStatus.skipped);
        _toast(s['markedSkipped']);
      case Reminders.snooze:
        await widget.reminders.dismiss(r.dose);
        await widget.reminders.snoozeDose(r.dose);
        _toast(s['snoozed']);
      default:
        if (widget.state.medicine(r.dose.medicineId) == null) {
          await Device.alarmClosed();
          return;
        }
        nav.push(MaterialPageRoute<void>(
          builder: (_) => DoseScreen(dose: r.dose),
          fullscreenDialog: true,
        ));
    }
  }

  void _toast(String text) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scope(
      state: widget.state,
      reminders: widget.reminders,
      child: MaterialApp(
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        onGenerateTitle: (context) => S.of(context)['appTitle'],
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: _locale,
        supportedLocales: S.supported,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        localeResolutionCallback: (locale, supported) {
          final code = locale?.languageCode;
          // Older Android reports Hebrew as "iw".
          if (code == 'he' || code == 'iw') return const Locale('he');
          return const Locale('en');
        },
        builder: (context, child) => TextSizeLimit(
          child: Stack(fit: StackFit.expand, children: [
            child!,
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _welcome
                  ? WelcomeScreen(name: widget.state.userName, onDone: _endWelcome)
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps "now", "due" and "missed" current while the app stays open.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const pages = [
      TodayScreen(),
      MedicinesScreen(),
      HistoryScreen(),
      RoutineScreen(),
      SettingsScreen(),
    ];
    // Back on another tab returns to Today instead of leaving the app.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              selectedIcon: const Icon(Icons.today),
              label: s['today']),
          NavigationDestination(
              icon: const Icon(Icons.medication_outlined),
              selectedIcon: const Icon(Icons.medication),
              label: s['medicines']),
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: s['history']),
          NavigationDestination(
              icon: const Icon(Icons.wb_sunny_outlined),
              selectedIcon: const Icon(Icons.wb_sunny),
              label: s['myDay']),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s['settings']),
        ],
      ),
      ),
    );
  }
}
