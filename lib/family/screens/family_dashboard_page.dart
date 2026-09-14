import 'package:flutter/material.dart';
import 'package:novaride/family/data/family_repository.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/family/widgets/family_status_badge.dart';
import 'package:novaride/shared/theme.dart';

class FamilyDashboardPage extends StatelessWidget {
  const FamilyDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FamilyRepository();

    return StreamBuilder<FamilyConnectedRider>(
      stream: repo.watchRiderStatus(),
      initialData: repo.connectedRider,
      builder: (context, snapshot) {
        final rider = snapshot.data ?? repo.connectedRider;

        return Scaffold(
          backgroundColor: NovaColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildConnectedRiderCard(rider),
                  const SizedBox(height: 18),
                  _buildStatusCard(rider),
                  const SizedBox(height: 24),
                  const FamilySectionTitle(label: 'CURRENT TRIP'),
                  const SizedBox(height: 12),
                  _buildTripCard(rider),
                  const SizedBox(height: 24),
                  const FamilySectionTitle(label: 'LIVE LOCATION', showLiveBadge: true),
                  const SizedBox(height: 12),
                  _buildLiveLocationCard(rider, context),
                  const SizedBox(height: 24),
                  const FamilySectionTitle(label: 'HELMET STATUS'),
                  const SizedBox(height: 12),
                  _buildHelmetStatusCard(rider),
                  const SizedBox(height: 24),
                  const FamilySectionTitle(label: 'SAFETY SUMMARY'),
                  const SizedBox(height: 12),
                  _buildSafetySummaryCard(rider),
                ],
              ),
            ),
          ),
          bottomNavigationBar: FamilyBottomNavBar(
            selectedIndex: 0,
            showAlertBadge: repo.hasActiveEmergency,
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Family Safety',
          style: TextStyle(
            color: NovaColors.primaryText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Icon(Icons.notifications_none, color: Colors.white, size: 24),
      ],
    );
  }

  Widget _buildConnectedRiderCard(FamilyConnectedRider rider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: NovaColors.cyan,
            child: Text(
              rider.avatarLetters,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rider.relationship,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FamilyStatusBadge(
            status: rider.status,
            isCompact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(FamilyConnectedRider rider) {
    final status = rider.status;
    final color = status.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rider Status',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: color, size: 14),
              const SizedBox(width: 10),
              Text(
                status.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: ${rider.lastUpdatedSeconds} seconds ago',
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(FamilyConnectedRider rider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rider.isCurrentlyRiding ? 'Currently Riding' : 'Currently Safe',
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(label: 'Speed', value: '${rider.speedKmh.toInt()} km/h'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(label: 'Trip Duration', value: '${rider.tripDurationMinutes} min'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: NovaColors.cyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rider.destination,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLocationCard(FamilyConnectedRider rider, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF0E1D2E),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapGridPainter(),
                  ),
                ),
                Positioned(
                  left: 170,
                  top: 54,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: NovaColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current location',
                        style: TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rider.address,
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/family-map');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Open Live Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelmetStatusCard(FamilyConnectedRider rider) {
    final rows = <_StatusRowData>[
      _StatusRowData('Helmet', rider.helmetConnected ? 'Connected' : 'Disconnected', NovaColors.green),
      _StatusRowData('GPS', rider.gpsActive ? 'Active' : 'Inactive', NovaColors.cyan),
      _StatusRowData('Internet', rider.internetConnected ? 'Connected' : 'Offline', NovaColors.green),
      _StatusRowData('Battery', '${rider.batteryPct}%', NovaColors.amber),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: rows.map((row) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                row.value,
                style: TextStyle(
                  color: row.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSafetySummaryCard(FamilyConnectedRider rider) {
    final rows = <_StatusRowData>[
      _StatusRowData('Impact', rider.impactNormal ? 'Normal' : 'High', rider.impactNormal ? NovaColors.green : NovaColors.red),
      _StatusRowData('Alcohol', rider.alcoholSafe ? 'Safe' : 'Warning', rider.alcoholSafe ? NovaColors.green : NovaColors.amber),
      _StatusRowData('GPS', rider.gpsLocked ? 'Locked' : 'Lost', rider.gpsLocked ? NovaColors.green : NovaColors.red),
      _StatusRowData('Helmet', rider.helmetConnected ? 'Connected' : 'Disconnected', rider.helmetConnected ? NovaColors.green : NovaColors.red),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: rows.map((row) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                row.value,
                style: TextStyle(
                  color: row.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: NovaColors.primaryText,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _StatusRowData {
  final String label;
  final String value;
  final Color color;

  const _StatusRowData(this.label, this.value, this.color);
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path();
    path.moveTo(0, 110);
    path.quadraticBezierTo(size.width * 0.25, 90, size.width * 0.45, 130);
    path.quadraticBezierTo(size.width * 0.7, 170, size.width, 110);
    canvas.drawPath(path, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
