import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/utils/coordinates.dart';
import 'package:novaride/core/widgets/nova_lists.dart' show novaTimeAgo;
import 'package:novaride/core/widgets/nova_surfaces.dart' show NovaTone;
import 'package:novaride/shared/models/models.dart' show kCrashCountdown;
import 'package:novaride/shared/theme.dart';

import '../../domain/entities/rider_alert.dart';
import '../providers/helmet_telemetry_provider.dart';
import '../providers/rider_alerts_provider.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import '../widgets/rider_alert_tile.dart';
import 'gps_map_page.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';

/// "Alerts", in the original NovaRide look: the red Emergency Alert System
/// banner, What Will Happen, the rider's recent alerts, Current Location,
/// and Who Is Told. The Alerts tab, and where Home's SOS button leads.
///
/// The old screen's content was not true, so only its look came back:
///
/// * the banner and the steps describe what the firmware and the crash
///   countdown actually do — there is no SMS to "all your emergency
///   contacts" and nothing notifies "nearby TNVS services";
/// * the location is the helmet's real last fix, or says there is none
///   (it was "EDSA, Quezon City" at ±5.2 m, typed into the code);
/// * "Contacts to be Notified" — four of the developers as "sibling",
///   each with a green tick — is gone. Who Is Told names the real
///   channels instead, and links to where each one is set.
class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  static const _purple = Color(0xFF9B6BFF);
  static const _orange = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EmergencyBanner(),
              const SizedBox(height: 24),
              const _SectionTitle('What Will Happen'),
              const SizedBox(height: 12),
              const _WhatWillHappenCard(),
              const SizedBox(height: 24),
              const _SectionTitle('Recent Alerts'),
              const SizedBox(height: 12),
              const _RecentAlertsCard(),
              const SizedBox(height: 24),
              const _SectionTitle('Current Location'),
              const SizedBox(height: 12),
              _LocationCard(onOpenMap: () => open(const GpsMapPage())),
              const SizedBox(height: 24),
              const _SectionTitle('Who Is Told'),
              const SizedBox(height: 12),
              _Card(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    _WhoTile(
                      icon: Icons.sms_outlined,
                      iconColor: NovaColors.cyan,
                      title: 'The helmet\'s emergency number',
                      subtitle: 'Texted by the helmet. Set on its setup page.',
                      onTap: () => open(const HelmetSettingsPage()),
                    ),
                    const _WhoTile(
                      icon: Icons.support_agent,
                      iconColor: NovaColors.green,
                      title: 'NovaRide operations',
                      subtitle: 'The console sees the alert and your location.',
                    ),
                    _WhoTile(
                      icon: Icons.contact_phone_outlined,
                      iconColor: _purple,
                      title: 'Your emergency contacts',
                      subtitle:
                          'Your guardians see the alert in their app. Phone '
                          'contacts are for operations to call.',
                      onTap: () => open(const EmergencyContactsPage()),
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

// ---------------------------------------------------------------------------
// Banner and steps
// ---------------------------------------------------------------------------

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner();

  @override
  Widget build(BuildContext context) {
    final seconds = kCrashCountdown.inSeconds;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovaColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NovaColors.red.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: NovaColors.red,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: const Text(
              'Emergency Alert System',
              style: TextStyle(
                color: NovaColors.red,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When your helmet detects a crash, it texts its emergency number '
            'a map link to where you are and alerts the NovaRide console. '
            'You get $seconds seconds to cancel a false alarm first.',
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatWillHappenCard extends StatelessWidget {
  const _WhatWillHappenCard();

  @override
  Widget build(BuildContext context) {
    final seconds = kCrashCountdown.inSeconds;
    return _Card(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _StepTile(
            icon: Icons.car_crash_outlined,
            iconColor: NovaColors.red,
            title: 'Crash Detected',
            subtitle: 'You get $seconds seconds to cancel a false alarm.',
          ),
          const _StepTile(
            icon: Icons.sms_outlined,
            iconColor: NovaColors.cyan,
            title: 'Help Is Texted',
            subtitle:
                'The helmet sends its emergency number a map link to where '
                'you are.',
          ),
          const _StepTile(
            icon: Icons.support_agent,
            iconColor: NovaColors.green,
            title: 'Operations Alerted',
            subtitle:
                'The NovaRide console sees the alert and can send responders.',
          ),
          const _StepTile(
            icon: Icons.radar,
            iconColor: AlertsPage._orange,
            title: 'Location Keeps Updating',
            subtitle: 'About every 30 seconds while the helmet is online.',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent alerts
// ---------------------------------------------------------------------------

/// This rider's latest alerts from `alerts/`, or why there are none.
class _RecentAlertsCard extends ConsumerWidget {
  const _RecentAlertsCard();

  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(linkedRiderProvider).value;
    final alertsAsync = ref.watch(riderAlertsProvider);
    final alerts = alertsAsync.value ?? const <RiderAlert>[];

    if (alertsAsync.hasError) {
      return const _Notice(
        icon: Icons.error_outline,
        color: NovaColors.red,
        text:
            'Couldn\'t load your alerts. They\'ll appear here once the '
            'connection is back.',
      );
    }
    if (alerts.isEmpty) {
      return _Notice(
        icon: Icons.verified_user_outlined,
        color: NovaColors.green,
        text: linked == null
            ? 'Alerts appear here once operations links your account to '
                  'your helmet.'
            : 'No alerts. Nothing has happened.',
      );
    }

    return _Card(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final alert in alerts.take(_shown)) _AlertTile(alert: alert),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final RiderAlert alert;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = alertTypeLabel(alert.type);
    final (status, tone) = alertStatusLabel(alert);
    final statusColor = _toneColor(tone);
    final iconColor = alert.isCritical ? NovaColors.red : AlertsPage._orange;
    final when = alert.timestamp;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            _IconCircle(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (when != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      novaTimeAgo(when),
                      style: const TextStyle(
                        color: NovaColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _toneColor(NovaTone tone) => switch (tone) {
    NovaTone.safe => NovaColors.green,
    NovaTone.warning => NovaColors.amber,
    NovaTone.critical => NovaColors.red,
    _ => NovaColors.secondaryText,
  };
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

/// The helmet's last real GPS fix, or why there is none.
class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(helmetTelemetryProvider).value;
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final lat = t?.lat;
    final lng = t?.lng;

    if (t == null || lat == null || lng == null) {
      return _Notice(
        icon: Icons.location_off_outlined,
        color: NovaColors.secondaryText,
        text: 'No location yet. The helmet needs a GPS fix — its antenna has '
            'to see the sky.',
        onTap: onOpenMap,
      );
    }

    // "Current" only for a fix from the last couple of minutes. A real
    // position from a week ago is a last known one, said as such.
    final current = t.hasCurrentFix(now);
    final takenAt = t.positionAt;

    return Semantics(
      button: true,
      label: 'Current location. Opens the map.',
      child: _Card(
        onTap: onOpenMap,
        child: Column(
          children: [
            _LocationRow(label: 'Latitude', value: formatLatitude(lat)),
            const SizedBox(height: 12),
            _LocationRow(label: 'Longitude', value: formatLongitude(lng)),
            const SizedBox(height: 12),
            _LocationRow(
              label: 'Fix',
              value: current
                  ? (t.satellites == null
                        ? 'Current'
                        : 'Current · ${t.satellites} satellites')
                  : 'Last known',
              valueColor: current ? NovaColors.green : NovaColors.amber,
            ),
            if (takenAt != null) ...[
              const SizedBox(height: 12),
              _LocationRow(label: 'Fix taken', value: novaTimeAgo(takenAt, now)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? NovaColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(
          color: NovaColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The old screen's card: dark, rounded, hairline border.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: child,
    );
    final tap = onTap;
    if (tap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: tap,
        child: box,
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

/// One step in What Will Happen.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconCircle(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in Who Is Told. Tappable rows open where that channel is set.
class _WhoTile extends StatelessWidget {
  const _WhoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _IconCircle(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: NovaColors.secondaryText,
              size: 20,
            ),
          ],
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return MergeSemantics(child: row);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: tap,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// A one-line card for "nothing here", with the reason.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          _IconCircle(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
