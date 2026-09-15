import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// (lat, lng) → canvas, with north at the top. The window is fixed, so a
/// dot's drift across the panel matches its drift across the city.
///
/// Shared by the painter and the tap hit-test so a click always resolves to
/// the dot the operator actually aimed at.
Offset projectLatLng(double lat, double lng, Size size) {
  final x = (lng - kFleetLngMin) / (kFleetLngMax - kFleetLngMin);
  final y = 1 - (lat - kFleetLatMin) / (kFleetLatMax - kFleetLatMin);
  return Offset(
    (x * size.width).clamp(0.0, size.width),
    (y * size.height).clamp(0.0, size.height),
  );
}

/// The stylized Metro Manila basemap with one dot per helmet.
///
/// Everything is painted — no tiles, no map package — but the geometry is
/// real enough that a rider drifting north-east reads as heading for Fairview.
///
/// Extracted from the dashboard panel so the Rider Monitoring page renders
/// the identical map instead of a second copy that could drift out of sync.
class FleetMapView extends StatefulWidget {
  final List<Rider> riders;
  final List<HelmetTelemetry> telemetry;

  /// Highlighted with a locator ring; its trail is the one that gets drawn.
  final String? selectedRiderId;

  /// Null makes the map read-only — the dashboard panel does not take
  /// selection, the monitoring page does.
  final ValueChanged<String?>? onRiderTap;

  /// Breadcrumb of recent fixes for the selected rider, oldest first.
  final List<TrailPoint> trail;

  final bool showLegend;

  const FleetMapView({
    super.key,
    required this.riders,
    required this.telemetry,
    this.selectedRiderId,
    this.onRiderTap,
    this.trail = const [],
    this.showLegend = true,
  });

  /// Radius in logical pixels within which a tap counts as hitting a dot.
  static const double tapSlop = 18;

  @override
  State<FleetMapView> createState() => _FleetMapViewState();
}

class _FleetMapViewState extends State<FleetMapView>
    with SingleTickerProviderStateMixin {
  /// Drives the emergency ping. Handed to the painter as its repaint
  /// listenable so the pulse never rebuilds the widget tree.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  List<RiderPin> _buildPins() {
    final pins = <RiderPin>[];
    for (final rider in widget.riders) {
      final t = _telemetryFor(rider.id);
      if (t == null) continue;
      pins.add(
        RiderPin(
          riderId: rider.id,
          lat: t.lat,
          lng: t.lng,
          color: StatusPill.colorForRider(rider.status),
          emergency: rider.status == RiderStatus.emergency,
          selected: rider.id == widget.selectedRiderId,
        ),
      );
    }
    return pins;
  }

  HelmetTelemetry? _telemetryFor(String riderId) {
    for (final t in widget.telemetry) {
      if (t.riderId == riderId) return t;
    }
    return null;
  }

  /// Nearest dot within [FleetMapView.tapSlop], else null — tapping empty
  /// basemap clears the selection rather than doing nothing.
  void _handleTap(TapUpDetails details, Size size, List<RiderPin> pins) {
    final onTap = widget.onRiderTap;
    if (onTap == null) return;

    String? hitId;
    var bestDistance = double.infinity;
    for (final pin in pins) {
      final center = projectLatLng(pin.lat, pin.lng, size);
      final distance = (center - details.localPosition).distance;
      if (distance < FleetMapView.tapSlop && distance < bestDistance) {
        bestDistance = distance;
        hitId = pin.riderId;
      }
    }
    onTap(hitId);
  }

  @override
  Widget build(BuildContext context) {
    final pins = _buildPins();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.onRiderTap == null
                ? null
                : (details) => _handleTap(details, size, pins),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: FleetMapPainter(
                    pins: pins,
                    pulse: _pulse,
                    trail: widget.trail,
                  ),
                  size: Size.infinite,
                ),
                const Positioned(top: 8, right: 8, child: _ZoomControls()),
                if (widget.showLegend)
                  const Positioned(bottom: 8, left: 8, child: _MapLegend()),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Visual only — pan/zoom arrives with the real basemap.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _button(Icons.add, top: true),
        _button(Icons.remove, top: false),
      ],
    );
  }

  Widget _button(IconData icon, {required bool top}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: NovaColors.card.withValues(alpha: 0.92),
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(top ? 4 : 0),
          bottom: Radius.circular(top ? 0 : 4),
        ),
      ),
      child: Icon(icon, size: 14, color: NovaColors.secondaryText),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: NovaColors.card.withValues(alpha: 0.85),
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in RiderStatus.values) ...[
            if (status != RiderStatus.values.first) const SizedBox(width: 12),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: StatusPill.colorForRider(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              status.label,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RiderPin {
  final String riderId;
  final double lat;
  final double lng;
  final Color color;
  final bool emergency;
  final bool selected;

  const RiderPin({
    required this.riderId,
    required this.lat,
    required this.lng,
    required this.color,
    required this.emergency,
    this.selected = false,
  });
}

class FleetMapPainter extends CustomPainter {
  final List<RiderPin> pins;
  final Animation<double> pulse;
  final List<TrailPoint> trail;

  FleetMapPainter({
    required this.pins,
    required this.pulse,
    this.trail = const [],
  }) : super(repaint: pulse);

  static const _basemap = Color(0xFF0B0F1E);
  static const _street = Color(0xFF1A2138);
  static const _avenue = Color(0xFF232C4A);
  static const _river = Color(0xFF16305A);

  static const _verticalStreets = 14;
  static const _horizontalStreets = 10;

  /// Major avenues in normalized (x, y) space — deliberately off-axis so the
  /// grid does not read as graph paper.
  static const _avenues = <List<Offset>>[
    [Offset(0.04, 0.18), Offset(0.96, 0.34)],
    [Offset(0.10, 0.86), Offset(0.72, 0.06)],
    [Offset(0.00, 0.62), Offset(1.00, 0.52)],
    [Offset(0.34, 0.00), Offset(0.58, 1.00)],
  ];

  /// Meandering river across the bottom-right quadrant.
  static const _riverPath = <Offset>[
    Offset(0.52, 1.02),
    Offset(0.60, 0.88),
    Offset(0.58, 0.78),
    Offset(0.68, 0.70),
    Offset(0.78, 0.72),
    Offset(0.86, 0.62),
    Offset(1.02, 0.60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _basemap);

    _paintStreetGrid(canvas, size);
    _paintAvenues(canvas, size);
    _paintRiver(canvas, size);
    _paintDistrictLabels(canvas, size);
    _paintTrail(canvas, size);
    _paintPins(canvas, size);
  }

  void _paintStreetGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _street
      ..strokeWidth = 1;

    for (var i = 1; i < _verticalStreets; i++) {
      final x = size.width * i / _verticalStreets;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < _horizontalStreets; i++) {
      final y = size.height * i / _horizontalStreets;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintAvenues(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _avenue
      ..strokeWidth = 2;

    for (final avenue in _avenues) {
      canvas.drawLine(
        _scale(avenue.first, size),
        _scale(avenue.last, size),
        paint,
      );
    }
  }

  void _paintRiver(Canvas canvas, Size size) {
    final start = _scale(_riverPath.first, size);
    final path = Path()..moveTo(start.dx, start.dy);
    for (final point in _riverPath.skip(1)) {
      final p = _scale(point, size);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _river.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintDistrictLabels(Canvas canvas, Size size) {
    for (final district in kFleetDistricts) {
      final anchor = projectLatLng(district.lat, district.lng, size);
      final painter = TextPainter(
        text: TextSpan(
          text: district.mapLabel,
          style: TextStyle(
            color: NovaColors.secondaryText.withValues(alpha: 0.5),
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Skip rather than overlap when the panel is too small to hold the label.
      if (size.width < painter.width + 4 || size.height < painter.height + 4) {
        continue;
      }

      // Sits above the centroid so the label never hides under its own
      // cluster of rider dots.
      painter.paint(
        canvas,
        Offset(
          (anchor.dx - painter.width / 2)
              .clamp(2.0, size.width - painter.width - 2),
          (anchor.dy - 16).clamp(2.0, size.height - painter.height - 2),
        ),
      );
    }
  }

  /// Breadcrumb for the selected rider, oldest fix faintest. Drawn as
  /// per-segment lines rather than one path so each can carry its own alpha.
  void _paintTrail(Canvas canvas, Size size) {
    if (trail.length < 2) return;

    for (var i = 1; i < trail.length; i++) {
      // Oldest segment ~12% opacity, newest ~70%.
      final progress = i / (trail.length - 1);
      final paint = Paint()
        ..color = NovaColors.cyan.withValues(alpha: 0.12 + 0.58 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 1.6 * progress
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        projectLatLng(trail[i - 1].lat, trail[i - 1].lng, size),
        projectLatLng(trail[i].lat, trail[i].lng, size),
        paint,
      );
    }
  }

  void _paintPins(Canvas canvas, Size size) {
    for (final pin in pins) {
      final center = projectLatLng(pin.lat, pin.lng, size);

      canvas.drawCircle(
        center,
        12,
        Paint()..color = pin.color.withValues(alpha: 0.25),
      );

      if (pin.emergency) {
        // Ring breathes 6 → 16px and fades out over the loop.
        final t = pulse.value;
        canvas.drawCircle(
          center,
          6 + 10 * t,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = pin.color.withValues(alpha: (1 - t) * 0.9),
        );
      }

      if (pin.selected) {
        // Static locator ring plus crosshair ticks — reads as "this one"
        // even when the dot sits in a cluster.
        canvas.drawCircle(
          center,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = NovaColors.cyan,
        );
        final tick = Paint()
          ..strokeWidth = 1.4
          ..color = NovaColors.cyan;
        for (final d in [
          [const Offset(0, -15), const Offset(0, -12)],
          [const Offset(0, 12), const Offset(0, 15)],
          [const Offset(-15, 0), const Offset(-12, 0)],
          [const Offset(12, 0), const Offset(15, 0)],
        ]) {
          canvas.drawLine(center + d[0], center + d[1], tick);
        }
      }

      canvas.drawCircle(center, 3.5, Paint()..color = pin.color);
    }
  }

  Offset _scale(Offset normalized, Size size) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  @override
  bool shouldRepaint(covariant FleetMapPainter old) =>
      old.pins != pins || old.trail != trail;
}
