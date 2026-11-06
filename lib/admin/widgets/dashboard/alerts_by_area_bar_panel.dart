import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/dashboard/simple_bar_chart.dart';
import 'package:novaride/shared/theme.dart';

/// Alert load per coverage district. An alert counts for a district only
/// when its own position is within [kDistrictRadiusKm] of that district's
/// centre; everything else — further out, or with no position at all — is
/// the last bar, "Outside", rather than quietly joining the nearest name.
class AlertsByAreaBarPanel extends StatelessWidget {
  final Map<String, int> countsByArea;

  const AlertsByAreaBarPanel({super.key, required this.countsByArea});

  @override
  Widget build(BuildContext context) {
    return DashPanel(
      title: 'Alerts by area',
      child: SimpleBarChart(
        values: [
          for (final d in kFleetDistricts) countsByArea[d.name] ?? 0,
          countsByArea[kOutsideCoverage] ?? 0,
        ],
        labels: [for (final d in kFleetDistricts) d.shortLabel, 'Outside'],
        barColor: NovaColors.cyan,
        showYAxisLabels: false,
      ),
    );
  }
}
