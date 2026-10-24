import 'package:flutter/widgets.dart';

import 'notifications.dart';
import 'store.dart';

/// Gives every screen the app state and the reminders, and rebuilds them
/// when the state changes.
class Scope extends InheritedNotifier<AppState> {
  const Scope({
    super.key,
    required AppState state,
    required this.reminders,
    required super.child,
  }) : super(notifier: state);

  final Reminders reminders;

  AppState get state => notifier!;

  static Scope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Scope>()!;

  /// Without subscribing to changes, for use in callbacks.
  static Scope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Scope>()!;
}
