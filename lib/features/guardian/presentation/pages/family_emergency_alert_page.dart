import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyEmergencyAlertPage extends ConsumerWidget {
  const FamilyEmergencyAlertPage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilyRepository repo =
        repository ?? ref.watch(familyRepositoryProvider);
    return StreamBuilder<FamilyIncident?>(
      stream: repo.watchActiveEmergency(),
      builder: (context, snapshot) {
        final incident = snapshot.data;
        return Scaffold(
          backgroundColor: incident == null
              ? NovaColors.background
              : const Color(0xFF1B0D12),
          body: SafeArea(
            child: switch ((snapshot.connectionState, snapshot.hasError, incident)) {
              (_, true, _) => _MessageState(
                title: 'Alerts unavailable',
                message: snapshot.error.toString(),
                icon: Icons.cloud_off_outlined,
              ),
              (ConnectionState.waiting, false, _) => const Center(
                child: CircularProgressIndicator(color: NovaColors.cyan),
              ),
              (_, false, null) => const _NoActiveAlert(),
              (_, false, final alert?) => _AlertDetails(incident: alert),
            },
          ),
          bottomNavigationBar: FamilyBottomNavBar(
            selectedIndex: 2,
            showAlertBadge: incident != null,
          ),
        );
      },
    );
  }
}

class _NoActiveAlert extends StatelessWidget {
  const _NoActiveAlert();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_outlined, color: NovaColors.green, size: 44),
          const SizedBox(height: 14),
          const Text(
            'No active emergency',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Active alerts for your linked rider will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NovaColors.secondaryText),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go(AppRoutes.guardianHistoryPath),
            child: const Text('View alert history'),
          ),
        ],
      ),
    ),
  );
}

class _AlertDetails extends StatelessWidget {
  const _AlertDetails({required this.incident});

  final FamilyIncident incident;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(AppRoutes.guardianHomePath),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'EMERGENCY ALERT',
                  style: TextStyle(
                    color: NovaColors.red,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            incident.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NovaColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  incident.status.toUpperCase(),
                  style: const TextStyle(
                    color: NovaColors.red,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Incident', value: incident.incidentType),
                _InfoRow(label: 'Severity', value: incident.severity),
                _InfoRow(label: 'Location', value: incident.location),
                _InfoRow(label: 'Time', value: _formatTime(incident.timestamp)),
                _InfoRow(label: 'GPS', value: incident.gpsInfo),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'This app does not contact emergency services automatically. If someone may be in danger, contact local emergency services using your phone.',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.guardianMapPath),
              icon: const Icon(Icons.map_outlined),
              label: const Text('VIEW LIVE LOCATION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.cyan,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.guardianHistoryPath),
              child: const Text('VIEW ALERT HISTORY'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
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
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: NovaColors.amber),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NovaColors.secondaryText),
          ),
        ],
      ),
    ),
  );
}
