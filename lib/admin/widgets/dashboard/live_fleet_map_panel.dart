import 'package:flutter/material.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/fleet_map_view.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// The dashboard's centrepiece: [FleetMapView] wrapped in panel chrome.
///
/// The map itself lives in [FleetMapView] so the Rider Monitoring page draws
/// the identical basemap and dots rather than a second copy of the painter.
/// This panel is read-only — selection belongs to the monitoring page.
class LiveFleetMapPanel extends StatelessWidget {
  final List<Rider> riders;
  final List<HelmetTelemetry> telemetry;
  final DateTime lastSync;

  const LiveFleetMapPanel({
    super.key,
    required this.riders,
    required this.telemetry,
    required this.lastSync,
  });

  @override
  Widget build(BuildContext context) {
    final plotted = riders
        .where((r) => telemetry.any((t) => t.riderId == r.id))
        .length;

    return DashPanel(
      title: 'Live fleet map',
      trailing: Text(
        '$plotted helmets',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10),
      ),
      contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FleetMapView(riders: riders, telemetry: telemetry),
          Positioned(
            bottom: 8,
            right: 8,
            child: Text(
              'Mock basemap — live tiles in Phase 5 · '
              'Last sync ${_clock(lastSync)}',
              style: TextStyle(
                color: NovaColors.secondaryText.withValues(alpha: 0.8),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
