import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/emergency_bottom_nav_bar.dart';

/// "GPS/Map Page" — also covers "Real-Time Tracking" from the Capstone
/// scope. Both bullets describe the same capability (an emergency
/// contact watching a rider's live position on a map), so rather than
/// build two near-identical screens, this one screen fulfills both —
/// flagged in the accompanying chat message.
///
/// Static/hardcoded for now, same stylized dark map approach as the
/// rider-side GPS page (no Google Maps API key required to demo).
class RiderMapPage extends StatelessWidget {
  const RiderMapPage({super.key});

  // Mock live telemetry for the monitored rider.
  static const double _speedKmh = 42;
  static const double _headingDegrees = 48; // NE
  static const double _lat = 14.5547;
  static const double _lng = 121.0244;
  static const String _address = 'Makati Ave, Makati City';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: Stack(
        children: [
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
                _buildBottomSheet(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EmergencyBottomNavBar(selectedIndex: 1),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        children: [
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
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: NovaColors.pink,
                    child: Text(
                      'JD',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "'Deor the great'",
                          style: TextStyle(
                            color: NovaColors.primaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _address,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10.5),
                        ),
                      ],
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

  Widget _buildBottomSheet(BuildContext context) {
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
              decoration: BoxDecoration(color: NovaColors.cardBorder, borderRadius: BorderRadius.circular(2)),
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
                  icon: Icons.water_drop_outlined,
                  color: NovaColors.amber,
                  value: '0.00',
                  unit: '%',
                  label: 'ALCOHOL',
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
                Expanded(child: _CoordLabel(label: 'LATITUDE', value: '${_lat.toStringAsFixed(4)}° N')),
                Container(width: 1, height: 28, color: NovaColors.cardBorder),
                const SizedBox(width: 12),
                Expanded(child: _CoordLabel(label: 'LONGITUDE', value: '${_lng.toStringAsFixed(4)}° E')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: NovaColors.card,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            'Calling Juan dela Cruz…',
                            style: TextStyle(color: NovaColors.primaryText),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: NovaColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.call_outlined, color: NovaColors.primaryText, size: 17),
                    label: const Text(
                      'CALL',
                      style: TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NovaColors.pink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.directions_outlined, color: Colors.white, size: 17),
                    label: const Text(
                      'DIRECTIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
                style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 9.5, letterSpacing: 0.6)),
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
        Text(label, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 9.5, letterSpacing: 0.6)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: NovaColors.primaryText, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Same stylized map painter approach as the rider-side GPS page — road
/// grid, breadcrumb trail, heading-rotated marker — recolored pink to
/// signal "this is someone else's location," not the viewer's own.
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

    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }
    for (double y = 0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }

    canvas.drawLine(Offset(0, size.height * 0.38), Offset(size.width, size.height * 0.38), majorPaint);
    canvas.drawLine(Offset(size.width * 0.62, 0), Offset(size.width * 0.62, size.height), majorPaint);
    canvas.drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.15), majorPaint);
  }

  void _drawRouteTrail(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx - 120, center.dy + 160)
      ..quadraticBezierTo(center.dx - 90, center.dy + 60, center.dx - 30, center.dy + 40)
      ..quadraticBezierTo(center.dx + 10, center.dy + 20, center.dx, center.dy);

    final trailPaint = Paint()
      ..color = NovaColors.pink.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trailPaint);
    canvas.drawCircle(Offset(center.dx - 120, center.dy + 160), 5, Paint()..color = NovaColors.secondaryText);
  }

  void _drawRiderMarker(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(center, 34, Paint()..color = NovaColors.pink.withValues(alpha: 0.12));
    canvas.drawCircle(center, 22, Paint()..color = NovaColors.pink.withValues(alpha: 0.15));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180);

    final arrowPaint = Paint()..color = NovaColors.pink;
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