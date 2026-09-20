import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
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
/// allowed below the fold. Every panel reads the app-scoped
/// [FleetController], which is what lets a simulated crash land in all
/// six at once — and in the other pages at the same time.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  /// Below this the side-by-side grid stops being readable and the panels
  /// stack into a single scrolling column.
  static const _stackBreakpoint = 1100.0;

  /// Below this page height the six-panel grid cannot give its shortest
  /// panel the room its content needs — the donut's legend is the first to
  /// go, at about 485px — so the panels stack and scroll instead. A 720p
  /// projector minus browser chrome is about 570 and keeps the grid.
  static const _minGridHeight = 500.0;

  static const _gap = 8.0;
  static const _outerPadding = 10.0;

  @override
  Widget build(BuildContext context) {
    // The controller is owned by FleetHost — this page must never dispose it.
    final fleet = FleetScope.of(context);

    return ListenableBuilder(
      listenable: fleet,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < _stackBreakpoint ||
                constraints.maxHeight < _minGridHeight;
            return Padding(
              padding: const EdgeInsets.all(_outerPadding),
              child: stacked ? _buildStacked(fleet) : _buildGrid(fleet),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------ desktop grid

  Widget _buildGrid(FleetController fleet) {
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
                    Expanded(flex: 5, child: _donutPanel(fleet)),
                    const SizedBox(height: _gap),
                    Expanded(flex: 4, child: _areaPanel(fleet)),
                  ],
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(flex: 73, child: _mapPanel(fleet)),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(flex: 27, child: _feedPanel(fleet)),
              const SizedBox(width: _gap),
              Expanded(flex: 36, child: _priorityPanel(fleet)),
              const SizedBox(width: _gap),
              Expanded(flex: 37, child: _typesPanel(fleet)),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------- narrow fallback

  /// Fixed heights because a scrolling column has no viewport to divide up.
  Widget _buildStacked(FleetController fleet) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 260, child: _donutPanel(fleet)),
          const SizedBox(height: _gap),
          SizedBox(height: 220, child: _areaPanel(fleet)),
          const SizedBox(height: _gap),
          SizedBox(height: 420, child: _mapPanel(fleet)),
          const SizedBox(height: _gap),
          SizedBox(height: 320, child: _feedPanel(fleet)),
          const SizedBox(height: _gap),
          SizedBox(height: 240, child: _priorityPanel(fleet)),
          const SizedBox(height: _gap),
          SizedBox(height: 240, child: _typesPanel(fleet)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- panels

  Widget _donutPanel(FleetController fleet) =>
      FleetStatusDonutPanel(counts: fleet.statusCounts);

  Widget _areaPanel(FleetController fleet) =>
      AlertsByAreaBarPanel(countsByArea: fleet.alertsByArea);

  Widget _mapPanel(FleetController fleet) => LiveFleetMapPanel(
        riders: fleet.riders,
        telemetry: fleet.telemetry,
        lastSync: fleet.lastSync,
      );

  Widget _feedPanel(FleetController fleet) =>
      RecentAlertsFeedPanel(alerts: fleet.alerts);

  Widget _priorityPanel(FleetController fleet) =>
      AlertPriorityBarPanel(countsByPriority: fleet.alertsByPriority);

  Widget _typesPanel(FleetController fleet) =>
      AlertTypesBarPanel(countsByType: fleet.alertsByType);
}
