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

/// The rider's home, in the original NovaRide look: the NOVARIDE header,
/// the rider card with the helmet's status, three sensor tiles, the
/// current speed, and the big SOS button.
///
/// Kept from the redesign, because they are true and the old screen did
/// not have them:
///
/// * the helmet's state — Connecting, Connected, Offline, Alcohol
///   detected, No helmet, Error — on the rider card, with a banner under
///   it whenever the rider has to know or do something;
/// * the sensors read from every node the helmet writes (see
///   rtdb_helmet_nodes.dart), the location tile saying whether its fix is
///   current or a last known one;
/// * speed only while the helmet is live and its fix is current.
///
/// Gone from the old screen: the Battery, Hardware and Signal tiles (the
/// helmet sends no battery level and a hard-coded signal on cellular, so
/// they could only ever be dashes), the trip's distance and duration
/// (nothing records a trip), the version number, and the bell's red dot
/// (nothing counts unread notifications, so it never went away).
///
/// Nothing is smaller than 12px: the old screen went down to 9px, which a
/// rider cannot read off a phone on a handlebar mount.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final helmet = _HelmetView.from(ref.watch(helmetTelemetryProvider), now);
    final banner = helmet.banner(now);

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 20),
              _RiderCard(
                profile: ref.watch(authStateProvider).profile,
                helmet: helmet,
              ),
              if (banner != null) ...[
                const SizedBox(height: 12),
                _StatusBanner(
                  banner: banner,
                  onRetry: helmet.phase == _HelmetPhase.error
                      ? () => ref.invalidate(helmetTelemetryProvider)
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              _SensorRow(helmet: helmet),
              const SizedBox(height: 24),
              const _SectionTitle('CURRENT SPEED'),
              const SizedBox(height: 12),
              _SpeedCard(helmet: helmet),
              const SizedBox(height: 24),
              const _SectionTitle('EMERGENCY SOS'),
              const SizedBox(height: 20),
              _SosButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AlertsPage())),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 0),
    );
  }
}

// ---------------------------------------------------------------------------
// What the screen can honestly say
// ---------------------------------------------------------------------------

/// The three things the helmet stream can be, plus the one that is not an
/// answer yet. Each renders differently, and none renders as a number.
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

/// A sentence under the rider card, and how loud it is.
typedef _Banner = ({String text, Color color});

/// What the home screen can honestly say about the helmet right now.
class _HelmetView {
  const _HelmetView(
    this.phase, {
    this.telemetry,
    this.live = false,
    this.errorMessage,
    this.now,
  });

  factory _HelmetView.from(AsyncValue<HelmetTelemetry?> async, DateTime now) {
    // A retry after an error keeps the old error while it loads; show that
    // as connecting rather than as the failure it is recovering from.
    if (async.hasError && !async.isLoading) {
      return _HelmetView(
        _HelmetPhase.error,
        errorMessage: messageFor(async.error!),
      );
    }
    if (async.hasValue && !async.hasError) {
      final telemetry = async.value;
      if (telemetry == null) return const _HelmetView(_HelmetPhase.missing);
      return _HelmetView(
        _HelmetPhase.reporting,
        telemetry: telemetry,
        now: now,
        live:
            telemetry.online == true &&
            telemetry.isFresh(now, helmetStaleAfter),
      );
    }
    return const _HelmetView(_HelmetPhase.connecting);
  }

  final _HelmetPhase phase;
  final HelmetTelemetry? telemetry;

  /// Says it is online, and wrote within [helmetStaleAfter]. A missing
  /// `online` or `lastSeen` is not live: there is no telling. (The
  /// firmware never writes `online: false`, so a helmet that went quiet
  /// still says true; freshness is what decides.)
  final bool live;
  final String? errorMessage;

  /// The clock this view was read at. Null outside [_HelmetPhase.reporting].
  final DateTime? now;

  /// Live, and the helmet's own threshold says the rider has been
  /// drinking. The one state that turns the rider card red.
  bool get alcoholAlert => live && telemetry?.alcoholAlert == true;

  /// The helmet's speed, only while it is live and its fix is current.
  double? get currentSpeedKmph {
    final at = now;
    return live && at != null ? telemetry?.currentSpeedKmph(at) : null;
  }

  /// The pill on the rider card.
  (String, Color) get pill => switch (phase) {
    _HelmetPhase.connecting => ('Connecting…', NovaColors.secondaryText),
    _HelmetPhase.error => ('Error', NovaColors.red),
    _HelmetPhase.missing => ('No helmet', NovaColors.secondaryText),
    _HelmetPhase.reporting when alcoholAlert => (
      'Alcohol detected',
      NovaColors.red,
    ),
    _HelmetPhase.reporting when live => ('Connected', NovaColors.green),
    _HelmetPhase.reporting => ('Offline', NovaColors.amber),
  };

  /// The sentence under the rider card, when there is something to say.
  /// Nothing while the helmet is simply connected: the pill says that.
  _Banner? banner(DateTime now) {
    final lastSeen = telemetry?.lastSeen;
    return switch (phase) {
      _HelmetPhase.connecting => null,
      _HelmetPhase.error => (
        text: errorMessage ?? 'Can\'t reach helmet data.',
        color: NovaColors.red,
      ),
      _HelmetPhase.missing => (
        text: 'No helmet has reported yet. Turn it on and check its Wi‑Fi.',
        color: NovaColors.secondaryText,
      ),
      _HelmetPhase.reporting when alcoholAlert => (
        text: 'Alcohol detected. Please don\'t ride — the helmet\'s reading '
            'is above its threshold.',
        color: NovaColors.red,
      ),
      _HelmetPhase.reporting when live => null,
      _HelmetPhase.reporting => (
        text: lastSeen == null
            ? 'Helmet offline. The readings below are the last ones it sent.'
            : 'Helmet offline · last report ${_ago(lastSeen, now)}. The '
                  'readings below are the last ones it sent.',
        color: NovaColors.amber,
      ),
    };
  }

  /// The status line under a sensor tile whose reading is [present].
  (String, Color) statusFor(bool present) => switch (phase) {
    _HelmetPhase.connecting => ('CONNECTING…', NovaColors.secondaryText),
    _HelmetPhase.error => ('ERROR', NovaColors.red),
    _HelmetPhase.missing => ('NO HELMET', NovaColors.secondaryText),
    _HelmetPhase.reporting when !present => (
      'NO READING',
      NovaColors.secondaryText,
    ),
    _HelmetPhase.reporting when live => ('LIVE', NovaColors.green),
    _HelmetPhase.reporting => ('STALE', NovaColors.amber),
  };

  /// The alcohol tile says ALERT while the helmet's threshold is crossed.
  /// No verdict sent is plain LIVE, not "clear".
  (String, Color) alcoholStatus() {
    final present = telemetry?.alcoholRelativeIndex != null;
    if (alcoholAlert && present) return ('ALERT', NovaColors.red);
    return statusFor(present);
  }

  /// The location tile: FIX only for a position taken in the last couple
  /// of minutes; an older real one is LAST KNOWN, never passed off as
  /// where the rider is.
  (String, Color) locationStatus() {
    final t = telemetry;
    final at = now;
    if (t?.positionAt == null) return statusFor(false);
    if (live && at != null && t!.hasCurrentFix(at)) {
      return ('FIX', NovaColors.green);
    }
    return ('LAST KNOWN', NovaColors.secondaryText);
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
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
                'SMART HELMET SYSTEM',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(
            Icons.notifications_none,
            color: NovaColors.primaryText,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationFeedPage()),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rider card
// ---------------------------------------------------------------------------

/// Who is signed in, and whether their helmet is working.
class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.profile, required this.helmet});

  final UserProfile? profile;
  final _HelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? '';
    final initials = initialsFrom(name);
    final (pillLabel, pillColor) = helmet.pill;
    final alert = helmet.alcoholAlert;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alert ? NovaColors.red.withValues(alpha: 0.10) : NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alert
              ? NovaColors.red.withValues(alpha: 0.5)
              : NovaColors.cardBorder,
        ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile == null ? '' : '@${profile!.username}',
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            liveRegion: true,
            child: _StatusPill(label: pillLabel, color: pillColor),
          ),
        ],
      ),
    );
  }
}

/// The helmet's state, in a rounded badge.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

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
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A sentence under the rider card: offline since when, no helmet, the
/// alcohol warning, or why the data can't be reached (with Retry).
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.banner, this.onRetry});

  final _Banner banner;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = banner.color;
    final retry = onRetry;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 10, retry == null ? 14 : 6, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              banner.text,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sensors
// ---------------------------------------------------------------------------

/// Impact, alcohol and location, side by side.
class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.helmet});

  final _HelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final t = helmet.telemetry;
    final impact = t?.impactG;
    final alcohol = t?.alcoholRelativeIndex;
    final (impactStatus, impactColor) = helmet.statusFor(impact != null);
    final (alcoholStatus, alcoholColor) = helmet.alcoholStatus();
    final (gpsStatus, gpsColor) = helmet.locationStatus();
    final hasPosition = t?.positionAt != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              iconColor: helmet.alcoholAlert
                  ? NovaColors.red
                  : NovaColors.secondaryText,
              value: alcohol == null
                  ? Unavailable.dash
                  : alcohol.toStringAsFixed(0),
              // The MQ-3's raw ADC count: a relative index, not a
              // percentage and not a breath concentration, so there is
              // no unit and the label says raw.
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
              value: hasPosition ? 'GPS' : Unavailable.dash,
              label: 'LOCATION',
              statusText: gpsStatus,
              statusColor: gpsColor,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GpsMapPage())),
            ),
          ),
        ],
      ),
    );
  }
}

/// One sensor: an icon in a circle, the reading, what it is, and how
/// much to trust it.
class _CircleStatCard extends StatelessWidget {
  const _CircleStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.statusText,
    required this.statusColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: statusColor, size: 6),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) return card;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tap,
          child: card,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Current speed
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
          color: NovaColors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Where "Current trip" was. The trip's distance and duration are gone —
/// nothing records a trip — and speed got the whole card.
class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.helmet});

  final _HelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final speed = helmet.currentSpeedKmph;
    final note = !helmet.live
        ? 'Speed shows only while the helmet is live.'
        : speed == null
        ? 'Waiting for a GPS fix. The helmet needs a clear view of the sky.'
        : 'From the helmet\'s GPS.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                speed == null ? Unavailable.dash : speed.toStringAsFixed(0),
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'km/h',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              note,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SOS
// ---------------------------------------------------------------------------

/// The big glowing SOS button. Opens Alerts, which says what happens in
/// an emergency.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
        child: Semantics(
          button: true,
          label: 'SOS. Opens the emergency page.',
          excludeSemantics: true,
          child: Material(
            color: NovaColors.red,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
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
      ),
    );
  }
}

/// "12 s ago", "4 min ago", "2 h ago" — short enough for one line.
String _ago(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.isNegative || diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds} s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
