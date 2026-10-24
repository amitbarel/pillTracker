import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// The app's colours beyond the Material scheme. Widgets read these through
/// `AppColors.of(context)` instead of hard-coding values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ink,
    required this.muted,
    required this.line,
    required this.track,
    required this.accentTint,
    required this.warn,
    required this.warnTint,
    required this.alarm,
    required this.onAlarm,
    required this.onAlarmMuted,
  });

  /// Main text.
  final Color ink;

  /// Secondary text; still 4.5:1 on white and on the page.
  final Color muted;

  /// Borders of unselected chips, inputs and time buttons.
  final Color line;

  /// Empty part of progress bars.
  final Color track;

  /// Light teal behind selected chips, badges and weekend times.
  final Color accentTint;

  /// Missed doses and destructive actions.
  final Color warn;
  final Color warnTint;

  /// The full-screen alarm.
  final Color alarm;
  final Color onAlarm;
  final Color onAlarmMuted;

  static const light = AppColors(
    ink: Color(0xFF1B1F1E),
    muted: Color(0xFF5B6461),
    line: Color(0xFFCFCAC0),
    track: Color(0xFFE2DED6),
    accentTint: Color(0xFFE3F1EF),
    warn: Color(0xFFB4480E),
    warnTint: Color(0xFFFCEBDD),
    alarm: Color(0xFF0B3D39),
    onAlarm: Color(0xFFFFFFFF),
    onAlarmMuted: Color(0xB3FFFFFF),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? ink,
    Color? muted,
    Color? line,
    Color? track,
    Color? accentTint,
    Color? warn,
    Color? warnTint,
    Color? alarm,
    Color? onAlarm,
    Color? onAlarmMuted,
  }) =>
      AppColors(
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        track: track ?? this.track,
        accentTint: accentTint ?? this.accentTint,
        warn: warn ?? this.warn,
        warnTint: warnTint ?? this.warnTint,
        alarm: alarm ?? this.alarm,
        onAlarm: onAlarm ?? this.onAlarm,
        onAlarmMuted: onAlarmMuted ?? this.onAlarmMuted,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      track: Color.lerp(track, other.track, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnTint: Color.lerp(warnTint, other.warnTint, t)!,
      alarm: Color.lerp(alarm, other.alarm, t)!,
      onAlarm: Color.lerp(onAlarm, other.onAlarm, t)!,
      onAlarmMuted: Color.lerp(onAlarmMuted, other.onAlarmMuted, t)!,
    );
  }
}

const _font = 'Rubik';
const _seed = Color(0xFF0B6B63);

/// Text sizes are large on purpose: the app is read at arm's length by
/// someone who may not have their glasses on. Widgets use these slots:
///
/// * headlineMedium: page titles
/// * displayLarge: the alarm's clock
/// * titleLarge: the medicine name on the alarm and focus card
/// * titleMedium: medicine names in lists, section titles
/// * bodyLarge: normal text
/// * bodyMedium: secondary lines (dose, timing)
/// * labelLarge: buttons and short status labels
ThemeData buildTheme() {
  const c = AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    primary: _seed,
    surface: const Color(0xFFF6F4EF),
    onSurface: c.ink,
    error: c.warn,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: _font);
  final t = base.textTheme;
  final text = t.copyWith(
    displayLarge: t.displayLarge?.copyWith(fontSize: 72, fontWeight: FontWeight.w700, height: 1.1),
    headlineMedium: t.headlineMedium?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, color: c.ink),
    titleLarge: t.titleLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
    titleMedium: t.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink),
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 18, color: c.ink),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 16, color: c.muted),
    labelLarge: t.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
  );
  final button = text.labelLarge!.copyWith(fontSize: 19);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    extensions: const [AppColors.light],
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: button,
        side: const BorderSide(color: _seed, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.ink,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedTextStyle: button.copyWith(fontSize: 18),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: c.accentTint,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelLarge!.copyWith(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? _seed : c.muted,
        );
      }),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: text.bodyLarge!.copyWith(fontSize: 17),
      side: BorderSide(color: c.line),
      selectedColor: c.accentTint,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: text.bodyLarge!.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    // Slide-and-fade between screens on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
