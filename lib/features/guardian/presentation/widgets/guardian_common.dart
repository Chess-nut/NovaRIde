/// Pieces every guardian screen shares: what can honestly be said about
/// the helmet, the bottom bar, the "not linked yet" state, and the two
/// things a guardian can launch (a call, a map).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/firebase_failure_mapper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_lists.dart';
import '../../../rider/domain/entities/helmet_telemetry.dart';
import '../../../rider/presentation/providers/helmet_telemetry_provider.dart';
import '../providers/guardian_providers.dart';

// ------------------------------------------------------------- helmet view

enum GuardianHelmetPhase {
  /// No snapshot yet.
  connecting,

  /// The stream failed.
  error,

  /// Nothing at that device id: the helmet has never reported.
  missing,

  /// The helmet's node, live or stale.
  reporting,
}

/// What a guardian screen can honestly say about the helmet right now.
/// Same reading as the rider's Home.
class GuardianHelmetView {
  const GuardianHelmetView(this.phase,
      {this.telemetry, this.live = false, this.errorMessage});

  factory GuardianHelmetView.from(
      AsyncValue<HelmetTelemetry?> async, DateTime now) {
    if (async.hasError && !async.isLoading) {
      return GuardianHelmetView(GuardianHelmetPhase.error,
          errorMessage: messageFor(async.error!));
    }
    if (async.hasValue && !async.hasError) {
      final t = async.value;
      if (t == null) return const GuardianHelmetView(GuardianHelmetPhase.missing);
      return GuardianHelmetView(
        GuardianHelmetPhase.reporting,
        telemetry: t,
        live: t.online == true && t.isFresh(now, helmetStaleAfter),
      );
    }
    return const GuardianHelmetView(GuardianHelmetPhase.connecting);
  }

  final GuardianHelmetPhase phase;
  final HelmetTelemetry? telemetry;

  /// Online and wrote within `helmetStaleAfter`.
  final bool live;
  final String? errorMessage;

  /// Current speed, only while live and only with a usable fix. Null
  /// otherwise: an old speed is not the rider's speed.
  double? get speedKmph =>
      live && telemetry?.hasUsableFix == true ? telemetry?.speedKmph : null;

  /// "Cellular", "Wi‑Fi", or null.
  String? get connection {
    final ip = telemetry?.ip;
    if (ip == null) return null;
    return ip == 'cellular' ? 'Cellular' : 'Wi‑Fi';
  }

  bool get hasPosition => telemetry?.lat != null && telemetry?.lng != null;
}

// ---------------------------------------------------------------- launch

/// A Google Maps link for the helmet's position, or null without one.
String? mapLinkFor(HelmetTelemetry? t) {
  if (t == null) return null;
  final url = t.mapsUrl;
  if (url != null && url.startsWith('https://')) return url;
  final lat = t.lat, lng = t.lng;
  if (lat == null || lng == null) return null;
  return 'https://maps.google.com/?q=$lat,$lng';
}

/// Opens [url] outside the app. Shows a sentence when nothing can.
Future<void> openExternal(BuildContext context, Uri url,
    {required String failure}) async {
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure)));
  }
}

/// Opens the dialer with [phone] filled in. Does not place the call.
Future<void> callNumber(BuildContext context, String phone) => openExternal(
      context,
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')),
      failure: 'Couldn\'t open the phone app. The number is $phone.',
    );

// ------------------------------------------------------------- bottom bar

/// Home, Map, Alerts, Profile. A dot on Alerts while a crash or SOS is
/// being worked.
class GuardianBottomNavBar extends ConsumerWidget {
  const GuardianBottomNavBar({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const _paths = [
    AppRoutes.guardianHomePath,
    AppRoutes.guardianMapPath,
    AppRoutes.guardianAlertsPath,
    AppRoutes.guardianProfilePath,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final alerts = ref.watch(followedAlertsProvider).value ?? const [];
    final emergency = activeEmergencyIn(alerts) != null;

    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.map_outlined, 'Map'),
      (Icons.notifications_none, 'Alerts'),
      (Icons.person_outline, 'Profile'),
    ];

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: colors.surfaceRaised,
        indicatorColor: colors.border,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.textPrimary
                : colors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colors.textPrimary
                : colors.textSecondary,
          ),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == selectedIndex) return;
            context.go(_paths[index]);
          },
          destinations: [
            for (final (icon, label) in items)
              NavigationDestination(
                icon: label == 'Alerts' && emergency
                    ? Badge(
                        backgroundColor: colors.critical,
                        smallSize: 10,
                        label: null,
                        child: Icon(icon),
                      )
                    : Icon(icon),
                label: label,
                tooltip: label == 'Alerts' && emergency
                    ? 'Alerts, emergency in progress'
                    : label,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- not linked

/// For Map and Alerts before the guardian has connected to a rider.
class GuardianNotLinked extends StatelessWidget {
  const GuardianNotLinked({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kRiderGutter),
      child: NovaEmptyState(
        icon: Icons.link_off,
        title: 'Not connected to a rider',
        message: 'Enter the rider\'s invite code on Home to see their '
            'location and alerts here.',
        action: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: NovaPrimaryButton(
            label: 'Go to Home',
            onPressed: () => context.go(AppRoutes.guardianHomePath),
          ),
        ),
      ),
    );
  }
}
