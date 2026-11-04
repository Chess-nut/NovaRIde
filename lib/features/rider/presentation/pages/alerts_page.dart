import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/utils/coordinates.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';
import 'package:novaride/shared/models/models.dart' show kCrashCountdown;

import '../providers/helmet_telemetry_provider.dart';
import '../providers/rider_alerts_provider.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import '../widgets/rider_alert_tile.dart';
import 'gps_map_page.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';

/// "Alerts" — what happens in an emergency, where you are, who is told,
/// and the alerts you have had. The Alerts tab, and where the Home SOS
/// button leads.
///
/// Every line is now something true. It used to show "EDSA, Quezon
/// City" at ±5.2 m as the current location, and two of the developers
/// as the contacts to be notified. Now:
///
/// - the steps describe what the firmware and the crash countdown do;
/// - the location is the helmet's last fix, or says there is none;
/// - "who is told" names the real channels — the number set on the
///   helmet, and the operations console;
/// - recent alerts are `alerts/` for this rider, or an empty state.
class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NovaScreenHeader(
                title: 'Alerts',
                subtitle: 'What happens when something goes wrong',
                showBack: false,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kRiderGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    const _EmergencyCard(),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Recent alerts'),
                    const SizedBox(height: AppSpacing.md),
                    const _RecentAlerts(),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Your location now'),
                    const SizedBox(height: AppSpacing.md),
                    _LocationCard(onOpenMap: () => open(const GpsMapPage())),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Who is told'),
                    const SizedBox(height: AppSpacing.md),
                    NovaListGroup(
                      children: [
                        NovaListRow(
                          icon: Icons.sms_outlined,
                          title: 'The helmet\'s emergency number',
                          subtitle:
                              'Texted by the helmet. Set on its setup page.',
                          onTap: () => open(const HelmetSettingsPage()),
                        ),
                        const NovaListRow(
                          icon: Icons.support_agent,
                          title: 'NovaRide operations',
                          subtitle:
                              'The console sees the alert and your location.',
                        ),
                        NovaListRow(
                          icon: Icons.contact_phone_outlined,
                          title: 'Your emergency contacts',
                          subtitle: 'Kept in the app. Not sent alerts yet.',
                          onTap: () => open(const EmergencyContactsPage()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 2),
    );
  }
}

/// What an emergency sets in motion, in order.
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final seconds = kCrashCountdown.inSeconds;
    final steps = [
      (
        Icons.car_crash,
        'Crash detected',
        'You get $seconds seconds to cancel a false alarm.',
      ),
      (
        Icons.sms_outlined,
        'Help is texted',
        'The helmet sends its emergency number a map link to where you are.',
      ),
      (
        Icons.support_agent,
        'Operations alerted',
        'The NovaRide console sees the alert and can send responders.',
      ),
      (
        Icons.my_location,
        'Location keeps updating',
        'About every 30 seconds while the helmet is online.',
      ),
    ];

    return NovaCard(
      tone: NovaTone.critical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sos, color: colors.critical, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'In an emergency',
                  style: context.text.h2.copyWith(color: colors.critical),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(steps[i].$1, size: 20, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$2, style: context.text.title),
                      const SizedBox(height: 2),
                      Text(steps[i].$3, style: context.text.body),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// This rider's latest alerts from `alerts/`, or why there are none.
class _RecentAlerts extends ConsumerWidget {
  const _RecentAlerts();

  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(linkedRiderProvider).value;
    final alertsAsync = ref.watch(riderAlertsProvider);

    if (alertsAsync.hasError) {
      return const NovaNote(
        tone: NovaTone.critical,
        icon: Icons.error_outline,
        text:
            'Couldn\'t load your alerts. They\'ll appear here once the '
            'connection is back.',
      );
    }

    final alerts = alertsAsync.value ?? const [];
    if (alerts.isEmpty) {
      return NovaEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'No alerts',
        message: linked == null
            ? 'Alerts appear here once operations links your account to '
                  'your helmet.'
            : 'Nothing has happened. Alerts the helmet raises appear here.',
      );
    }

    return NovaListGroup(
      children: [
        for (final alert in alerts.take(_shown)) RiderAlertRow(alert: alert),
      ],
    );
  }
}

/// The helmet's last GPS fix, or why there is none.
class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(helmetTelemetryProvider).value;
    final lat = t?.lat;
    final lng = t?.lng;
    final fix = t?.hasUsableFix;

    if (lat == null || lng == null) {
      return NovaEmptyState(
        icon: Icons.location_off_outlined,
        title: 'No location yet',
        message: 'The helmet needs a GPS fix. Its antenna has to see the sky.',
        action: TextButton(onPressed: onOpenMap, child: const Text('Open map')),
      );
    }

    final takenAt = fixTakenAt(t?.lastSeen, t?.gpsAgeMs);
    return NovaCard(
      onTap: onOpenMap,
      semanticLabel: 'Your location. Open map.',
      child: Column(
        children: [
          NovaValueRow(label: 'Latitude', value: formatLatitude(lat)),
          NovaValueRow(label: 'Longitude', value: formatLongitude(lng)),
          NovaValueRow(
            label: 'Fix',
            value: switch (fix) {
              true =>
                t?.satellites == null
                    ? 'Current'
                    : 'Current · ${t!.satellites} satellites',
              false => 'Old — last known position',
              null => '—',
            },
          ),
          if (takenAt != null)
            NovaValueRow(label: 'Fix taken', value: novaTimeAgo(takenAt)),
        ],
      ),
    );
  }
}
