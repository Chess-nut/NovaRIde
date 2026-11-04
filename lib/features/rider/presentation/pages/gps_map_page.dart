import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/utils/coordinates.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';
import 'package:novaride/core/widgets/unavailable.dart';

import '../../domain/entities/helmet_telemetry.dart';
import '../providers/helmet_telemetry_provider.dart';

/// "Location" — where the helmet last was, on Signal.
///
/// **Live.** Reads the same helmet node as Home. It used to show a
/// scripted trip — 42 km/h heading NE on Makati Ave, ±4.8 m — over a
/// drawn-in route.
///
/// **The map is still a drawing, not tiles.** `google_maps_flutter`
/// needs a billed key wired into native config before it renders; until
/// then this paints a dark street grid with the helmet as a dot in the
/// middle. Swapping the [CustomPaint] for a `GoogleMap` centred on
/// [HelmetTelemetry.lat]/[HelmetTelemetry.lng] is the drop-in upgrade.
///
/// What is gone, because nothing measured it: the heading arrow (the
/// firmware sends no heading), the accuracy figure (no HDOP), the route
/// trail, and the "follow me" toggle, which had nothing to follow.
/// "Share" now really copies a link.
class GpsMapPage extends ConsumerWidget {
  const GpsMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final telemetryAsync = ref.watch(helmetTelemetryProvider);
    final t = telemetryAsync.value;
    final live =
        t != null && t.online == true && t.isFresh(now, helmetStaleAfter);
    final hasPosition = t?.lat != null && t?.lng != null;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: hasPosition
                  ? 'Map with the helmet\'s last position at the centre'
                  : 'Map with no position yet',
              child: CustomPaint(
                painter: _MapPainter(
                  showMarker: hasPosition,
                  grid: colors.border,
                  avenue: colors.borderStrong,
                  ground: colors.surfaceSunken,
                  marker: live ? colors.riding : colors.offline,
                  markerRing: colors.surface,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(telemetry: t, live: live, now: now),
                const Spacer(),
                _DetailsSheet(telemetry: t, live: live, now: now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Back, and how fresh the position is, over the map.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.telemetry,
    required this.live,
    required this.now,
  });

  final HelmetTelemetry? telemetry;
  final bool live;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = telemetry;
    final taken = fixTakenAt(t?.lastSeen, t?.gpsAgeMs);
    final label = t?.lat == null
        ? 'No GPS fix yet'
        : taken == null
        ? 'Last known position'
        : 'Fix taken ${novaTimeAgo(taken, now)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        kRiderGutter,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceRaised,
              fixedSize: const Size.square(AppSizes.minTouchTarget),
            ),
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: NovaCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(label, style: context.text.label)),
                  NovaPill(
                    label: live ? 'Live' : 'Offline',
                    tone: live ? NovaTone.safe : NovaTone.offline,
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

/// Speed, satellites, coordinates, and a link to share.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.telemetry,
    required this.live,
    required this.now,
  });

  final HelmetTelemetry? telemetry;
  final bool live;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = telemetry;
    final lat = t?.lat;
    final lng = t?.lng;
    // An old speed shown as current is worse than none.
    final speed = live ? t?.speedKmph : null;
    final satellites = t?.satellites;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        kRiderGutter,
        AppSpacing.xl,
        kRiderGutter,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Speed',
                  value: speed?.toStringAsFixed(0),
                  unit: 'km/h',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Satellites',
                  value: satellites?.toString(),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Fix',
                  value: switch (t?.hasUsableFix) {
                    true => 'Current',
                    false => 'Old',
                    null => null,
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.sm),
          NovaValueRow(
            label: 'Latitude',
            value: lat == null ? Unavailable.dash : formatLatitude(lat),
          ),
          NovaValueRow(
            label: 'Longitude',
            value: lng == null ? Unavailable.dash : formatLongitude(lng),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: lat == null || lng == null
                  ? null
                  : () => _copyLink(context, t?.mapsUrl, lat, lng),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.borderStrong),
                shape: const StadiumBorder(),
                textStyle: AppTypography.title,
              ),
              icon: const Icon(Icons.link, size: 20),
              label: const Text('Copy map link'),
            ),
          ),
        ],
      ),
    );
  }

  /// The firmware's own Google Maps link when it sent one, else one built
  /// from the coordinates.
  Future<void> _copyLink(
    BuildContext context,
    String? mapsUrl,
    double lat,
    double lng,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final link = (mapsUrl != null && mapsUrl.isNotEmpty)
        ? mapsUrl
        : 'https://maps.google.com/?q=$lat,$lng';
    await Clipboard.setData(ClipboardData(text: link));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Map link copied. Paste it to share.')),
      );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.unit});

  final String label;

  /// Null is no reading: a dash.
  final String? value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelMuted),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value ?? Unavailable.dash,
              style: context.text.h1.copyWith(
                color: value == null
                    ? colors.textSecondary
                    : colors.textPrimary,
              ),
            ),
            if (unit != null && value != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(unit!, style: context.text.caption),
            ],
          ],
        ),
      ],
    );
  }
}

/// A dark street grid with the helmet as a dot at the centre.
class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.showMarker,
    required this.grid,
    required this.avenue,
    required this.ground,
    required this.marker,
    required this.markerRing,
  });

  final bool showMarker;
  final Color grid;
  final Color avenue;
  final Color ground;
  final Color marker;
  final Color markerRing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    final minor = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }

    final major = Paint()
      ..color = avenue
      ..strokeWidth = 3;
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

    if (!showMarker) return;
    final centre = Offset(size.width / 2, size.height * 0.4);
    canvas.drawCircle(
      centre,
      28,
      Paint()..color = marker.withValues(alpha: 0.18),
    );
    canvas.drawCircle(centre, 11, Paint()..color = markerRing);
    canvas.drawCircle(centre, 8, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.showMarker != showMarker ||
      old.marker != marker ||
      old.grid != grid ||
      old.ground != ground;
}
