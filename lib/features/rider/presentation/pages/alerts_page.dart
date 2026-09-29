import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/nova_bottom_nav_bar.dart';

/// "Alerts" screen — shown when the SOS button is triggered, or when the
/// ALERTS tab in the bottom nav bar is selected. Explains what happens
/// when an emergency SOS is activated, plus current location and the
/// contacts that will be notified.
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  // Extra accent colors used only on this screen.
  static const _purple = Color(0xFF9B6BFF);
  static const _orange = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmergencyBanner(),
              const SizedBox(height: 24),
              _buildSectionTitle('What Will Happen'),
              const SizedBox(height: 12),
              _buildWhatWillHappenCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Current Location'),
              const SizedBox(height: 12),
              _buildCurrentLocationCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Contacts to be Notified'),
              const SizedBox(height: 12),
              _buildContactsCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 2),
    );
  }

  // ---- Top red "Emergency Alert System" banner ----
  Widget _buildEmergencyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovaColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NovaColors.red.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined, color: NovaColors.red, size: 22),
          ),
          const SizedBox(height: 12),
          const Text(
            'Emergency Alert System',
            style: TextStyle(
              color: NovaColors.red,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Activating this emergency SOS will immediately send alerts to '
            'all your emergency contacts and nearby TNVS services with your '
            'current GPS location.',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: NovaColors.primaryText,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ---- "What Will Happen" steps card ----
  Widget _buildWhatWillHappenCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          _WhatHappensTile(
            icon: Icons.sms_outlined,
            iconColor: NovaColors.cyan,
            title: 'SMS Alerts Sent',
            subtitle: 'All emergency contacts receive immediate notification',
          ),
          _WhatHappensTile(
            icon: Icons.location_on_outlined,
            iconColor: NovaColors.green,
            title: 'GPS Location Shared',
            subtitle: 'Real-time coordinates transmitted instantly',
          ),
          _WhatHappensTile(
            icon: Icons.directions_car_filled_outlined,
            iconColor: _purple,
            title: 'TNVS Services Notified',
            subtitle: 'Nearby transport services alerted for assistance',
          ),
          _WhatHappensTile(
            icon: Icons.radar,
            iconColor: _orange,
            title: 'Continuous Tracking',
            subtitle: 'Location updates every 30 seconds',
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ---- Current Location card ----
  Widget _buildCurrentLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _LocationRow(label: 'Latitude', value: '14.5995° N'),
          SizedBox(height: 12),
          _LocationRow(label: 'Longitude', value: '120.9842° E'),
          SizedBox(height: 12),
          _LocationRow(label: 'Address', value: 'EDSA, Quezon City'),
          SizedBox(height: 12),
          _LocationRow(label: 'Accuracy', value: '±5.2m', valueColor: NovaColors.green),
        ],
      ),
    );
  }

  // ---- Contacts to be Notified card ----
  Widget _buildContactsCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _ContactTile(name: 'David Chester M. Legarde (sibling)'),
          _ContactTile(name: 'Denzil P. Legarde (sibling)'),
          _ContactTile(name: 'Ralph Lluewyne U. Natal (sibling)'),
          _ContactTile(name: 'Hanz Jibriel C. Agbayani (sibling)'),
          _ContactTile(name: 'Emergency Services'),
          _ContactTile(name: 'Nearby TNVS Services'),
        ],
      ),
    );
  }
}

/// One row in the "What Will Happen" card.
class _WhatHappensTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLast;

  const _WhatHappensTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One label/value row in the Current Location card.
class _LocationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _LocationRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? NovaColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One row in the Contacts to be Notified card.
class _ContactTile extends StatelessWidget {
  final String name;

  const _ContactTile({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: NovaColors.green, size: 14),
          ),
        ],
      ),
    );
  }
}