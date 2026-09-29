import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
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
    return MaterialApp.router(
      title: 'NovaRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
