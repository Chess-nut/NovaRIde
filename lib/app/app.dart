import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import 'router.dart';

/// The mobile app widget.
///
/// A [ConsumerWidget] so it can read [routerProvider]; it must be built
/// under a [ProviderScope], which `main.dart` supplies. A test that pumps
/// this directly needs its own scope, and that is the seam for overriding
/// the session — see `test/support/mobile_app.dart`.
class NovaRideApp extends ConsumerWidget {
  const NovaRideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both slots are built from the dark palette. Only one palette exists,
    // and pointing `theme` at a light one that does not would mean a
    // themeMode change produced an unstyled screen rather than a
    // deliberate result. When AppColors.light lands, this line becomes
    // `AppTheme.from(AppColors.light, brightness: Brightness.light)` and
    // nothing else in the app changes.
    final dark = AppTheme.from(AppColors.dark);

    return MaterialApp.router(
      title: 'NovaRide',
      debugShowCheckedModeBanner: false,
      theme: dark,
      darkTheme: dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
