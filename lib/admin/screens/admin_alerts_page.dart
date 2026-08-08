import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Full alert history, reusing the dashboard's feed tile.
///
/// Reads the app-scoped controller rather than the seed statics, so alerts
/// the simulation spawns show up here with the same IDs the dashboard feed
/// is showing.
class AdminAlertsPage extends StatelessWidget {
  const AdminAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = FleetScope.of(context);

    return ListenableBuilder(
      listenable: fleet,
      builder: (context, _) => _buildList(fleet.alerts),
    );
  }

  Widget _buildList(List<AlertEvent> alerts) {
    final openCount = alerts.where((a) => a.status.isOpen).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'All Alerts',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$openCount open · ${alerts.length} total',
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.map((alert) => AlertFeedTile(alert: alert)),
          ],
        ),
      ),
    );
  }
}
