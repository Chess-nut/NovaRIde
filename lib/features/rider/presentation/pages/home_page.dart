import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/errors/firebase_failure_mapper.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import '../../domain/entities/helmet_telemetry.dart';
import '../providers/helmet_telemetry_provider.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import 'alerts_page.dart';
import 'gps_map_page.dart';
import 'notification_feed_page.dart';

/// The rider's home: is my helmet working, what is it reading, and help.
///
/// Built on Signal (`core/theme`) like the auth screens, in reading order
/// of what a rider needs at a glance: the helmet's status, its four live
/// sensors, the current speed, then SOS.
///
/// What it deliberately does not show: battery, hardware and signal tiles
/// (the firmware sends no battery level and a hard-coded rssi on
/// cellular, so they could only ever be dashes), and trip distance and
/// duration (nothing records a trip yet). A reading the helmet did not
/// send is an em dash, never 0.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final helmet = _HelmetView.from(ref.watch(helmetTelemetryProvider), now);
    final name = firstNameFrom(
      ref.watch(authStateProvider).profile?.displayName,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(firstName: name, helmet: helmet),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
              _HelmetStatusCard(
                helmet: helmet,
                now: now,
                onRetry: () => ref.invalidate(helmetTelemetryProvider),
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
              const NovaSectionLabel('Sensors'),
              const SizedBox(height: AppSpacing.md),
              _SensorGrid(helmet: helmet),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
              _SpeedCard(helmet: helmet),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
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

  /// The stream failed; the status card says why and offers Retry.
  error,

  /// The snapshot arrived and there is nothing at that device id.
  missing,

  /// The helmet's node, live or stale. Its fields may still be absent.
  reporting,
}

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
  /// `online` or `lastSeen` is not live: there is no telling.
  final bool live;
  final String? errorMessage;

  /// The clock this view was read at. Null outside [_HelmetPhase.reporting].
  final DateTime? now;

  /// The helmet's speed, only while it is live and its fix is current.
  double? get currentSpeedKmph {
    final at = now;
    return live && at != null ? telemetry?.currentSpeedKmph(at) : null;
  }

  /// The location tile: the fix, and how far to trust it. "Live" only
  /// for a position taken in the last couple of minutes; an older one is
  /// a last known position, said as such.
  (String, NovaTone) locationStatus() {
    final t = telemetry;
    final at = now;
    final hasPosition = t?.positionAt != null;
    if (!hasPosition) return statusFor(false);
    if (live && at != null && t!.hasCurrentFix(at)) {
      return ('Live', NovaTone.safe);
    }
    return phase == _HelmetPhase.reporting
        ? ('Last known', NovaTone.offline)
        : statusFor(true);
  }

  /// Live, and the helmet's own threshold says the rider has been
  /// drinking. The one state that takes over the status card.
  bool get alcoholAlert => live && telemetry?.alcoholAlert == true;

  /// The status line under a sensor whose reading is [present].
  (String, NovaTone) statusFor(bool present) => switch (phase) {
    _HelmetPhase.connecting => ('Connecting…', NovaTone.offline),
    _HelmetPhase.error => ('Error', NovaTone.critical),
    _HelmetPhase.missing => ('No helmet', NovaTone.offline),
    _HelmetPhase.reporting when !present => ('No reading', NovaTone.offline),
    _HelmetPhase.reporting when live => ('Live', NovaTone.safe),
    _HelmetPhase.reporting => ('Stale', NovaTone.offline),
  };

  /// The alcohol tile carries the helmet's own threshold verdict while it
  /// is live. No verdict sent is plain "Live", not "Below threshold".
  (String, NovaTone) alcoholStatus() {
    final t = telemetry;
    final present = t?.alcoholRelativeIndex != null;
    if (live && present && t!.alcoholAlert == true) {
      return ('Above threshold', NovaTone.warning);
    }
    if (live && present && t!.alcoholAlert == false) {
      return ('Below threshold', NovaTone.safe);
    }
    return statusFor(present);
  }

  /// The posture tile says the firmware's own orientation label while it
  /// is live — "Upright", "Side/abnormal" — and warns on an abnormal one.
  (String, NovaTone) postureStatus() {
    final t = telemetry;
    final orientation = t?.orientation;
    final present = t?.tiltDegrees != null;
    if (live && present && orientation != null && orientation != 'Unknown') {
      final odd = orientation.toLowerCase().contains('abnormal');
      return (orientation, odd ? NovaTone.warning : NovaTone.safe);
    }
    return statusFor(present);
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.helmet});

  final String firstName;
  final _HelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final greeting = firstName.isEmpty ? 'Hi there' : 'Hi, $firstName';
    final subline = helmet.live
        ? 'Your helmet is watching the road with you.'
        : 'Turn your helmet on to start a ride.';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: context.text.h1),
              const SizedBox(height: 2),
              Text(subline, style: context.text.bodyMuted),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // No unread dot: nothing counts unread notifications yet, and a
        // dot that never goes away teaches the rider to ignore it.
        IconButton(
          tooltip: 'Notifications',
          style: IconButton.styleFrom(
            backgroundColor: colors.surfaceRaised,
            fixedSize: const Size.square(AppSizes.minTouchTarget),
          ),
          icon: Icon(Icons.notifications_none, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationFeedPage()),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helmet status
// ---------------------------------------------------------------------------

/// The first thing on screen: is the helmet working?
class _HelmetStatusCard extends StatelessWidget {
  const _HelmetStatusCard({
    required this.helmet,
    required this.now,
    required this.onRetry,
  });

  final _HelmetView helmet;
  final DateTime now;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lastSeen = helmet.telemetry?.lastSeen;
    final seen = lastSeen == null ? null : _ago(lastSeen, now);

    final (
      String title,
      String detail,
      NovaTone tone,
      String? pill,
      IconData? icon,
    ) = switch (helmet.phase) {
      _HelmetPhase.connecting => (
        'Connecting to helmet…',
        'Waiting for its first report.',
        NovaTone.offline,
        null,
        null,
      ),
      _HelmetPhase.error => (
        'Can\'t reach helmet data',
        helmet.errorMessage ?? '',
        NovaTone.critical,
        null,
        Icons.error_outline,
      ),
      _HelmetPhase.missing => (
        'No helmet',
        'Nothing has reported yet. Turn the helmet on and check its '
            'Wi‑Fi.',
        NovaTone.offline,
        null,
        null,
      ),
      _HelmetPhase.reporting when helmet.alcoholAlert => (
        'Alcohol detected',
        'Please don\'t ride. The helmet\'s alcohol reading is above its '
            'threshold.',
        NovaTone.warning,
        'Live',
        Icons.water_drop_outlined,
      ),
      _HelmetPhase.reporting when helmet.live => (
        'Helmet connected',
        seen == null ? 'Reporting now.' : 'Last report $seen.',
        NovaTone.safe,
        'Live',
        null,
      ),
      _HelmetPhase.reporting => (
        'Helmet offline',
        seen == null
            ? 'The readings below are the last ones it sent.'
            : 'Last report $seen. The readings below are the last ones '
                  'it sent.',
        NovaTone.offline,
        'Offline',
        null,
      ),
    };

    // The status card tints only for the states a rider must act on.
    final cardTone = tone == NovaTone.warning || tone == NovaTone.critical
        ? tone
        : NovaTone.neutral;

    return Semantics(
      container: true,
      liveRegion: true,
      child: NovaCard(
        tone: cardTone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 20, color: tone.colorIn(colors))
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tone.colorIn(colors),
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: context.text.h2.copyWith(
                      color: cardTone == NovaTone.neutral
                          ? colors.textPrimary
                          : tone.textIn(colors),
                    ),
                  ),
                ),
                if (pill != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  NovaPill(
                    label: pill,
                    tone: helmet.live ? NovaTone.safe : NovaTone.offline,
                  ),
                ],
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail,
                style: cardTone == NovaTone.neutral
                    ? context.text.bodyMuted
                    : context.text.body,
              ),
            ],
            if (helmet.phase == _HelmetPhase.error) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sensors
// ---------------------------------------------------------------------------

/// Alcohol, posture, impact and location, two by two.
class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.helmet});

  final _HelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final t = helmet.telemetry;

    final alcohol = t?.alcoholRelativeIndex;
    final (alcoholText, alcoholTone) = helmet.alcoholStatus();

    final tilt = t?.tiltDegrees;
    final (postureText, postureTone) = helmet.postureStatus();

    final impact = t?.impactG;
    final (impactText, impactTone) = helmet.statusFor(impact != null);

    final fixAt = t?.positionAt;
    final satellites = t?.satellites;
    final now = helmet.now;
    final (fixText, fixTone) = helmet.locationStatus();
    // "Fix" with its satellites while current; otherwise how old the last
    // real position is, so a week-old dot is never read as where you are.
    final current = now != null && t != null && t.hasCurrentFix(now);
    final fixValue = fixAt == null ? null : (current ? 'Fix' : 'Last fix');
    final fixUnit = fixAt == null
        ? null
        : current
        ? (satellites == null ? null : '$satellites satellites')
        : (now == null ? null : novaTimeAgo(fixAt, now));

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SensorTile(
                  icon: Icons.water_drop_outlined,
                  label: 'Alcohol',
                  // The MQ-3's raw ADC count: a relative index, not a
                  // percentage and not a breath concentration.
                  value: alcohol?.toStringAsFixed(0),
                  unit: 'raw index',
                  status: alcoholText,
                  tone: alcoholTone,
                  statusIcon: alcoholTone == NovaTone.warning
                      ? Icons.arrow_upward
                      : null,
                  highlight: helmet.alcoholAlert,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SensorTile(
                  icon: Icons.accessibility_new,
                  label: 'Posture',
                  value: tilt == null ? null : '${tilt.toStringAsFixed(0)}°',
                  unit: 'tilt',
                  status: postureText,
                  tone: postureTone,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SensorTile(
                  icon: Icons.monitor_heart_outlined,
                  label: 'Impact',
                  value: impact?.toStringAsFixed(2),
                  unit: 'g',
                  status: impactText,
                  tone: impactTone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SensorTile(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: fixValue,
                  unit: fixUnit,
                  status: fixText,
                  tone: fixTone,
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const GpsMapPage())),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One sensor: what it is, what it reads, and whether to trust that.
class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.tone,
    this.unit,
    this.statusIcon,
    this.highlight = false,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null is "no reading" and renders as a dash.
  final String? value;
  final String? unit;
  final String status;
  final NovaTone tone;
  final IconData? statusIcon;

  /// Outline the tile in [tone] — for the one reading the rider must see.
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Stale and absent readings are drawn in the secondary colour, so an
    // old number never looks as current as a live one.
    final current = tone != NovaTone.offline;
    final valueStyle = context.text.h1.copyWith(
      color: current ? colors.textPrimary : colors.textSecondary,
    );

    return NovaCard(
      tone: highlight ? tone : NovaTone.neutral,
      onTap: onTap,
      semanticLabel: onTap == null
          ? null
          : '$label, ${value ?? 'no reading'}, $status. Open map.',
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + 2,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: context.text.labelMuted)),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value ?? Unavailable.dash, style: valueStyle),
              if (unit != null && value != null) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                Flexible(child: Text(unit!, style: context.text.caption)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          NovaStatusLine(text: status, tone: tone, icon: statusIcon),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Speed
// ---------------------------------------------------------------------------

/// The helmet's own speed, only while it is live: an old speed shown as
/// current is worse than none.
class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.helmet});

  final _HelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final speed = helmet.currentSpeedKmph;
    final note = !helmet.live
        ? 'Speed shows only while the helmet is live.'
        : speed == null
        ? 'Waiting for a GPS fix. The helmet needs a clear view of the sky.'
        : 'From the helmet\'s GPS.';

    return NovaCard(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current speed', style: context.text.labelMuted),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    speed == null ? Unavailable.dash : speed.toStringAsFixed(0),
                    style: context.text.display.copyWith(
                      color: speed == null
                          ? colors.textSecondary
                          : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text('km/h', style: context.text.bodyMuted),
                ],
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              note,
              textAlign: TextAlign.end,
              style: context.text.caption,
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

/// Full width so a gloved thumb cannot miss it. Dark text on the SOS pink
/// (4.7:1); the white it used to carry was 3.5:1.
///
/// Behaviour is unchanged on purpose: a tap opens the Alerts page. Whether
/// SOS should send on a long press or after a countdown is a separate
/// decision.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.sos,
          foregroundColor: colors.onAction,
          shape: const StadiumBorder(),
          textStyle: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.warning_amber_rounded, size: 24),
        label: const Text('SOS · Get help'),
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
