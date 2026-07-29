import 'package:flutter/material.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/fleet_table.dart';
import 'package:novaride/admin/widgets/kpi_card.dart';
import 'package:novaride/admin/widgets/weekly_alerts_chart.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Fleet overview — the centrepiece of the operations console.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final riders = MockData.riders;
    final telemetry = MockData.telemetry;
    final alerts = MockData.alerts;

    /* Every KPI is derived from the mock data, never hardcoded. */
    final activeRiders = riders
        .where((r) => r.status == RiderStatus.riding || r.status == RiderStatus.emergency)
        .length;
    final helmetsOnline = riders.where((r) => r.status != RiderStatus.offline).length;
    final openAlerts = alerts.where((a) => a.status.isOpen).length;

    final movingSpeeds =
        telemetry.where((t) => t.speedKmh > 0).map((t) => t.speedKmh).toList();
    final avgSpeed = movingSpeeds.isEmpty
        ? 0.0
        : movingSpeeds.reduce((a, b) => a + b) / movingSpeeds.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiRow(
            activeRiders: activeRiders,
            helmetsOnline: helmetsOnline,
            totalRiders: riders.length,
            openAlerts: openAlerts,
            avgSpeed: avgSpeed,
          ),
          const SizedBox(height: 20),
          _buildMainGrid(riders, alerts),
          const SizedBox(height: 20),
          _buildWeeklyChartCard(),
        ],
      ),
    );
  }

  Widget _buildKpiRow({
    required int activeRiders,
    required int helmetsOnline,
    required int totalRiders,
    required int openAlerts,
    required double avgSpeed,
  }) {
    final cards = [
      KpiCard(
        label: 'Active Riders',
        value: '$activeRiders',
        caption: 'currently on a trip',
        icon: Icons.two_wheeler,
        accent: NovaColors.green,
      ),
      KpiCard(
        label: 'Helmets Online',
        value: '$helmetsOnline',
        caption: 'of $totalRiders registered helmets',
        icon: Icons.sensors,
      ),
      KpiCard(
        label: 'Open Alerts',
        value: '$openAlerts',
        caption: openAlerts > 0 ? 'awaiting dispatch' : 'nothing pending',
        icon: Icons.warning_amber_rounded,
        alarmed: openAlerts > 0,
      ),
      KpiCard(
        label: 'Avg Fleet Speed',
        value: '${avgSpeed.toStringAsFixed(1)} km/h',
        caption: 'riders in motion',
        icon: Icons.speed,
        accent: NovaColors.pink,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        /* Two-up on narrow windows so the numbers never squeeze. */
        final columns = constraints.maxWidth < 1000 ? 2 : 4;
        const gap = 16.0;
        final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }

  Widget _buildMainGrid(List<Rider> riders, List<AlertEvent> alerts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1000;

        final left = _panel(
          title: 'Live Fleet',
          trailing: Text(
            '${riders.length} helmets',
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
          ),
          child: FleetTable(riders: riders),
        );

        final right = Column(
          children: [
            _buildMapPlaceholder(),
            const SizedBox(height: 16),
            _panel(
              title: 'Emergency Alerts',
              trailing: Text(
                '${alerts.where((a) => a.status.isOpen).length} open',
                style: const TextStyle(color: NovaColors.red, fontSize: 12),
              ),
              child: Column(
                children: [
                  for (final alert in alerts.take(4)) AlertFeedTile(alert: alert),
                ],
              ),
            ),
          ],
        );

        if (stacked) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: left),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: right),
          ],
        );
      },
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NovaColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.map_outlined, color: NovaColors.cyan, size: 25),
          ),
          const SizedBox(height: 14),
          const Text(
            'Live GPS map',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'integrated in Phase 5',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChartCard() {
    return _panel(
      title: 'Alerts this week',
      trailing: Text(
        '${MockData.alertsThisWeek.reduce((a, b) => a + b)} total',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
      ),
      child: WeeklyAlertsChart(
        values: MockData.alertsThisWeek,
        labels: MockData.weekdayLabels,
      ),
    );
  }

  Widget _panel({required String title, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Text(
                title,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
