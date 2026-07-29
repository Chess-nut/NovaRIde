import 'package:flutter/material.dart';
import 'package:novaride/admin/state/mock_fleet_controller.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// The centrepiece: a stylized Metro Manila basemap with one dot per helmet.
/// Everything is painted — no tiles, no map package — but the geometry is
/// real enough that a rider drifting north-east reads as heading for Fairview.
class LiveFleetMapPanel extends StatefulWidget {
  final List<Rider> riders;
  final List<HelmetTelemetry> telemetry;
  final DateTime lastSync;

  const LiveFleetMapPanel({
    super.key,
    required this.riders,
    required this.telemetry,
    required this.lastSync,
  });

  @override
  State<LiveFleetMapPanel> createState() => _LiveFleetMapPanelState();
}

class _LiveFleetMapPanelState extends State<LiveFleetMapPanel>
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

  @override
  Widget build(BuildContext context) {
    final positions = <_RiderPin>[];
    for (final rider in widget.riders) {
      final t = _telemetryFor(rider.id);
      if (t == null) continue;
      positions.add(
        _RiderPin(
          lat: t.lat,
          lng: t.lng,
          color: StatusPill.colorForRider(rider.status),
          emergency: rider.status == RiderStatus.emergency,
        ),
      );
    }

    return DashPanel(
      title: 'Live fleet map',
      trailing: Text(
        '${positions.length} helmets',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10),
      ),
      contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _FleetMapPainter(pins: positions, pulse: _pulse),
              size: Size.infinite,
            ),
            const Positioned(top: 8, right: 8, child: _ZoomControls()),
            const Positioned(bottom: 8, left: 8, child: _MapLegend()),
            Positioned(
              bottom: 8,
              right: 8,
              child: Text(
                'Mock basemap — live tiles in Phase 5 · '
                'Last sync ${_clock(widget.lastSync)}',
                style: TextStyle(
                  color: NovaColors.secondaryText.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  HelmetTelemetry? _telemetryFor(String riderId) {
    for (final t in widget.telemetry) {
      if (t.riderId == riderId) return t;
    }
    return null;
  }

  static String _clock(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
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

class _RiderPin {
  final double lat;
  final double lng;
  final Color color;
  final bool emergency;

  const _RiderPin({
    required this.lat,
    required this.lng,
    required this.color,
    required this.emergency,
  });
}

class _FleetMapPainter extends CustomPainter {
  final List<_RiderPin> pins;
  final Animation<double> pulse;

  _FleetMapPainter({required this.pins, required this.pulse})
      : super(repaint: pulse);

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
      final anchor = _project(district.lat, district.lng, size);
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

  void _paintPins(Canvas canvas, Size size) {
    for (final pin in pins) {
      final center = _project(pin.lat, pin.lng, size);

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

      canvas.drawCircle(center, 3.5, Paint()..color = pin.color);
    }
  }

  Offset _scale(Offset normalized, Size size) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  /// (lat, lng) → canvas, with north at the top. The window is fixed, so a
  /// dot's drift across the panel matches its drift across the city.
  Offset _project(double lat, double lng, Size size) {
    final x = (lng - kFleetLngMin) / (kFleetLngMax - kFleetLngMin);
    final y = 1 - (lat - kFleetLatMin) / (kFleetLatMax - kFleetLatMin);
    return Offset(
      (x * size.width).clamp(0.0, size.width),
      (y * size.height).clamp(0.0, size.height),
    );
  }

  @override
  bool shouldRepaint(covariant _FleetMapPainter old) => old.pins != pins;
}
