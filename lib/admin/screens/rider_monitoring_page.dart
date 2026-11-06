import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novaride/admin/console_format.dart';
import 'package:novaride/admin/screens/admin_shell.dart';
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

  /// The map itself, so "Locate on map" can move its camera.
  final GlobalKey<FleetMapViewState> _mapViewKey = GlobalKey();

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
      child: Builder(
        builder: (context) {
          final nav = AdminNavScope.maybeOf(context);
          return FleetMapView(
            key: _mapViewKey,
            riders: fleet.riders,
            telemetry: fleet.telemetry,
            selectedRiderId: selectedId,
            onRiderTap: fleet.selectRider,
            onViewRider: fleet.selectRider,
            trail: selectedId == null ? const [] : fleet.trailFor(selectedId),
            alerts: fleet.alerts,
            statusOf: fleet.effectiveStatusOf,
            onAlertTap: nav == null ? null : (a) => nav.openAlert(a.id),
            // Only the simulation is captioned; live data needs no excuse.
            note: fleet.source == FleetSource.simulation
                ? 'Simulated GPS — not live helmet data · synced '
                      '${_clock(fleet.lastSync)}'
                : null,
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------- roster

  Widget _buildRosterCard(
    FleetController fleet,
    List<Rider> roster, {
    bool scrollable = true,
  }) {
    final unassigned = _filteredUnassigned(fleet);
    final table = FleetTable(
      riders: roster,
      telemetry: fleet.telemetry,
      unassigned: unassigned,
      selectedRiderId: fleet.selectedRiderId,
      onSelect: fleet.selectRider,
      statusOf: fleet.effectiveStatusOf,
    );

    final Widget body = roster.isEmpty && unassigned.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No riders match this search',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 11,
              horizontal: 12,
            ),
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
      if (_statusFilter.isNotEmpty &&
          !_statusFilter.contains(fleet.effectiveStatusOf(rider))) {
        return false;
      }
      if (_query.isEmpty) return true;
      return '${rider.fullName} ${rider.helmetId}'.toLowerCase().contains(
        _query,
      );
    }).toList();
  }

  /// Unassigned helmets match the search on their device id. They have no
  /// rider status, so a status filter leaves them out.
  List<HelmetTelemetry> _filteredUnassigned(FleetController fleet) {
    if (_statusFilter.isNotEmpty) return const [];
    return fleet.unassignedTelemetry.where((t) {
      if (_query.isEmpty) return true;
      return (t.deviceId ?? '').toLowerCase().contains(_query);
    }).toList();
  }

  // ----------------------------------------------------------- detail card

  Widget _buildDetailCard(FleetController fleet, Rider? rider) {
    final selectedId = fleet.selectedRiderId;
    final device = rider == null && selectedId != null
        ? fleet.unassignedFor(selectedId)
        : null;
    if (device != null) return _buildUnassignedCard(device);
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
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final telemetry = fleet.telemetryFor(rider.id);
    final status = fleet.effectiveStatusOf(rider);
    final riderAlerts = fleet.alerts
        .where((a) => a.riderId == rider.id)
        .take(4)
        .toList();

    return _Card(
      title: 'Rider detail',
      trailing: StatusPill.rider(status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rider.fullName,
            style: TextStyle(
              color: status == RiderStatus.emergency
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
            ..._telemetryDetail(telemetry, status: status),
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

  /// The readings block shared by a rider's card and an unassigned
  /// helmet's: every field the helmet sends, grouped the way an operator
  /// reads them. A reading the helmet did not send is a dash, never 0.
  ///
  /// Since the Oct 30 consultation acceleration is not a crash parameter:
  /// it lives under the collapsed Diagnostics, and vibration (SW-420), tilt
  /// and alcohol lead. Alcohol is the raw count against the helmet's own
  /// threshold and verdict — never BAC, never mg/L.
  List<Widget> _telemetryDetail(
    HelmetTelemetry telemetry, {
    RiderStatus? status,
  }) {
    final (lat, lng) = (telemetry.lat, telemetry.lng);
    final hasPosition = lat != null && lng != null;
    final district = hasPosition ? districtWithin(lat, lng) : null;
    final currentFix = FleetController.hasCurrentFix(telemetry);
    final vibrationColor = switch (telemetry.sw420Active) {
      true => NovaColors.amber,
      false => NovaColors.green,
      null => NovaColors.secondaryText,
    };
    final alcoholColor = switch (telemetry.alcoholDetected) {
      true => NovaColors.amber,
      false => NovaColors.green,
      null => NovaColors.secondaryText,
    };
    final crash = telemetry.reportsCrash;
    final sw420Changed = telemetry.sw420ChangedAt;

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Metric(
            label: 'VIBRATION',
            value: telemetry.vibrationLabel,
            icon: Icons.vibration,
            color: vibrationColor,
          ),
          _Metric(
            label: 'TILT',
            value: telemetry.tiltDegrees == null
                ? TelemetryReadout.missing
                : '${telemetry.tiltDegrees!.toStringAsFixed(1)}°',
            icon: Icons.screen_rotation_alt,
            color: telemetry.tiltDegrees == null
                ? NovaColors.secondaryText
                : NovaColors.cyan,
          ),
          _Metric(
            label: 'ALCOHOL',
            value: telemetry.alcoholVerdictLabel,
            icon: Icons.local_bar,
            color: alcoholColor,
          ),
          _Metric(
            label: 'SPEED',
            value: telemetry.speedLabel,
            icon: Icons.speed,
            color: telemetry.speedKmh == null
                ? NovaColors.secondaryText
                : NovaColors.cyan,
          ),
          _Metric(
            label: 'GPS',
            value: currentFix
                ? 'Locked'
                : (hasPosition ? 'Last known' : 'No fix'),
            icon: currentFix ? Icons.gps_fixed : Icons.gps_off,
            color: currentFix ? NovaColors.green : NovaColors.secondaryText,
          ),
        ],
      ),
      const SizedBox(height: 14),

      _group('STATUS'),
      if (status != null) _kv('Status', status.label),
      _kv('Online', telemetry.onlineLabel),
      _kvTime('Last seen', telemetry.heardAt),
      _kv('IP', telemetry.ipLabel),
      _kv('Cellular', telemetry.cellularLabel),

      _group('SAFETY'),
      _kv(
        'Safety event',
        telemetry.safetyEventLabel,
        valueColor: crash ? NovaColors.red : null,
      ),
      _kvWidget(
        'Vibration',
        Row(
          children: [
            Text(
              telemetry.vibrationLabel,
              style: TextStyle(color: vibrationColor, fontSize: 12.5),
            ),
            if (telemetry.sw420Active != null)
              Flexible(
                child: Tooltip(
                  message: sw420Changed == null
                      ? 'No change seen in this session or the helmet logs'
                      : formatManila(sw420Changed),
                  child: Text(
                    sw420Changed == null
                        ? ' · last change not seen'
                        : ' · changed ${formatAgo(sw420Changed)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      _kv('Tilt / orientation', telemetry.tiltLabel),

      _group('ALCOHOL'),
      // Raw ADC count against the raw-count threshold configured on the
      // helmet, and the helmet's own verdict. Not a concentration.
      _kv(
        'Reading',
        telemetry.alcoholThresholdLabel,
        valueColor: telemetry.alcoholDetected == true ? NovaColors.amber : null,
      ),
      _kv('Raw', telemetry.alcoholRawLabel),
      _kv('Voltage', telemetry.mq3VoltageLabel),
      _kv('Threshold', telemetry.alcoholThresholdValueLabel),
      _kv('Verdict', telemetry.alcoholVerdictLabel),

      _group('GPS'),
      _kv(
        'Fix',
        currentFix
            ? 'Current'
            : (hasPosition ? 'Not current — last known position' : 'No fix'),
      ),
      _kv('Satellites', telemetry.satellitesLabel),
      _kvTime('Fix taken', telemetry.fixAt),
      _kv(
        'Fix age at upload',
        telemetry.gpsAgeMs == null
            ? TelemetryReadout.missing
            : '${(telemetry.gpsAgeMs! / 1000).toStringAsFixed(1)} s',
      ),
      _kv('Speed', telemetry.speedLabel),
      _kv('Altitude', telemetry.altitudeLabel),
      _kvWidget('Coordinates', _CopyableCoordinates(telemetry)),
      _kv('Position source', telemetry.positionSourceLabel),
      _kv(
        'District',
        !hasPosition ? '—' : (district?.name ?? kOutsideCoverage),
      ),

      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('diagnostics'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          dense: true,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: NovaColors.secondaryText,
          collapsedIconColor: NovaColors.secondaryText,
          title: const Text(
            'DIAGNOSTICS',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          children: [
            _kv(
              'Accelerometer',
              switch (telemetry.accelerometerReady) {
                true => 'Ready',
                false => 'Not ready',
                null => TelemetryReadout.missing,
              },
            ),
            _kv('Accel x / y / z', telemetry.accelAxesLabel),
            _kv('Accel magnitude', telemetry.accelLabel),
            _kv('GPS serial', telemetry.nmeaLabel),
            _kv(
              'Battery',
              telemetry.batteryPct == null
                  ? 'Not reported by this firmware'
                  : telemetry.batteryLabel,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _group(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    ),
  );

  /// A time as "12 s ago", with the absolute Asia/Manila time on hover.
  Widget _kvTime(String label, DateTime? at) => _kvWidget(
    label,
    at == null
        ? const Text(
            TelemetryReadout.missing,
            style: TextStyle(color: NovaColors.primaryText, fontSize: 12.5),
          )
        : Tooltip(
            message: formatManila(at),
            child: Text(
              formatAgo(at),
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 12.5,
              ),
            ),
          ),
  );

  /// Detail for a helmet that reports but is on nobody's roster entry.
  Widget _buildUnassignedCard(HelmetTelemetry telemetry) {
    return _Card(
      title: 'Unassigned device',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            telemetry.deviceId ?? 'Unknown device',
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Transmitting with no rider assigned — no rider, alerts or trail '
            'are attached to it.',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          ..._telemetryDetail(telemetry),
        ],
      ),
    );
  }

  Widget _buildLocateButton(FleetController fleet, Rider rider) {
    return Tooltip(
      message:
          'Selects this rider and centres the map on their helmet. Turn on '
          '"Follow selected" on the map to keep it centred.',
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
    // After the frame that carries the new selection, so the map recentres
    // on this rider and not the previous one.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mapViewKey.currentState?.recentre(),
    );

    final mapContext = _mapKey.currentContext;
    if (mapContext == null || !_stackedScrollController.hasClients) return;
    Scrollable.ensureVisible(
      mapContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _kv(String label, String value, {Color? valueColor}) => _kvWidget(
    label,
    Text(
      value,
      style: TextStyle(
        color: valueColor ?? NovaColors.primaryText,
        fontSize: 12.5,
      ),
    ),
  );

  Widget _kvWidget(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: value),
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

/// The coordinates as selectable text with a copy button, so an operator
/// can paste them into a call log or a dispatcher's map.
class _CopyableCoordinates extends StatelessWidget {
  final HelmetTelemetry telemetry;

  const _CopyableCoordinates(this.telemetry);

  @override
  Widget build(BuildContext context) {
    final hasPosition = telemetry.lat != null && telemetry.lng != null;
    final text = hasPosition
        ? '${telemetry.lat!.toStringAsFixed(6)}, '
              '${telemetry.lng!.toStringAsFixed(6)}'
        : TelemetryReadout.missing;
    return Row(
      children: [
        Flexible(
          child: SelectableText(
            text,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 12.5,
            ),
          ),
        ),
        if (hasPosition)
          IconButton(
            tooltip: 'Copy coordinates',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 22),
            iconSize: 14,
            color: NovaColors.secondaryText,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text('Copied $text'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
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
