import 'package:flutter/material.dart';
import 'package:novaride/family/data/family_repository.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyIncidentHistoryPage extends StatelessWidget {
  const FamilyIncidentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final incidents = FamilyRepository().incidentHistory;

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Incident History',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final incident = incidents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NovaColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: NovaColors.cardBorder),
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        collapsedIconColor: NovaColors.secondaryText,
                        iconColor: NovaColors.cyan,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incident.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${incident.timestamp.day}/${incident.timestamp.month}/${incident.timestamp.year}',
                              style: const TextStyle(
                                color: NovaColors.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          incident.status,
                          style: TextStyle(
                            color: incident.status == 'Warning' ? NovaColors.amber : NovaColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                _HistoryDetailRow(label: 'Time', value: '${incident.timestamp.hour}:${incident.timestamp.minute.toString().padLeft(2, '0')}'),
                                _HistoryDetailRow(label: 'Location', value: incident.location),
                                _HistoryDetailRow(label: 'Incident Type', value: incident.incidentType),
                                _HistoryDetailRow(label: 'Severity', value: incident.severity),
                                _HistoryDetailRow(label: 'Rider Status', value: incident.riderStatus),
                                _HistoryDetailRow(label: 'GPS', value: incident.gpsInfo),
                                _HistoryDetailRow(label: 'SOS Triggered', value: incident.sosTriggered ? 'Yes' : 'No'),
                                _HistoryDetailRow(label: 'Rider Cancelled Alert', value: incident.riderCancelledAlert ? 'Yes' : 'No'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 3),
    );
  }
}

class _HistoryDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
