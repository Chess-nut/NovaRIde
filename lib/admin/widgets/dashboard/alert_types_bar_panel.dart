import 'package:flutter/material.dart';
import 'package:novaride/admin/widgets/dashboard/alert_priority_bar_panel.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/dashboard/simple_bar_chart.dart';
import 'package:novaride/shared/models/models.dart';

/// The same board split by what actually happened, rather than how urgent it is.
class AlertTypesBarPanel extends StatelessWidget {
  final Map<AlertType, int> countsByType;

  const AlertTypesBarPanel({super.key, required this.countsByType});

  /// Short forms — the full labels ("Alcohol Warning") never fit a 9px axis.
  static const _labels = {
    AlertType.crash: 'Crash',
    AlertType.sos: 'SOS',
    AlertType.alcoholWarning: 'Alcohol',
    AlertType.lowBattery: 'Battery',
  };

  static const _order = [
    AlertType.crash,
    AlertType.sos,
    AlertType.alcoholWarning,
    AlertType.lowBattery,
  ];

  @override
  Widget build(BuildContext context) {
    return DashPanel(
      title: 'Alert types',
      child: SimpleBarChart(
        values: [for (final t in _order) countsByType[t] ?? 0],
        labels: [for (final t in _order) _labels[t]!],
        barColor: AlertPriorityBarPanel.seriesColor,
      ),
    );
  }
}
