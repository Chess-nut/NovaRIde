import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "GPS / Map" screen — shows the rider's real-time location, trajectory,
/// and heading on a map, per the Capstone scope's GPS/Map Page module.
///
/// NOTE ON THE MAP RENDERING: this draws a stylized, dark-themed map with
/// a `CustomPainter` instead of embedding real Google Maps tiles. Two
/// reasons: (1) `google_maps_flutter` needs a billed Google Maps API key
/// wired into AndroidManifest.xml / Info.plist / web/index.html before it
/// renders anything — without that setup it just shows a gray box, which
/// is a common capstone-demo failure mode; (2) Google's default map tiles
/// are light-themed and would clash with NovaRide's dark UI unless a
/// custom map-style JSON is also applied. The layout below (marker,
/// heading, breadcrumb trail, HUD cards) is built so swapping the
/// `CustomPaint` for a real `GoogleMap` widget later is a drop-in
/// replacement — everything around it stays the same.
class GpsMapPage extends StatefulWidget {
  const GpsMapPage({super.key});

  @override
  State<GpsMapPage> createState() => _GpsMapPageState();
}

class _GpsMapPageState extends State<GpsMapPage> {
  // Mock live telemetry — matches the active trip shown on the Home screen
  // (Makati Ave → BGC, 42 km/h). Phase 2 replaces this with a Firebase
  // stream keyed off the NEO-6M GPS module, per Chapter 3.
  static const double _speedKmh = 42;
  static const double _headingDegrees = 48; // NE
  static const double _lat = 14.5547;
  static const double _lng = 121.0244;
  static const double _accuracyM = 4.8;
  static const String _address = 'Makati Ave, Makati City';

  bool _followMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: Stack(
        children: [
          // ---- Full-bleed stylized map ----
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPainter(heading: _headingDegrees),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const Spacer(),
                _buildFollowToggle(),
                const SizedBox(height: 12),
                _buildBottomSheet(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Back arrow + title, floating over the map ----
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NovaColors.card.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(color: NovaColors.cardBorder),
              ),
              child: const Icon(Icons.arrow_back, color: NovaColors.primaryText, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: NovaColors.card.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NovaColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: NovaColors.cyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _address,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: NovaColors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: NovaColors.green,
                      fontSize: 10,
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

  // ---- Recenter / follow-mode pill, floating above the bottom sheet ----
  Widget _buildFollowToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: GestureDetector(
          onTap: () => setState(() => _followMode = !_followMode),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _followMode ? NovaColors.cyan : NovaColors.card.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(
                color: _followMode ? NovaColors.cyan : NovaColors.cardBorder,
              ),
              boxShadow: _followMode
                  ? [BoxShadow(color: NovaColors.cyan.withValues(alpha: 0.35), blurRadius: 14)]
                  : null,
            ),
            child: Icon(
              Icons.my_location,
              color: _followMode ? Colors.black : NovaColors.secondaryText,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ---- Speed / heading / accuracy HUD + coordinates + share ----
  Widget _buildBottomSheet() {
    final cardinal = _cardinalFromDegrees(_headingDegrees);

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
                  icon: Icons.speed,
                  color: NovaColors.cyan,
                  value: _speedKmh.toStringAsFixed(0),
                  unit: 'km/h',
                  label: 'SPEED',
                ),
              ),
              Expanded(
                child: _HudStat(
                  icon: Icons.explore_outlined,
                  color: NovaColors.green,
                  value: cardinal,
                  unit: '${_headingDegrees.toStringAsFixed(0)}°',
                  label: 'HEADING',
                ),
              ),
              Expanded(
                child: _HudStat(
                  icon: Icons.gps_fixed,
                  color: NovaColors.purple,
                  value: '±${_accuracyM.toStringAsFixed(1)}',
                  unit: 'm',
                  label: 'ACCURACY',
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
                  child: _CoordLabel(label: 'LATITUDE', value: '${_lat.toStringAsFixed(4)}° N'),
                ),
                Container(width: 1, height: 28, color: NovaColors.cardBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: _CoordLabel(label: 'LONGITUDE', value: '${_lng.toStringAsFixed(4)}° E'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: NovaColors.card,
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      'Location link copied — share it with a contact',
                      style: TextStyle(color: NovaColors.primaryText),
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: NovaColors.cyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.share_location_outlined, color: NovaColors.cyan, size: 18),
              label: const Text(
                'SHARE MY LOCATION',
                style: TextStyle(
                  color: NovaColors.cyan,
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

  String _cardinalFromDegrees(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees % 360) / 45).round() % 8;
    return directions[index];
  }
}

/// Small stat block used in the HUD row (speed / heading / accuracy).
class _HudStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  final String label;

  const _HudStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 9.5,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _CoordLabel extends StatelessWidget {
  final String label;
  final String value;

  const _CoordLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 9.5,
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

/// Draws the stylized dark map: a road grid, a breadcrumb route trail, and
/// a rider marker rotated toward the current heading.
class _MapPainter extends CustomPainter {
  final double heading;

  _MapPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D1220));

    _drawRoadGrid(canvas, size);
    _drawRouteTrail(canvas, size);
    _drawRiderMarker(canvas, size);
  }

  void _drawRoadGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = NovaColors.cardBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = NovaColors.cardBorder
      ..strokeWidth = 2.5;

    // Minor grid streets.
    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }
    for (double y = 0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }

    // A couple of "major avenues" for visual interest, one of them diagonal
    // (a nod to EDSA-style arterial roads).
    canvas.drawLine(Offset(0, size.height * 0.38), Offset(size.width, size.height * 0.38), majorPaint);
    canvas.drawLine(Offset(size.width * 0.62, 0), Offset(size.width * 0.62, size.height), majorPaint);
    canvas.drawLine(
      Offset(0, size.height * 0.85),
      Offset(size.width, size.height * 0.15),
      majorPaint,
    );
  }

  void _drawRouteTrail(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx - 120, center.dy + 160)
      ..quadraticBezierTo(center.dx - 90, center.dy + 60, center.dx - 30, center.dy + 40)
      ..quadraticBezierTo(center.dx + 10, center.dy + 20, center.dx, center.dy);

    final trailPaint = Paint()
      ..color = NovaColors.cyan.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trailPaint);

    // Trip start marker.
    canvas.drawCircle(Offset(center.dx - 120, center.dy + 160), 5, Paint()..color = NovaColors.secondaryText);
  }

  void _drawRiderMarker(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Static accuracy ring.
    canvas.drawCircle(center, 34, Paint()..color = NovaColors.cyan.withValues(alpha: 0.12));
    canvas.drawCircle(center, 22, Paint()..color = NovaColors.cyan.withValues(alpha: 0.15));

    // Heading arrow, rotated toward `heading` degrees (0 = North/up).
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180);

    final arrowPaint = Paint()..color = NovaColors.cyan;
    final arrowPath = Path()
      ..moveTo(0, -14)
      ..lineTo(9, 10)
      ..lineTo(0, 4)
      ..lineTo(-9, 10)
      ..close();
    canvas.drawShadow(arrowPath, Colors.black, 4, false);
    canvas.drawPath(arrowPath, arrowPaint);
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = NovaColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => oldDelegate.heading != heading;
}