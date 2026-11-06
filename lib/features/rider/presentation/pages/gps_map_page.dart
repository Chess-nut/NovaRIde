import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/utils/coordinates.dart';
import 'package:novaride/core/widgets/nova_live_map.dart';
import 'package:novaride/core/widgets/nova_lists.dart' show novaTimeAgo;
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/shared/theme.dart';

import '../../domain/entities/helmet_telemetry.dart';
import '../providers/helmet_telemetry_provider.dart';

/// "Location" — where the helmet last was, in the original NovaRide look.
///
/// **Live.** Reads the same helmet data as Home. The old page showed a
/// scripted trip — 42 km/h heading NE on Makati Ave, ±4.8 m.
///
/// **Speed sits on the map**, as a round speedometer where the old
/// "follow me" button was, so it can be read at a glance without looking
/// at the sheet. It shows only while the helmet is live and its fix is
/// current; an old speed shown as current is worse than none.
///
/// **Gone, because nothing measures them:** heading (the firmware sends
/// none), accuracy (no HDOP), the route trail, the street address and the
/// follow toggle. In their place the sheet shows what the GPS does send:
/// satellites in view, whether the fix is current, and when it was taken.
///
/// **The map is OpenStreetMap** (free, no key, no card): a dark street map
/// with a pin on the helmet that follows each new fix — cyan while live,
/// amber for a last known position. Before the first fix it falls back to
/// the drawn street grid.
class GpsMapPage extends ConsumerWidget {
  const GpsMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final t = ref.watch(helmetTelemetryProvider).value;
    final live =
        t != null && t.online == true && t.isFresh(now, helmetStaleAfter);
    final hasPosition = t?.lat != null && t?.lng != null;
    final speed = t != null && live ? t.currentSpeedKmph(now) : null;

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: NovaLiveMap(
              lat: t?.lat,
              lng: t?.lng,
              pinColor: live ? NovaColors.cyan : NovaColors.amber,
              semanticLabel: 'Map with the helmet\'s position at the centre',
              fallback: Semantics(
                label: hasPosition
                    ? 'Map with the helmet\'s last position at the centre'
                    : 'Map with no position yet',
                child: CustomPaint(
                  painter: _MapPainter(showMarker: hasPosition, live: live),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(telemetry: t, live: live, now: now),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _Speedometer(speed: speed, live: live),
                  ),
                ),
                const SizedBox(height: 12),
                _BottomSheet(telemetry: t, now: now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Back, how fresh the position is, and LIVE / OFFLINE.
class _Header extends StatelessWidget {
  const _Header({
    required this.telemetry,
    required this.live,
    required this.now,
  });

  final HelmetTelemetry? telemetry;
  final bool live;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = telemetry;
    final taken = t?.positionAt;
    final label = t?.lat == null
        ? 'No GPS fix yet'
        : taken == null
        ? 'Last known position'
        : 'Fix taken ${novaTimeAgo(taken, now)}';
    final stateColor = live ? NovaColors.green : NovaColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Row(
        children: [
          Material(
            color: NovaColors.card.withValues(alpha: 0.92),
            shape: const CircleBorder(
              side: BorderSide(color: NovaColors.cardBorder),
            ),
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back,
                color: NovaColors.primaryText,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: NovaColors.card.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NovaColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: NovaColors.cyan,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.circle, color: stateColor, size: 7),
                  const SizedBox(width: 5),
                  Text(
                    live ? 'LIVE' : 'OFFLINE',
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The current speed, on the map. A dash when there is no current one.
class _Speedometer extends StatelessWidget {
  const _Speedometer({required this.speed, required this.live});

  final double? speed;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final value = speed;
    final ring = value != null ? NovaColors.cyan : NovaColors.cardBorder;

    return Semantics(
      label: value == null
          ? 'Speed unavailable'
          : 'Speed ${value.toStringAsFixed(0)} kilometres per hour',
      excludeSemantics: true,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: NovaColors.card.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 3),
          boxShadow: value != null
              ? [
                  BoxShadow(
                    color: NovaColors.cyan.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value == null ? Unavailable.dash : value.toStringAsFixed(0),
              style: TextStyle(
                color: value == null
                    ? NovaColors.secondaryText
                    : NovaColors.primaryText,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const Text(
              'km/h',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the GPS sends — satellites, fix, when — then coordinates and a
/// link to share.
class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.telemetry, required this.now});

  final HelmetTelemetry? telemetry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = telemetry;
    final lat = t?.lat;
    final lng = t?.lng;
    final taken = t?.positionAt;
    final current = t?.hasUsableFix == null ? null : t!.hasCurrentFix(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: NovaColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NovaColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HudStat(
                  icon: Icons.satellite_alt_outlined,
                  color: NovaColors.purple,
                  value: t?.satellites?.toString(),
                  label: 'SATELLITES',
                ),
              ),
              Expanded(
                child: _HudStat(
                  icon: Icons.gps_fixed,
                  color: current == true ? NovaColors.green : NovaColors.amber,
                  value: switch (current) {
                    true => 'Current',
                    false => 'Old',
                    null => null,
                  },
                  label: 'FIX',
                ),
              ),
              Expanded(
                child: _HudStat(
                  icon: Icons.schedule,
                  color: NovaColors.cyan,
                  value: taken == null ? null : novaTimeAgo(taken, now),
                  label: 'FIX TAKEN',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NovaColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NovaColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CoordLabel(
                    label: 'LATITUDE',
                    value: lat == null ? Unavailable.dash : formatLatitude(lat),
                  ),
                ),
                Container(width: 1, height: 32, color: NovaColors.cardBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: _CoordLabel(
                    label: 'LONGITUDE',
                    value: lng == null
                        ? Unavailable.dash
                        : formatLongitude(lng),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: lat == null || lng == null
                  ? null
                  : () => _copyLink(context, t?.mapsUrl, lat, lng),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: lat == null ? NovaColors.cardBorder : NovaColors.cyan,
                ),
                foregroundColor: NovaColors.cyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.share_location_outlined, size: 18),
              label: const Text(
                'COPY MAP LINK',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The firmware's own Google Maps link when it sent one, else one built
  /// from the coordinates.
  void _copyLink(
    BuildContext context,
    String? mapsUrl,
    double lat,
    double lng,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final link = (mapsUrl != null && mapsUrl.isNotEmpty)
        ? mapsUrl
        : 'https://maps.google.com/?q=$lat,$lng';
    // A void seam: the tap never holds the Future.
    Clipboard.setData(ClipboardData(text: link))
        .then((_) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                backgroundColor: NovaColors.card,
                behavior: SnackBarBehavior.floating,
                content: Text(
                  'Map link copied. Paste it to share.',
                  style: TextStyle(color: NovaColors.primaryText),
                ),
              ),
            );
        })
        .catchError((Object _) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Couldn\'t copy the link.')),
          );
        });
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;

  /// Null is no reading: a dash.
  final String? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: value == null ? NovaColors.secondaryText : color, size: 18),
        const SizedBox(height: 6),
        Text(
          value ?? Unavailable.dash,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null
                ? NovaColors.secondaryText
                : NovaColors.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _CoordLabel extends StatelessWidget {
  const _CoordLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: NovaColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The old dark street grid, with the helmet as a dot at the centre —
/// cyan while live, grey when the position is only the last known one.
/// No heading arrow and no trail: nothing measures either.
class _MapPainter extends CustomPainter {
  _MapPainter({required this.showMarker, required this.live});

  final bool showMarker;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D1220),
    );

    final minor = Paint()
      ..color = NovaColors.cardBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }

    final major = Paint()
      ..color = NovaColors.cardBorder
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(0, size.height * 0.38),
      Offset(size.width, size.height * 0.38),
      major,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, 0),
      Offset(size.width * 0.62, size.height),
      major,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.85),
      Offset(size.width, size.height * 0.15),
      major,
    );

    if (!showMarker) return;
    final marker = live ? NovaColors.cyan : NovaColors.secondaryText;
    final centre = Offset(size.width / 2, size.height * 0.4);
    canvas.drawCircle(centre, 34, Paint()..color = marker.withValues(alpha: 0.12));
    canvas.drawCircle(centre, 22, Paint()..color = marker.withValues(alpha: 0.15));
    canvas.drawCircle(centre, 11, Paint()..color = NovaColors.background);
    canvas.drawCircle(centre, 8, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.showMarker != showMarker || old.live != live;
}
