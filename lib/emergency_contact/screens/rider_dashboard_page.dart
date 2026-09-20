import 'package:flutter/material.dart';
import 'package:novaride/emergency_contact/data/emergency_contact_repository.dart';
import 'package:novaride/emergency_contact/models/emergency_contact_models.dart';
import 'package:novaride/emergency_contact/screens/emergency_alert_page.dart';
import 'package:novaride/emergency_contact/screens/incident_history_page.dart';
import 'package:novaride/emergency_contact/screens/rider_map_page.dart';
import 'package:novaride/emergency_contact/widgets/emergency_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class RiderDashboardPage extends StatelessWidget {
  const RiderDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = EmergencyContactRepository();
    return StreamBuilder<ConnectedRider>(
      stream: repository.watchRiderStatus(),
      initialData: repository.connectedRider,
      builder: (context, snapshot) {
        final rider = snapshot.data ?? repository.connectedRider;
        return Scaffold(
          backgroundColor: NovaColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MONITORING', style: TextStyle(color: NovaColors.primaryText, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  const Text('Connected rider safety overview', style: TextStyle(color: NovaColors.secondaryText, fontSize: 11, letterSpacing: 0.4)),
                  const SizedBox(height: 20),
                  _RiderCard(rider: rider),
                  const SizedBox(height: 16),
                  _StatusCard(rider: rider),
                  const SizedBox(height: 16),
                  _TelemetryCard(rider: rider),
                  const SizedBox(height: 24),
                  const Text('QUICK ACTIONS', style: TextStyle(color: NovaColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _ActionButton(label: 'VIEW LIVE LOCATION', icon: Icons.map_outlined, color: NovaColors.cyan, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RiderMapPage()))),
                  const SizedBox(height: 10),
                  _ActionButton(label: 'VIEW EMERGENCY ALERT', icon: Icons.warning_amber_outlined, color: NovaColors.red, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyAlertPage()))),
                  const SizedBox(height: 10),
                  _ActionButton(label: 'VIEW INCIDENT HISTORY', icon: Icons.history_outlined, color: NovaColors.amber, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncidentHistoryPage()))),
                  const SizedBox(height: 24),
                  const Text('RECENT STATUS', style: TextStyle(color: NovaColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _RecentStatus(rider: rider),
                ],
              ),
            ),
          ),
          bottomNavigationBar: EmergencyBottomNavBar(selectedIndex: 0, showAlertBadge: repository.hasActiveEmergency),
        );
      },
    );
  }
}

class _RiderCard extends StatelessWidget {
  final ConnectedRider rider;
  const _RiderCard({required this.rider});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: NovaColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: NovaColors.cardBorder)),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: NovaColors.pink, child: Text(rider.avatarLetters, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rider.name, style: const TextStyle(color: NovaColors.primaryText, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(rider.relationship, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12)),
          ])),
          _StatusPill(status: rider.status),
        ]),
      );
}

class _StatusCard extends StatelessWidget {
  final ConnectedRider rider;
  const _StatusCard({required this.rider});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: rider.status.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: rider.status.color.withValues(alpha: 0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CURRENT SAFETY', style: TextStyle(color: rider.status.color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(children: [Icon(Icons.circle, color: rider.status.color, size: 13), const SizedBox(width: 9), Text(rider.status.label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          Text('Last updated ${rider.lastUpdatedSeconds} seconds ago', style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12)),
        ]),
      );
}

class _TelemetryCard extends StatelessWidget {
  final ConnectedRider rider;
  const _TelemetryCard({required this.rider});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: NovaColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: NovaColors.cardBorder)),
        child: Column(children: [
          _TelemetryRow(icon: Icons.location_on_outlined, label: 'CURRENT LOCATION', value: rider.address, color: NovaColors.green),
          _TelemetryRow(icon: Icons.speed, label: 'CURRENT SPEED', value: '${rider.speedKmh.toStringAsFixed(0)} km/h', color: NovaColors.cyan),
          _TelemetryRow(icon: Icons.sports_motorsports_outlined, label: 'HELMET', value: rider.helmetConnected ? 'CONNECTED' : 'DISCONNECTED', color: rider.helmetConnected ? NovaColors.green : NovaColors.red),
          _TelemetryRow(icon: Icons.gps_fixed, label: 'GPS / CONNECTION', value: rider.gpsActive && rider.internetConnected ? 'ACTIVE' : 'OFFLINE', color: rider.gpsActive && rider.internetConnected ? NovaColors.green : NovaColors.red),
        ]),
      );
}

class _TelemetryRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _TelemetryRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11, letterSpacing: 0.4))),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _RecentStatus extends StatelessWidget {
  final ConnectedRider rider;
  const _RecentStatus({required this.rider});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: NovaColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: NovaColors.cardBorder)),
        child: Row(children: [
          Icon(rider.impactNormal ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: rider.impactNormal ? NovaColors.green : NovaColors.red),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rider.impactNormal ? 'Safety systems normal' : 'Safety warning detected', style: const TextStyle(color: NovaColors.primaryText, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(rider.alcoholSafe ? 'Helmet and alcohol checks are clear.' : 'Alcohol warning requires attention.', style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5)),
          ])),
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  final RiderStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: status.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(status.label, style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 18),
          label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.7)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        ),
      );
}
