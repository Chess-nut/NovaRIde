import 'package:flutter/material.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/fleet_map_view.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// The dashboard's centrepiece: [FleetMapView] wrapped in panel chrome.
///
/// The map itself lives in [FleetMapView] so Rider Monitoring draws the
/// identical map. Here it is fully interactive — pan, zoom, popups — but
/// does not select: "View rider" in a popup switches the console to Rider
/// Monitoring with that rider selected ([onViewRider]).
class LiveFleetMapPanel extends StatelessWidget {
  final List<Rider> riders;
  final List<HelmetTelemetry> telemetry;
  final DateTime lastSync;
  final List<AlertEvent> alerts;
  final RiderStatus Function(Rider rider)? statusOf;
  final ValueChanged<String>? onViewRider;
  final ValueChanged<AlertEvent>? onAlertTap;

  /// The simulation says so on the map; live data needs no caption.
  final FleetSource source;

  const LiveFleetMapPanel({
    super.key,
    required this.riders,
    required this.telemetry,
    required this.lastSync,
    this.alerts = const [],
    this.statusOf,
    this.onViewRider,
    this.onAlertTap,
    this.source = FleetSource.firestore,
  });

  /// "1 helmet", "3 helmets".
  static String helmetCount(int n) => n == 1 ? '1 helmet' : '$n helmets';

  @override
  Widget build(BuildContext context) {
    // Same rule as the map's markers: a rider's helmet or an unassigned
    // one, and only with a position.
    final riderIds = {for (final r in riders) r.id};
    final plotted = telemetry
        .where(
          (t) =>
              t.lat != null &&
              t.lng != null &&
              (t.riderId == null
                  ? t.deviceId != null
                  : riderIds.contains(t.riderId)),
        )
        .length;

    return DashPanel(
      title: 'Live fleet map',
      trailing: Tooltip(
        message: 'Last update received ${_clock(lastSync)}',
        child: Text(
          helmetCount(plotted),
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10),
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: FleetMapView(
        riders: riders,
        telemetry: telemetry,
        alerts: alerts,
        statusOf: statusOf,
        onViewRider: onViewRider,
        onAlertTap: onAlertTap,
        note: source == FleetSource.simulation
            ? 'Simulated GPS — not live helmet data · '
                  'synced ${_clock(lastSync)}'
            : null,
      ),
    );
  }

  static String _clock(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
