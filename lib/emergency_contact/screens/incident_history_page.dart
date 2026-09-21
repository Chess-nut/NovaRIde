import 'package:flutter/material.dart';
import 'package:novaride/emergency_contact/data/emergency_contact_repository.dart';
import 'package:novaride/emergency_contact/widgets/emergency_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class IncidentHistoryPage extends StatelessWidget {
  const IncidentHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final incidents = EmergencyContactRepository().incidentHistory;
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Incident History', style: TextStyle(color: NovaColors.primaryText, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Expanded(child: ListView.builder(itemCount: incidents.length, itemBuilder: (context, index) {
          final incident = incidents[index];
          return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: NovaColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: NovaColors.cardBorder)), child: ExpansionTile(tilePadding: EdgeInsets.zero, collapsedIconColor: NovaColors.secondaryText, iconColor: NovaColors.cyan, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(incident.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 4), Text('${incident.timestamp.day}/${incident.timestamp.month}/${incident.timestamp.year}', style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12))]), subtitle: Text(incident.status, style: TextStyle(color: incident.status == 'Warning' ? NovaColors.amber : NovaColors.green, fontWeight: FontWeight.w700, fontSize: 12)), children: [Padding(padding: const EdgeInsets.only(top: 8), child: Column(children: [
            _Row('Time', '${incident.timestamp.hour}:${incident.timestamp.minute.toString().padLeft(2, '0')}'), _Row('Location', incident.location), _Row('Incident Type', incident.incidentType), _Row('Severity', incident.severity), _Row('Rider Status', incident.riderStatus), _Row('GPS', incident.gpsInfo), _Row('SOS Triggered', incident.sosTriggered ? 'Yes' : 'No'), _Row('Rider Cancelled Alert', incident.riderCancelledAlert ? 'Yes' : 'No'),
          ]))]));
        })),
      ]))),
      bottomNavigationBar: const EmergencyBottomNavBar(selectedIndex: 3),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w600))), Expanded(flex: 2, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))]));
}
