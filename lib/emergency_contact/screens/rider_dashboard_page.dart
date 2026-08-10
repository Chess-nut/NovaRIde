import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/emergency_bottom_nav_bar.dart';
import 'rider_map_page.dart';

/// "Rider Logs / Rider Dashboard" — the Emergency Contact's home screen.
/// Shows the status of the rider they're monitoring: live stats, current
/// trip, and a recent activity log (speed, alcohol readings, ride events)
/// per the Capstone scope's Emergency Contact feature list.
class RiderDashboardPage extends StatelessWidget {
  const RiderDashboardPage({super.key});

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
              _buildRiderCard(),
              const SizedBox(height: 16),
              _buildLiveStatsRow(),
              const SizedBox(height: 24),
              _buildSectionTitle('CURRENT TRIP', showLive: true),
              const SizedBox(height: 12),
              _buildTripCard(context),
              const SizedBox(height: 24),
              _buildSectionTitle('RECENT ACTIVITY'),
              const SizedBox(height: 12),
              _buildActivityLog(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const EmergencyBottomNavBar(selectedIndex: 0),
    );
  }

  // ---- Title + bell icon ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MONITORING',
              style: TextStyle(
                color: NovaColors.primaryText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Real-time rider safety overview',
              style: TextStyle(color: NovaColors.secondaryText, fontSize: 11, letterSpacing: 0.4),
            ),
          ],
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: NovaColors.red, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Rider identity card ----
  Widget _buildRiderCard() {
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
          const CircleAvatar(
            radius: 26,
            backgroundColor: NovaColors.pink,
            child: Text(
              'JD',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deor the great',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Rider #NV-08567 · Sibling',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.circle, color: NovaColors.green, size: 7),
                SizedBox(width: 5),
                Text(
                  'RIDING',
                  style: TextStyle(
                    color: NovaColors.green,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Speed / Alcohol / Battery live stat tiles ----
  Widget _buildLiveStatsRow() {
    return const Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.speed,
            iconColor: NovaColors.cyan,
            value: '42',
            unit: 'km/h',
            label: 'SPEED',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.water_drop_outlined,
            iconColor: NovaColors.green,
            value: '0.00',
            unit: '%',
            label: 'ALCOHOL',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.battery_charging_full,
            iconColor: NovaColors.amber,
            value: '78',
            unit: '%',
            label: 'HELMET BATT.',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {bool showLive = false}) {
    return Row(
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
        if (showLive) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: NovaColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: NovaColors.red,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- Current trip summary + link to full map ----
  Widget _buildTripCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _TripMetric(value: '42', unit: 'km/h', label: 'SPEED'),
              _TripMetric(value: '8.3', unit: 'km', label: 'DISTANCE'),
              _TripMetric(value: '23:47', unit: '', label: 'DURATION'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Icon(Icons.location_on, color: NovaColors.pink, size: 15),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Makati Ave → Bonifacio Global City',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RiderMapPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: NovaColors.pink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.map_outlined, color: NovaColors.pink, size: 17),
              label: const Text(
                'VIEW LIVE MAP',
                style: TextStyle(
                  color: NovaColors.pink,
                  fontSize: 12.5,
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

  // ---- Recent ride activity log ----
  Widget _buildActivityLog() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _ActivityRow(
            icon: Icons.play_circle_outline,
            color: NovaColors.green,
            title: 'Trip Started',
            subtitle: 'Departed from Makati Ave',
            time: '8:02 AM',
          ),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 52),
          _ActivityRow(
            icon: Icons.check_circle_outline,
            color: NovaColors.cyan,
            title: 'Alcohol Check Passed',
            subtitle: 'Breath reading: 0.00%',
            time: '8:01 AM',
          ),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 52),
          _ActivityRow(
            icon: Icons.bluetooth,
            color: NovaColors.pink,
            title: 'Helmet Connected',
            subtitle: 'NV-08567 paired and active',
            time: '8:00 AM',
          ),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 52),
          _ActivityRow(
            icon: Icons.flag_outlined,
            color: NovaColors.secondaryText,
            title: 'Previous Trip Completed',
            subtitle: 'Home → Work · 12.1 km',
            time: 'Yesterday, 6:20 PM',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 10.5,
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
              fontSize: 9,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _TripMetric({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 9.5, letterSpacing: 0.4),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final bool isLast;

  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}