import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/errors/firebase_failure_mapper.dart';
import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/shared/theme.dart';
import '../../domain/entities/helmet_telemetry.dart';
import '../providers/helmet_telemetry_provider.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import 'alerts_page.dart';
import 'gps_map_page.dart';
import 'notification_feed_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helmet = _HelmetView.from(
      ref.watch(helmetTelemetryProvider),
      ref.watch(helmetClockProvider).value ?? DateTime.now(),
    );

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildProfileCard(
                  context, ref.watch(authStateProvider).profile, helmet),
              const SizedBox(height: 16),
              _buildQuickStatsRow(),
              const SizedBox(height: 16),
              _buildCircleStatsRow(context, helmet),
              if (helmet.phase == _HelmetPhase.error) ...[
                const SizedBox(height: 12),
                _TelemetryErrorBanner(
                  message: helmet.errorMessage ?? '',
                  onRetry: () => ref.invalidate(helmetTelemetryProvider),
                ),
              ],
              const SizedBox(height: 24),
              // showLive is off: nothing is streaming, and a green LIVE
              // dot over three em dashes is the contradiction this pass
              // exists to remove.
              _buildSectionTitle('CURRENT TRIP'),
              const SizedBox(height: 12),
              _buildTripCard(helmet),
              const SizedBox(height: 24),
              _buildSectionTitle('EMERGENCY SOS'),
              const SizedBox(height: 20),
              _buildSosButton(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 0),
    );
  }

  // ---- Top app title + notification bell ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOVARIDE',
              style: TextStyle(
                color: NovaColors.primaryText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'SMART HELMET SYSTEM V4.2',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationFeedPage()),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.white, size: 26),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: NovaColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Rider identity, from `users/{uid}`.
  ///
  /// The name, the initials and the connection state were a hardcoded
  /// persona — "Deor the great", "Rider #NV-08567", "Connected". None of
  /// it was true of whoever was signed in.
  ///
  /// The rider number is gone rather than replaced: it belongs to the
  /// console's roster (`riders/{R-001}`), a mobile account cannot read
  /// that collection, and nothing links the two yet. The username is
  /// shown instead, which is real and is what they signed in with.
  Widget _buildProfileCard(
      BuildContext context, UserProfile? profile, _HelmetView helmet) {
    final name = profile?.displayName ?? '';
    final initials = initialsFrom(name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: NovaColors.pink,
            child: initials.isEmpty
                ? const Icon(Icons.person_outline, color: Colors.white, size: 20)
                : Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Loading…' : name,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile == null ? '' : '@${profile.username}',
                  style: const TextStyle(
                      color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          // "Connected" only while the helmet says it is online and its
          // last write is recent: the firmware never writes online:false,
          // so a helmet that has gone quiet still says true.
          switch (helmet.phase) {
            _HelmetPhase.connecting => const _StatusPill(
                label: 'Connecting…', color: NovaColors.secondaryText),
            _HelmetPhase.error =>
              const _StatusPill(label: 'Error', color: NovaColors.red),
            _HelmetPhase.missing => const _StatusPill(
                label: 'No helmet', color: NovaColors.secondaryText),
            _HelmetPhase.reporting when helmet.live => const _StatusPill(
                label: 'Connected', color: NovaColors.green),
            _HelmetPhase.reporting => const _StatusPill(
                label: 'Offline', color: NovaColors.amber),
          },
        ],
      ),
    );
  }
  // ---- Battery / Hardware / Signal row ----
  //
  // 78%, ESP32 and -62 dBm were invented. The firmware sends no battery
  // level, and its rssi is a hard-coded 0 on cellular. Em dashes until
  // there is a real feed.
  Widget _buildQuickStatsRow() {
    return Row(
      children: const [
        Expanded(
          child: _InfoCard(
            value: Unavailable.dash,
            valueColor: NovaColors.secondaryText,
            label: 'BATTERY',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            value: Unavailable.dash,
            valueColor: NovaColors.secondaryText,
            label: 'HARDWARE',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            value: Unavailable.dash,
            valueColor: NovaColors.secondaryText,
            label: 'SIGNAL',
          ),
        ),
      ],
    );
  }

  // ---- Impact / Air quality / GPS row ----
  Widget _buildCircleStatsRow(BuildContext context, _HelmetView helmet) {
    final t = helmet.telemetry;
    final impact = t?.impactG;
    final alcohol = t?.alcoholRelativeIndex;
    final (impactStatus, impactColor) = helmet.statusFor(impact != null);
    final (alcoholStatus, alcoholColor) = helmet.alcoholStatus();
    final (gpsStatus, gpsColor) = helmet.gpsStatus();

    return Row(
      children: [
        Expanded(
          child: _CircleStatCard(
            icon: Icons.bolt,
            iconColor: NovaColors.green,
            value: impact == null
                ? Unavailable.dash
                : '${impact.toStringAsFixed(2)} g',
            label: 'IMPACT',
            statusText: impactStatus,
            statusColor: impactColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CircleStatCard(
            icon: Icons.water_drop_outlined,
            iconColor: NovaColors.secondaryText,
            value: alcohol == null
                ? Unavailable.dash
                : alcohol.toStringAsFixed(0),
            // The MQ-3's raw ADC count: a relative index, not a percentage
            // and not a breath concentration, so there is no unit and the
            // label says raw.
            label: 'RAW ALCOHOL INDEX',
            statusText: alcoholStatus,
            statusColor: alcoholColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CircleStatCard(
            icon: Icons.location_on_outlined,
            iconColor: NovaColors.cyan,
            value: 'GPS',
            label: 'LOCATION',
            statusText: gpsStatus,
            statusColor: gpsColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GpsMapPage()),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Section header, optionally with a "LIVE" indicator ----
  Widget _buildSectionTitle(String title, {bool showLive = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        if (showLive)
          Row(
            children: const [
              Icon(Icons.circle, color: NovaColors.green, size: 8),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  color: NovaColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---- Trip speed / distance / duration + route ----
  //
  // 42 km/h, 8.3 km, 23:47 and "Makati Ave → Bonifacio Global City"
  // were a scripted demo trip. Trips are not recorded anywhere yet —
  // there is no trips collection to build distance or duration from.
  // Speed is the helmet's own, and only while it is live: this tile has
  // no status line to mark a stale figure as stale.
  Widget _buildTripCard(_HelmetView helmet) {
    final speed = helmet.live ? helmet.telemetry?.speedKmph : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _TripMetric(
                    value: speed == null
                        ? Unavailable.dash
                        : speed.toStringAsFixed(1),
                    unit: 'km/h',
                    label: 'SPEED'),
              ),
              const Expanded(
                child: _TripMetric(
                    value: Unavailable.dash, unit: 'km', label: 'DISTANCE'),
              ),
              const Expanded(
                child: _TripMetric(
                    value: Unavailable.dash, unit: 'min', label: 'DURATION'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.location_on, color: NovaColors.secondaryText, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No trip in progress',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Big glowing SOS button ----
  Widget _buildSosButton(BuildContext context) {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: NovaColors.red.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Material(
          color: NovaColors.red,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertsPage()),
              );
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 30),
                SizedBox(height: 6),
                Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three things the helmet stream can be, plus the one that is not
/// an answer yet. Each renders differently, and none renders as a number.
enum _HelmetPhase {
  /// No snapshot yet.
  connecting,

  /// The stream failed; the banner says why and offers Retry.
  error,

  /// The snapshot arrived and there is nothing at that device id.
  missing,

  /// The helmet's node, live or stale. Its fields may still be absent.
  reporting,
}

/// What the home screen can honestly say about the helmet right now.
class _HelmetView {
  const _HelmetView(this.phase,
      {this.telemetry, this.live = false, this.errorMessage});

  factory _HelmetView.from(AsyncValue<HelmetTelemetry?> async, DateTime now) {
    // A retry after an error keeps the old error while it loads; show that
    // as connecting rather than as the failure it is recovering from.
    if (async.hasError && !async.isLoading) {
      return _HelmetView(_HelmetPhase.error,
          errorMessage: messageFor(async.error!));
    }
    if (async.hasValue && !async.hasError) {
      final telemetry = async.value;
      if (telemetry == null) return const _HelmetView(_HelmetPhase.missing);
      return _HelmetView(
        _HelmetPhase.reporting,
        telemetry: telemetry,
        live: telemetry.online == true &&
            telemetry.isFresh(now, helmetStaleAfter),
      );
    }
    return const _HelmetView(_HelmetPhase.connecting);
  }

  final _HelmetPhase phase;
  final HelmetTelemetry? telemetry;

  /// Says it is online, and wrote within [helmetStaleAfter]. A missing
  /// `online` or `lastSeen` is not live: there is no telling.
  final bool live;
  final String? errorMessage;

  /// The status line under a circle tile whose reading is [present].
  (String, Color) statusFor(bool present) => switch (phase) {
        _HelmetPhase.connecting => ('CONNECTING…', NovaColors.secondaryText),
        _HelmetPhase.error => ('ERROR', NovaColors.red),
        _HelmetPhase.missing => ('NO HELMET', NovaColors.secondaryText),
        _HelmetPhase.reporting when !present =>
          ('NO READING', NovaColors.secondaryText),
        _HelmetPhase.reporting when live => ('LIVE', NovaColors.green),
        _HelmetPhase.reporting => ('STALE', NovaColors.amber),
      };

  /// The alcohol tile's status line carries the helmet's own threshold
  /// verdict, while it is live. No verdict sent is plain LIVE, not "clear".
  (String, Color) alcoholStatus() {
    final t = telemetry;
    final present = t?.alcoholRelativeIndex != null;
    if (live && present && t!.alcoholAlert == true) {
      return ('ALERT', NovaColors.red);
    }
    return statusFor(present);
  }

  /// The location tile's status line is the fix itself, while it is live.
  (String, Color) gpsStatus() {
    final fix = telemetry?.hasUsableFix;
    if (fix == null || !live) return statusFor(fix != null);
    return fix ? ('FIX', NovaColors.green) : ('NO FIX', NovaColors.amber);
  }
}

/// Why the helmet stream failed, with a way back that does not need the
/// app restarted.
class _TelemetryErrorBanner extends StatelessWidget {
  const _TelemetryErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: NovaColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: NovaColors.primaryText, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Small rounded status badge shown on the profile card.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Battery / Hardware / Signal card.
class _InfoCard extends StatelessWidget {
  final String value;
  final Color valueColor;
  final String label;

  const _InfoCard({
    required this.value,
    required this.valueColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Impact / Alcohol / GPS card with an icon circle and status dot.
class _CircleStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;

  const _CircleStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.statusText,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: statusColor, size: 6),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One metric (speed / distance / duration) inside the trip card.
class _TripMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _TripMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
