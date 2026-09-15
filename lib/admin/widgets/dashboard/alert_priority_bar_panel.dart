import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/dashboard/simple_bar_chart.dart';

/// Dispatch queue shape: how much of the board is life-critical right now.
class AlertPriorityBarPanel extends StatelessWidget {
  final Map<AlertPriority, int> countsByPriority;

  const AlertPriorityBarPanel({super.key, required this.countsByPriority});

  /// Muted blue-grey — the two bottom charts are read together, so neither
  /// gets to shout over the alert feed beside them.
  static const seriesColor = Color(0xBF5C7CFA);

  @override
  Widget build(BuildContext context) {
    return DashPanel(
      title: 'Alert priority',
      child: SimpleBarChart(
        values: [
          for (final p in AlertPriority.values) countsByPriority[p] ?? 0,
        ],
        labels: [for (final p in AlertPriority.values) p.label],
        barColor: seriesColor,
      ),
    );
  }
}
