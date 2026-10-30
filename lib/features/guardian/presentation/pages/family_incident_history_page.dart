import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyIncidentHistoryPage extends ConsumerWidget {
  const FamilyIncidentHistoryPage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilyRepository repo =
        repository ?? ref.watch(familyRepositoryProvider);
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
                child: StreamBuilder<List<FamilyIncident>>(
                  stream: repo.watchIncidentHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _Message(
                        title: 'History unavailable',
                        message: snapshot.error.toString(),
                        icon: Icons.cloud_off_outlined,
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: NovaColors.cyan),
                      );
                    }
                    final incidents = snapshot.data ?? const [];
                    if (incidents.isEmpty) {
                      return const _Message(
                        title: 'No incidents recorded',
                        message:
                            'Incident alerts for your linked rider will appear here.',
                        icon: Icons.history,
                      );
                    }
                    return ListView.builder(
                      itemCount: incidents.length,
                      itemBuilder: (context, index) =>
                          _IncidentCard(incident: incidents[index]),
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

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final FamilyIncident incident;

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (incident.severity.toLowerCase()) {
      'high' => NovaColors.red,
      'moderate' || 'medium' => NovaColors.amber,
      _ => NovaColors.green,
    };
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
              _formatDate(incident.timestamp),
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${incident.status} · ${incident.severity}',
          style: TextStyle(
            color: severityColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                _Detail(label: 'Location', value: incident.location),
                _Detail(label: 'Incident type', value: incident.incidentType),
                _Detail(label: 'Rider status', value: incident.riderStatus),
                _Detail(label: 'GPS', value: incident.gpsInfo),
                _Detail(
                  label: 'SOS triggered',
                  value: incident.sosTriggered ? 'Yes' : 'No',
                ),
                _Detail(
                  label: 'Rider cancelled alert',
                  value: incident.riderCancelledAlert ? 'Yes' : 'No',
                ),
                _Detail(label: 'Duration', value: incident.durationLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime timestamp) =>
      '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: NovaColors.secondaryText),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: NovaColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
