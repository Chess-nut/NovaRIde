import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/filter_controls.dart';
import 'package:novaride/admin/widgets/fleet_map_view.dart';
import 'package:novaride/admin/widgets/fleet_table.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Live rider monitoring — the map and the roster, kept in lockstep.
///
/// Selection lives on the controller rather than in this page's state, which
/// is what lets a click on a map dot highlight the table row and vice versa
/// without either widget knowing about the other.
class RiderMonitoringPage extends StatefulWidget {
  const RiderMonitoringPage({super.key});

  @override
  State<RiderMonitoringPage> createState() => _RiderMonitoringPageState();
}

class _RiderMonitoringPageState extends State<RiderMonitoringPage> {
  /// Same breakpoint as the dashboard: below it the two panes become one
  /// scrolling column.
  static const _stackBreakpoint = 1100.0;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _stackedScrollController = ScrollController();

  /// Anchor for "Locate on map" when the layout is stacked and the map has
  /// scrolled out of view.
  final GlobalKey _mapKey = GlobalKey();

  final Set<RiderStatus> _statusFilter = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _stackedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = FleetScope.of(context);

    return ListenableBuilder(
      listenable: fleet,
      builder: (context, _) {
        final roster = _filteredRiders(fleet);
        final selected = fleet.selectedRiderId == null
            ? null
            : fleet.riderFor(fleet.selectedRiderId!);

        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < _stackBreakpoint;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: stacked
                  ? _buildStacked(fleet, roster, selected)
                  : _buildTwoPane(fleet, roster, selected),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------------- layout

  Widget _buildTwoPane(
    FleetController fleet,
    List<Rider> roster,
    Rider? selected,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 62, child: _buildMapCard(fleet)),
        const SizedBox(width: 12),
        Expanded(
          flex: 38,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildRosterCard(fleet, roster)),
              const SizedBox(height: 12),
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: _buildDetailCard(fleet, selected),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStacked(
    FleetController fleet,
    List<Rider> roster,
    Rider? selected,
  ) {
    return SingleChildScrollView(
      controller: _stackedScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 420, child: _buildMapCard(fleet)),
          const SizedBox(height: 12),
          _buildRosterCard(fleet, roster, scrollable: false),
          const SizedBox(height: 12),
          _buildDetailCard(fleet, selected),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- map

  Widget _buildMapCard(FleetController fleet) {
    final selectedId = fleet.selectedRiderId;

    return _Card(
      key: _mapKey,
      title: 'Live fleet map',
      // The map fills its card in both layouts — stacked gives it a fixed
      // 420px box, two-pane gives it the full column height.
      expandChild: true,
      trailing: Text(
        selectedId == null
            ? 'Click a dot to drill in'
            : 'Tracking ${fleet.riderFor(selectedId)?.fullName ?? selectedId}',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FleetMapView(
            riders: fleet.riders,
            telemetry: fleet.telemetry,
            selectedRiderId: selectedId,
            onRiderTap: fleet.selectRider,
            trail: selectedId == null
                ? const []
                : fleet.trailFor(selectedId),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Text(
              'Mock basemap and simulated GPS — live ESP32 telemetry in a '
              'later phase · Last sync ${_clock(fleet.lastSync)}',
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

  // ----------------------------------------------------------------- roster

  Widget _buildRosterCard(
    FleetController fleet,
    List<Rider> roster, {
    bool scrollable = true,
  }) {
    final table = FleetTable(
      riders: roster,
      telemetry: fleet.telemetry,
      selectedRiderId: fleet.selectedRiderId,
      onSelect: fleet.selectRider,
    );

    final Widget body = roster.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No riders match this search',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ),
          )
        : (scrollable ? SingleChildScrollView(child: table) : table);

    return _Card(
      title: 'Rider roster',
      trailing: Text(
        '${roster.length} of ${fleet.riders.length}',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
      ),
      expandChild: scrollable,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _buildRosterFilters(),
          const SizedBox(height: 10),
          if (scrollable) Expanded(child: body) else body,
        ],
      ),
    );
  }

  Widget _buildRosterFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          style: const TextStyle(color: NovaColors.primaryText, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search name or helmet ID',
            hintStyle: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12.5,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: NovaColors.secondaryText,
            ),
            filled: true,
            fillColor: NovaColors.background,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            border: _border(NovaColors.cardBorder),
            enabledBorder: _border(NovaColors.cardBorder),
            focusedBorder: _border(NovaColors.cyan),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const FilterGroupLabel('STATUS'),
            for (final status in RiderStatus.values)
              FilterChipButton(
                label: status.label,
                color: StatusPill.colorForRider(status),
                selected: _statusFilter.contains(status),
                onTap: () => setState(() {
                  _statusFilter.contains(status)
                      ? _statusFilter.remove(status)
                      : _statusFilter.add(status);
                }),
              ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  List<Rider> _filteredRiders(FleetController fleet) {
    return fleet.riders.where((rider) {
      if (_statusFilter.isNotEmpty && !_statusFilter.contains(rider.status)) {
        return false;
      }
      if (_query.isEmpty) return true;
      return '${rider.fullName} ${rider.helmetId}'
          .toLowerCase()
          .contains(_query);
    }).toList();
  }

  // ----------------------------------------------------------- detail card

  Widget _buildDetailCard(FleetController fleet, Rider? rider) {
    if (rider == null) {
      return _Card(
        title: 'Rider detail',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.person_search_outlined,
                color: NovaColors.secondaryText,
                size: 30,
              ),
              SizedBox(height: 12),
              Text(
                'Select a rider',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Pick a row in the roster or click a dot on the map.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final telemetry = fleet.telemetryFor(rider.id);
    final riderAlerts =
        fleet.alerts.where((a) => a.riderId == rider.id).take(4).toList();
    final district = telemetry == null
        ? null
        : FleetController.nearestDistrict(telemetry.lat, telemetry.lng);

    return _Card(
      title: 'Rider detail',
      trailing: StatusPill.rider(rider.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rider.fullName,
            style: TextStyle(
              color: rider.status == RiderStatus.emergency
                  ? NovaColors.red
                  : NovaColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${rider.id} · ${rider.helmetId} · ${rider.phone}',
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          if (telemetry == null)
            const Text(
              'No helmet telemetry reporting for this rider.',
              style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(
                  label: 'SPEED',
                  value: '${telemetry.speedKmh.toStringAsFixed(1)} km/h',
                  icon: Icons.speed,
                  color: NovaColors.cyan,
                ),
                _Metric(
                  label: 'BATTERY',
                  value: '${telemetry.batteryPct}%',
                  icon: Icons.battery_std,
                  color: telemetry.batteryPct < 20
                      ? NovaColors.amber
                      : NovaColors.green,
                ),
                _Metric(
                  label: 'ALCOHOL',
                  value: telemetry.alcoholLevel.toStringAsFixed(2),
                  icon: Icons.local_bar,
                  color: telemetry.alcoholLevel > kAlcoholWarningLevel
                      ? NovaColors.amber
                      : NovaColors.green,
                ),
                _Metric(
                  label: 'GPS',
                  value: telemetry.gpsFix ? 'Locked' : 'No fix',
                  icon: telemetry.gpsFix ? Icons.gps_fixed : Icons.gps_off,
                  color: telemetry.gpsFix
                      ? NovaColors.green
                      : NovaColors.secondaryText,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Nearest district', district?.name ?? '—'),
            _kv(
              'Coordinates',
              '${telemetry.lat.toStringAsFixed(5)}, '
                  '${telemetry.lng.toStringAsFixed(5)}',
            ),
            _kv('Last update', AlertFeedTile.relativeTime(telemetry.lastUpdate)),
            _kv('Trail points', '${fleet.trailFor(rider.id).length}'),
            const SizedBox(height: 12),
            _buildLocateButton(fleet, rider),
          ],
          const SizedBox(height: 16),
          const Text(
            'RECENT ALERTS',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          if (riderAlerts.isEmpty)
            const Text(
              'No alerts recorded for this rider.',
              style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
            )
          else
            for (final alert in riderAlerts) AlertFeedTile(alert: alert),
        ],
      ),
    );
  }

  Widget _buildLocateButton(FleetController fleet, Rider rider) {
    return Tooltip(
      message: 'Highlights this rider on the basemap. The map window is fixed, '
          'so the view does not re-centre.',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _locateOnMap(fleet, rider),
          icon: const Icon(Icons.my_location, size: 16),
          label: const Text('Locate on map'),
          style: OutlinedButton.styleFrom(
            foregroundColor: NovaColors.cyan,
            side: const BorderSide(color: NovaColors.cardBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  /// Selects the rider — which draws the locator ring and their trail — and,
  /// when the layout is stacked, scrolls the map back into view.
  void _locateOnMap(FleetController fleet, Rider rider) {
    fleet.selectRider(rider.id);

    final mapContext = _mapKey.currentContext;
    if (mapContext == null || !_stackedScrollController.hasClients) return;
    Scrollable.ensureVisible(
      mapContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );

  static String _clock(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// Page-level card chrome. Squarer and denser than the rider app's cards, to
/// match the dashboard panels without pulling in DashPanel's fixed layout.
class _Card extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  /// True when the card is inside a bounded parent and the body should fill
  /// it; false when it sits in a scrolling column and must size to content.
  final bool expandChild;

  const _Card({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: NovaColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              // Flexible so a longer label ellipsises instead of overflowing
              // the fixed-width tile.
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
