import 'package:flutter/material.dart';
import 'package:novaride/family/data/family_repository.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyLiveLocationPage extends StatelessWidget {
  const FamilyLiveLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FamilyRepository();
    return StreamBuilder<FamilyConnectedRider>(
      stream: repo.watchRiderStatus(),
      initialData: repo.connectedRider,
      builder: (context, snapshot) {
        final rider = snapshot.data ?? repo.connectedRider;
        final isEmergency = rider.status == FamilyRiderStatus.accidentDetected || rider.status == FamilyRiderStatus.sosActive;

        return Scaffold(
          backgroundColor: NovaColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/family-dashboard'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Live Location',
                        style: TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: const Color(0xFF0E1D2E),
                          border: Border.all(color: NovaColors.cardBorder),
                        ),
                        child: const _MapBackground(),
                      ),
                      Positioned(
                        right: 20,
                        bottom: 110,
                        child: FloatingActionButton(
                          heroTag: 'family-center-rider',
                          backgroundColor: isEmergency ? NovaColors.red : NovaColors.cyan,
                          onPressed: () {},
                          child: const Icon(Icons.location_searching, color: Colors.black),
                        ),
                      ),
                      if (isEmergency)
                        Positioned(
                          top: 20,
                          left: 32,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: NovaColors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'EMERGENCY MODE',
                              style: TextStyle(
                                color: NovaColors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 24,
                        left: 18,
                        right: 18,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: NovaColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: NovaColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rider.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rider.isCurrentlyRiding ? '● Riding' : '● Safe',
                                      style: TextStyle(
                                        color: rider.isCurrentlyRiding ? NovaColors.green : NovaColors.secondaryText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${rider.speedKmh.toInt()} km/h',
                                      style: const TextStyle(
                                        color: NovaColors.primaryText,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rider.address,
                                      style: const TextStyle(
                                        color: NovaColors.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Updated ${rider.lastUpdatedSeconds} seconds ago',
                                      style: const TextStyle(
                                        color: NovaColors.secondaryText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: NovaColors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 1),
        );
      },
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (double x = 0; x <= size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.4, size.width * 0.55, size.height * 0.28);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.12, size.width, size.height * 0.48);
    canvas.drawPath(path, road);

    final riderPin = Paint()..color = NovaColors.green;
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.42), 18, riderPin);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.42), 7, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
