/// Which theme the app is showing.
///
/// Wired through [MaterialApp] from the start even though only the dark
/// palette exists, so that adding a light one is a change to
/// `core/theme/` and nothing else. Without this, switching later means
/// touching `app.dart`, threading a provider through, and re-testing the
/// root — small, but exactly the kind of restructuring the Phase 2 brief
/// asked to avoid.
///
/// Fixed at [ThemeMode.dark] on purpose. It is not read from the platform
/// and not persisted: following the system would mean a rider's phone in
/// light mode silently picks a theme that does not exist yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  /// Here for the day a light palette lands, and for a test that wants to
  /// prove the wiring works. Setting [ThemeMode.light] today shows the
  /// dark theme, because that is what `app.dart` passes for both.
  void set(ThemeMode mode) => state = mode;
}
