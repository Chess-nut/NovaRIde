import 'package:flutter/material.dart';
import 'package:novaride/emergency_contact/data/emergency_contact_repository.dart';
import 'package:novaride/emergency_contact/models/emergency_contact_models.dart';
import 'package:novaride/emergency_contact/screens/rider_map_page.dart';
import 'package:novaride/emergency_contact/widgets/emergency_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class EmergencyAlertPage extends StatelessWidget {
  const EmergencyAlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = EmergencyContactRepository();
    return StreamBuilder<ConnectedRider>(
      stream: repository.watchRiderStatus(),
      initialData: repository.connectedRider,
      builder: (context, snapshot) {
        final rider = snapshot.data ?? repository.connectedRider;
        final resolved = rider.status == RiderStatus.resolved;
        return Scaffold(
          backgroundColor: resolved ? NovaColors.background : const Color(0xFF1B0D12),
          body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [IconButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/emergency-map'), icon: const Icon(Icons.arrow_back, color: Colors.white)), Text(resolved ? 'Emergency Resolved' : 'EMERGENCY ALERT', style: TextStyle(color: resolved ? NovaColors.primaryText : NovaColors.red, fontSize: 28, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 8),
            Text(resolved ? 'The emergency has been resolved.' : '${rider.name} may need help.', style: TextStyle(color: resolved ? NovaColors.secondaryText : Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: resolved ? NovaColors.card : NovaColors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22), border: Border.all(color: resolved ? NovaColors.cardBorder : NovaColors.red.withValues(alpha: 0.4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Status', style: TextStyle(color: NovaColors.secondaryText, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 10),
              Text(resolved ? 'RESOLVED' : rider.status.label, style: TextStyle(color: resolved ? NovaColors.green : NovaColors.red, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _InfoRow('Impact', rider.impactNormal ? 'Normal' : 'High'),
              _InfoRow('Location', rider.address),
              _InfoRow('Time', rider.lastUpdated.toLocal().toString().substring(11, 16)),
              _InfoRow('GPS', '${rider.latitude.toStringAsFixed(4)}° N / ${rider.longitude.toStringAsFixed(4)}° E'),
              _InfoRow('Helmet', rider.helmetConnected ? 'Connected' : 'Disconnected'),
            ])),
            const SizedBox(height: 20),
            if (!resolved) const Text('Emergency contacts have been notified.', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            if (!resolved) ...[
              _Action('CALL RIDER', Icons.call, NovaColors.green),
              const SizedBox(height: 12),
              _Action('VIEW LIVE LOCATION', Icons.map_outlined, NovaColors.cyan, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RiderMapPage()))),
              const SizedBox(height: 12),
              _Action('CONTACT EMERGENCY SERVICES', Icons.local_hospital, NovaColors.red),
            ] else _Action('RETURN TO MAP', Icons.map_outlined, NovaColors.cyan, () => Navigator.of(context).pushReplacementNamed('/emergency-map')),
          ]))),
          bottomNavigationBar: const EmergencyBottomNavBar(selectedIndex: 2, showAlertBadge: true),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12.5, fontWeight: FontWeight.w600))), Expanded(flex: 2, child: Text(value, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)))]));
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? action;
  const _Action(this.label, this.icon, this.color, [this.action]);
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: action ?? () {}, icon: Icon(icon, color: Colors.white), label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8)), style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));
}
