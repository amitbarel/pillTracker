import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n.dart';
import 'models.dart';
import 'notifications.dart';
import 'screens/dose_screen.dart';
import 'screens/history_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/today_screen.dart';
import 'scope.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final state = await AppState.load();
  final reminders = Reminders(state);
  await reminders.init();
  runApp(PillApp(state: state, reminders: reminders));
}

const seed = Color(0xFF0B6B63);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    primary: seed,
    surface: const Color(0xFFF6F4EF),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    // Bigger body text: this app is read at arm's length.
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 17),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 17),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 19),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        side: const BorderSide(color: seed, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(fontSize: 17),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  );
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reminders.actions.addListener(_onReminder);
    widget.state.addListener(_onState);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
        if (widget.state.medicine(r.dose.medicineId) == null) return;
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
          content: Text(text, style: const TextStyle(fontSize: 18))));
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
    final pages = [
      const TodayScreen(),
      const MedicinesScreen(),
      const HistoryScreen(),
      const RoutineScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 76,
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
        ],
      ),
    );
  }
}
