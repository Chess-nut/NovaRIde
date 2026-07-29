import 'package:flutter/material.dart';
import 'package:novaride/admin/state/mock_fleet_controller.dart';
import 'package:novaride/admin/widgets/dashboard/alert_priority_bar_panel.dart';
import 'package:novaride/admin/widgets/dashboard/alert_types_bar_panel.dart';
import 'package:novaride/admin/widgets/dashboard/alerts_by_area_bar_panel.dart';
import 'package:novaride/admin/widgets/dashboard/fleet_status_donut_panel.dart';
import 'package:novaride/admin/widgets/dashboard/live_fleet_map_panel.dart';
import 'package:novaride/admin/widgets/dashboard/recent_alerts_feed_panel.dart';

/// Fleet overview — the centrepiece of the operations console.
///
/// A dense panel grid around one large map, sized to the viewport rather than
/// scrolled: an operator watches this all shift, so nothing important is
/// allowed below the fold. Every panel reads from one [MockFleetController],
/// which is what lets a simulated crash land in all six at once.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final MockFleetController _fleet = MockFleetController();

  /// Below this the side-by-side grid stops being readable and the panels
  /// stack into a single scrolling column.
  static const _stackBreakpoint = 1100.0;

  static const _gap = 8.0;
  static const _outerPadding = 10.0;

  @override
  void dispose() {
    _fleet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _fleet,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < _stackBreakpoint;
            return Padding(
              padding: const EdgeInsets.all(_outerPadding),
              child: stacked ? _buildStacked() : _buildGrid(),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------ desktop grid

  Widget _buildGrid() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                flex: 27,
                child: Column(
                  children: [
                    Expanded(flex: 5, child: _donutPanel()),
                    const SizedBox(height: _gap),
                    Expanded(flex: 4, child: _areaPanel()),
                  ],
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(flex: 73, child: _mapPanel()),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(flex: 27, child: _feedPanel()),
              const SizedBox(width: _gap),
              Expanded(flex: 36, child: _priorityPanel()),
              const SizedBox(width: _gap),
              Expanded(flex: 37, child: _typesPanel()),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------- narrow fallback

  /// Fixed heights because a scrolling column has no viewport to divide up.
  Widget _buildStacked() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 260, child: _donutPanel()),
          const SizedBox(height: _gap),
          SizedBox(height: 220, child: _areaPanel()),
          const SizedBox(height: _gap),
          SizedBox(height: 420, child: _mapPanel()),
          const SizedBox(height: _gap),
          SizedBox(height: 320, child: _feedPanel()),
          const SizedBox(height: _gap),
          SizedBox(height: 240, child: _priorityPanel()),
          const SizedBox(height: _gap),
          SizedBox(height: 240, child: _typesPanel()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- panels

  Widget _donutPanel() => FleetStatusDonutPanel(counts: _fleet.statusCounts);

  Widget _areaPanel() => AlertsByAreaBarPanel(countsByArea: _fleet.alertsByArea);

  Widget _mapPanel() => LiveFleetMapPanel(
        riders: _fleet.riders,
        telemetry: _fleet.telemetry,
        lastSync: _fleet.lastSync,
      );

  Widget _feedPanel() => RecentAlertsFeedPanel(alerts: _fleet.alerts);

  Widget _priorityPanel() =>
      AlertPriorityBarPanel(countsByPriority: _fleet.alertsByPriority);

  Widget _typesPanel() => AlertTypesBarPanel(countsByType: _fleet.alertsByType);
}
