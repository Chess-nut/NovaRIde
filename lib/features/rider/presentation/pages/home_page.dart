import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import 'alerts_page.dart';
import 'gps_map_page.dart';
import 'notification_feed_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildProfileCard(),
              const SizedBox(height: 16),
              _buildQuickStatsRow(),
              const SizedBox(height: 16),
              _buildCircleStatsRow(context),
              const SizedBox(height: 24),
              _buildSectionTitle('CURRENT TRIP', showLive: true),
              const SizedBox(height: 12),
              _buildTripCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('EMERGENCY SOS'),
              const SizedBox(height: 20),
              _buildSosButton(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 0),
    );
  }

  // ---- Top app title + notification bell ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
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
              'SMART HELMET SYSTEM V4.2',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationFeedPage()),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.white, size: 26),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: NovaColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Rider profile card with avatar + connection status ----
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: NovaColors.pink,
            child: const Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deor the great',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Rider #NV-08567',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusPill(label: 'Connected', color: NovaColors.green),
        ],
      ),
    );
  }

  // ---- Battery / Hardware / Signal row ----
  Widget _buildQuickStatsRow() {
    return Row(
      children: const [
        Expanded(
          child: _InfoCard(
            value: '78%',
            valueColor: NovaColors.green,
            label: 'BATTERY',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            value: 'ESP32',
            valueColor: NovaColors.primaryText,
            label: 'HARDWARE',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            value: '-62\ndBm',
            valueColor: NovaColors.cyan,
            label: 'SIGNAL',
            isTwoLine: true,
          ),
        ),
      ],
    );
  }

  // ---- Impact / Air quality / GPS row ----
  Widget _buildCircleStatsRow(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _CircleStatCard(
            icon: Icons.bolt,
            iconColor: NovaColors.green,
            value: '0.3G',
            label: 'IMPACT',
            statusText: 'ACTIVE',
            statusColor: NovaColors.green,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _CircleStatCard(
            icon: Icons.water_drop_outlined,
            iconColor: NovaColors.green,
            value: '0.00%',
            label: '% Alcohol',
            statusText: 'CLEAR',
            statusColor: NovaColors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CircleStatCard(
            icon: Icons.location_on_outlined,
            iconColor: NovaColors.cyan,
            value: 'GPS',
            label: 'LOCATION',
            statusText: 'ACTIVE',
            statusColor: NovaColors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GpsMapPage()),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Section header, optionally with a "LIVE" indicator ----
  Widget _buildSectionTitle(String title, {bool showLive = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        if (showLive)
          Row(
            children: const [
              Icon(Icons.circle, color: NovaColors.green, size: 8),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  color: NovaColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---- Trip speed / distance / duration + route ----
  Widget _buildTripCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: _TripMetric(value: '42', unit: 'km/h', label: 'SPEED'),
              ),
              Expanded(
                child: _TripMetric(value: '8.3', unit: 'km', label: 'DISTANCE'),
              ),
              Expanded(
                child: _TripMetric(value: '23:47', unit: 'min', label: 'DURATION'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.location_on, color: NovaColors.secondaryText, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Makati Ave → Bonifacio Global City',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Big glowing SOS button ----
  Widget _buildSosButton(BuildContext context) {
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
        child: Material(
          color: NovaColors.red,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertsPage()),
              );
            },
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
    );
  }
}

/// Small rounded "Connected" badge shown on the profile card.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

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
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Battery / Hardware / Signal card.
class _InfoCard extends StatelessWidget {
  final String value;
  final Color valueColor;
  final String label;
  final bool isTwoLine;

  const _InfoCard({
    required this.value,
    required this.valueColor,
    required this.label,
    this.isTwoLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: isTwoLine ? 2 : 1,
            style: TextStyle(
              color: valueColor,
              fontSize: isTwoLine ? 16 : 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Impact / % Clean / GPS card with an icon circle and status dot.
class _CircleStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;

  const _CircleStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.statusText,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: statusColor, size: 6),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One metric (speed / distance / duration) inside the trip card.
class _TripMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _TripMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}