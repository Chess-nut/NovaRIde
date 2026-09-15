import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/dashboard/simple_bar_chart.dart';
import 'package:novaride/shared/theme.dart';

/// Alert load per coverage district. Each alert is bucketed by the district
/// centre it sits closest to, so the bars follow the map, not a lookup table.
class AlertsByAreaBarPanel extends StatelessWidget {
  final Map<String, int> countsByArea;

  const AlertsByAreaBarPanel({super.key, required this.countsByArea});

  @override
  Widget build(BuildContext context) {
    return DashPanel(
      title: 'Alerts by area',
      child: SimpleBarChart(
        values: [for (final d in kFleetDistricts) countsByArea[d.name] ?? 0],
        labels: [for (final d in kFleetDistricts) d.shortLabel],
        barColor: NovaColors.cyan,
        showYAxisLabels: false,
      ),
    );
  }
}
