import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:novaride/admin/console_format.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/maps/nova_map_style.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds the basemap layer. Injectable so tests can supply none — a
/// network tile image fails under `flutter test` — or a stand-in.
typedef FleetTileLayerBuilder =
    Widget Function(BuildContext context, VoidCallback onTileError);

/// The live fleet on a real, interactive map: pan, wheel / pinch zoom,
/// working +/− buttons, "Fit all" and "Recentre", clickable helmet and
/// alert markers with popups, the selected rider's trail, layer toggles and
/// a follow mode.
///
/// **The mobile app's map look** ([NovaMapStyle]): OpenStreetMap tiles
/// tinted dark, the same pin ([NovaMapPin]), credit chip ([NovaMapCredit]),
/// background and zoom limits. No API key and no billing: Google Maps for
/// the web needs a billing-enabled key, and the project is on the Spark
/// plan. If the tiles cannot load (offline), the markers still draw on the
/// plain dark background and a small note says so.
///
/// **The camera never moves on its own when data updates.** It fits every
/// marker once, on first load; after that only the operator moves it —
/// unless they switch on "Follow selected", which moves to each new fix of
/// the selected rider and keeps the operator's zoom, as the mobile map
/// does.
///
/// Shared by the dashboard panel and Rider Monitoring so the two pages draw
/// the same map. Markers are coloured by the status [statusOf] returns —
/// the controller's effective status, worked out from the helmet.
class FleetMapView extends StatefulWidget {
  final List<Rider> riders;
  final List<HelmetTelemetry> telemetry;

  /// Highlighted with a locator ring; its trail is the one that gets drawn.
  final String? selectedRiderId;

  /// Called with a marker's id (rider id, or device id for an unassigned
  /// helmet) when it is clicked, and with null when the empty map is.
  /// Null leaves selection alone — the dashboard does not select.
  final ValueChanged<String?>? onRiderTap;

  /// Breadcrumb of fixes for the selected rider, oldest first.
  final List<TrailPoint> trail;

  final bool showLegend;

  /// Alerts to mark. Only active ones with a position of their own are
  /// drawn — a last-known helmet fix is not where the alert happened.
  final List<AlertEvent> alerts;

  /// "View on Alerts page" in an alert's popup. Null hides the link.
  final ValueChanged<AlertEvent>? onAlertTap;

  /// "View rider" in a helmet's popup. Null hides the button.
  final ValueChanged<String>? onViewRider;

  /// The status a rider's marker shows. Defaults to the stored status;
  /// both pages pass the controller's effective status.
  final RiderStatus Function(Rider rider)? statusOf;

  /// A line of context in the top-left corner (the simulation says so).
  final String? note;

  /// Null uses the dark OpenStreetMap tiles, except under `flutter test`,
  /// where no tile layer is built at all.
  final FleetTileLayerBuilder? tileLayerBuilder;

  /// Lets a test (or a parent) read and drive the camera. Owned by the
  /// caller when given.
  final MapController? mapController;

  /// Draws pins at [NovaMapPin.compactScale] of the mobile size, so a
  /// small map with the whole fleet on it does not turn into one blob. The
  /// dashboard panel uses it; Rider Monitoring keeps full-size pins.
  final bool compactPins;

  const FleetMapView({
    super.key,
    required this.riders,
    required this.telemetry,
    this.selectedRiderId,
    this.onRiderTap,
    this.trail = const [],
    this.showLegend = true,
    this.alerts = const [],
    this.onAlertTap,
    this.onViewRider,
    this.statusOf,
    this.note,
    this.tileLayerBuilder,
    this.mapController,
    this.compactPins = false,
  });

  /// OpenStreetMap's tile policy wants each app identified; the mobile app
  /// sends `ph.edu.tip.novaride`.
  static const userAgentPackageName = 'ph.edu.tip.novaride.admin';

  /// A fix older than this is drawn faded with a "stale" badge: the
  /// firmware uploads every 5 min, so two missed uploads.
  static const staleAfter = Duration(minutes: 7);

  /// Where the map opens, and where Recentre goes with nothing to show.
  static const metroManila = LatLng(kMetroManilaLat, kMetroManilaLng);

  /// The basemap colour the tiles are drawn over, and all that shows
  /// without them — the mobile map's.
  static const background = NovaMapStyle.background;

  @override
  State<FleetMapView> createState() => FleetMapViewState();
}

/// What the popup is showing: a helmet marker (by its marker id) or an
/// alert (by id).
sealed class _Popup {
  const _Popup();
}

class _HelmetPopup extends _Popup {
  final String markerId;
  const _HelmetPopup(this.markerId);
}

class _AlertPopup extends _Popup {
  final String alertId;
  const _AlertPopup(this.alertId);
}

/// One helmet on the map, worked out from a rider or an unassigned helmet.
class _HelmetPin {
  final String id;
  final Rider? rider;
  final HelmetTelemetry telemetry;
  final LatLng point;
  final RiderStatus? status;
  final bool stale;

  const _HelmetPin({
    required this.id,
    required this.rider,
    required this.telemetry,
    required this.point,
    required this.status,
    required this.stale,
  });

  bool get unassigned => rider == null;
  bool get emergency => status == RiderStatus.emergency;

  /// A helmet nobody is paired with: neutral grey.
  static const unassignedColor = NovaColors.secondaryText;

  Color get color =>
      unassigned ? unassignedColor : StatusPill.colorForRider(status!);
}

/// Public so a page can drive the camera on the operator's behalf ("Locate
/// on map" calls [recentre]) and a test can read [following].
class FleetMapViewState extends State<FleetMapView>
    with SingleTickerProviderStateMixin {
  late final MapController _ownController = MapController();
  MapController get _controller => widget.mapController ?? _ownController;

  /// Drives the emergency ping. Runs only while an emergency marker is on
  /// the map, so a quiet map lets the frame scheduler settle.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _mapReady = false;
  bool _autoFitted = false;
  bool _follow = false;
  LatLng? _lastFollowed;
  _Popup? _popup;

  bool _showRiders = true;
  bool _showUnassigned = true;
  bool _showAlerts = true;
  bool _showTrail = true;

  bool _tilesFailing = false;
  Timer? _tileRecovery;

  /// Whether the camera follows the selected rider. Exposed for tests.
  bool get following => _follow;

  @override
  void dispose() {
    _pulse.dispose();
    _tileRecovery?.cancel();
    if (widget.mapController == null) _ownController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FleetMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoFit();
      _maybeFollow();
    });
  }

  // ---------------------------------------------------------------- pins

  List<_HelmetPin> _pins() {
    final now = DateTime.now();
    final pins = <_HelmetPin>[];
    for (final rider in widget.riders) {
      final t = _telemetryFor(rider.id);
      if (t == null) continue;
      final (lat, lng) = (t.lat, t.lng);
      // No position is no marker — never a marker at 0,0.
      if (lat == null || lng == null) continue;
      pins.add(
        _HelmetPin(
          id: rider.id,
          rider: rider,
          telemetry: t,
          point: LatLng(lat, lng),
          status: widget.statusOf?.call(rider) ?? rider.status,
          stale: _isStale(t, now),
        ),
      );
    }
    // A helmet with no rider is still on the map, in neutral grey, keyed
    // by its device id.
    for (final t in widget.telemetry) {
      final (deviceId, lat, lng) = (t.deviceId, t.lat, t.lng);
      if (t.riderId != null || deviceId == null) continue;
      if (lat == null || lng == null) continue;
      pins.add(
        _HelmetPin(
          id: deviceId,
          rider: null,
          telemetry: t,
          point: LatLng(lat, lng),
          status: null,
          stale: _isStale(t, now),
        ),
      );
    }
    return pins;
  }

  static bool _isStale(HelmetTelemetry t, DateTime now) {
    final at = t.fixAt ?? t.heardAt;
    return at == null || now.difference(at) > FleetMapView.staleAfter;
  }

  HelmetTelemetry? _telemetryFor(String riderId) {
    for (final t in widget.telemetry) {
      if (t.riderId == riderId) return t;
    }
    return null;
  }

  List<_HelmetPin> _visiblePins(List<_HelmetPin> all) => [
    for (final p in all)
      if (p.unassigned ? _showUnassigned : _showRiders) p,
  ];

  List<AlertEvent> _alertsToMark() => [
    for (final a in widget.alerts)
      if (a.status.isActive && a.hasPosition) a,
  ];

  // -------------------------------------------------------------- camera

  void _onMapReady() {
    _mapReady = true;
    _maybeAutoFit();
  }

  /// Where the camera opens. When helmets are already known on the first
  /// frame (a page reopened after the fleet loaded), the camera *starts* on
  /// them, which counts as the one-time auto-fit. Opening on Metro Manila
  /// and fitting from [_onMapReady] instead moved the camera inside the
  /// map's first frame: every tile request was aborted and the basemap
  /// stayed blank until the operator first moved the map. With no helmets
  /// yet, it opens on Metro Manila and fits once they arrive.
  late final ({LatLng center, double zoom, CameraFit? fit}) _initialCamera =
      () {
        final points = _fitPoints();
        if (points.isEmpty) {
          return (
            center: FleetMapView.metroManila,
            zoom: kMetroManilaZoom,
            fit: null,
          );
        }
        _autoFitted = true;
        if (points.length == 1) {
          return (center: points.single, zoom: _singlePointZoom, fit: null);
        }
        return (
          center: FleetMapView.metroManila,
          zoom: kMetroManilaZoom,
          fit: _cameraFit(points),
        );
      }();

  /// The zoom for a fit with only one point to frame.
  static const double _singlePointZoom = 15;

  static CameraFit _cameraFit(List<LatLng> points) => CameraFit.coordinates(
    coordinates: points,
    padding: const EdgeInsets.all(56),
    maxZoom: 16,
  );

  /// Once, the first time there is anything to show.
  void _maybeAutoFit() {
    if (_autoFitted || !_mapReady) return;
    final points = _fitPoints();
    if (points.isEmpty) return;
    _autoFitted = true;
    _fit(points);
  }

  /// As on the mobile map: move to the new fix and keep the zoom the
  /// operator chose. Nothing happens unless the fix actually moved.
  void _maybeFollow() {
    if (!_follow) return;
    final target = _selectedPoint();
    if (target == null || target == _lastFollowed) return;
    _lastFollowed = target;
    _controller.move(target, _controller.camera.zoom);
  }

  LatLng? _selectedPoint() {
    final id = widget.selectedRiderId;
    if (id == null) return null;
    for (final p in _pins()) {
      if (p.id == id) return p.point;
    }
    return null;
  }

  List<LatLng> _fitPoints() => [
    for (final p in _visiblePins(_pins())) p.point,
    if (_showAlerts)
      for (final a in _alertsToMark()) LatLng(a.lat!, a.lng!),
  ];

  void _fit(List<LatLng> points) {
    if (!_mapReady) return;
    if (points.length == 1) {
      _controller.move(points.single, _singlePointZoom);
      return;
    }
    _controller.fitCamera(_cameraFit(points));
  }

  void fitAll() {
    final points = _fitPoints();
    if (points.isEmpty) {
      recentre();
    } else {
      _fit(points);
    }
  }

  /// The selected rider, else the middle of everything shown, else Metro
  /// Manila at zoom 12.
  void recentre() {
    if (!_mapReady) return;
    final selected = _selectedPoint();
    if (selected != null) {
      _controller.move(selected, _controller.camera.zoom);
      return;
    }
    final points = _fitPoints();
    if (points.isEmpty) {
      _controller.move(FleetMapView.metroManila, kMetroManilaZoom);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _controller.move(bounds.center, _controller.camera.zoom);
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _controller.camera;
    _controller.move(camera.center, camera.clampZoom(camera.zoom + delta));
  }

  void _toggleFollow() {
    setState(() {
      _follow = !_follow;
      _lastFollowed = null;
    });
    if (_follow) _maybeFollow();
  }

  // --------------------------------------------------------------- tiles

  void _onTileError() {
    _tileRecovery?.cancel();
    // Clear the note once tiles have stopped failing for a while.
    _tileRecovery = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _tilesFailing = false);
    });
    if (!_tilesFailing && mounted) setState(() => _tilesFailing = true);
  }

  /// Network tiles fail under `flutter test`, and a failing image is a test
  /// failure, so no tile layer is built there unless one is injected.
  static bool get _underTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  Widget? _tileLayer(BuildContext context) {
    final builder = widget.tileLayerBuilder;
    if (builder != null) return builder(context, _onTileError);
    if (_underTest) return null;
    return NovaMapStyle.darkTiles(
      context,
      userAgentPackageName: FleetMapView.userAgentPackageName,
      errorTileCallback: (tile, error, stack) => _onTileError(),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final allPins = _pins();
    final pins = _visiblePins(allPins);
    final alerts = _showAlerts ? _alertsToMark() : const <AlertEvent>[];
    _syncPulse(pins);

    final trail = _showTrail && widget.selectedRiderId != null
        ? widget.trail
        : const <TrailPoint>[];
    final tiles = _tileLayer(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _initialCamera.center,
              initialZoom: _initialCamera.zoom,
              initialCameraFit: _initialCamera.fit,
              minZoom: NovaMapStyle.minZoom,
              maxZoom: NovaMapStyle.maxZoom,
              backgroundColor: FleetMapView.background,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: _onMapReady,
              onTap: (_, _) {
                setState(() => _popup = null);
                widget.onRiderTap?.call(null);
              },
            ),
            children: [
              ?tiles,
              if (trail.length >= 2) _trailLine(trail),
              if (trail.isNotEmpty) _trailDots(trail),
              MarkerLayer(
                markers: [
                  for (final a in alerts) _alertMarker(a),
                  for (final p in pins) _helmetMarker(p),
                ],
              ),
              // Under the popup, so an open card is never hidden by it.
              if (tiles != null) const NovaMapCredit(),
              _PopupLayer(
                point: _popupPoint(allPins),
                // Clear of the pin's halo.
                gap: NovaMapPin.haloSize(compact: widget.compactPins) / 2 + 4,
                child: _popupCard(allPins),
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tilesFailing)
                  const _MapNote(
                    icon: Icons.cloud_off_outlined,
                    text: 'Map tiles unavailable — markers are still live',
                    color: NovaColors.amber,
                  ),
                if (widget.note case final note?)
                  _MapNote(icon: Icons.science_outlined, text: note),
              ],
            ),
          ),
          Positioned(top: 8, right: 8, child: _buildControls()),
          // Bottom-right, clear of the credit chip in the bottom-left: on a
          // narrow map the legend wraps upward instead of covering it.
          if (widget.showLegend)
            Positioned(
              bottom: 6,
              right: 6,
              left: 0,
              // Padding rather than `left:`: on a tiny map it shrinks to
              // zero instead of asking for a negative width.
              child: Padding(
                padding: EdgeInsets.only(
                  left: tiles == null
                      ? 6
                      : NovaMapCredit.footprint(context).width,
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: _MapLegend(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _syncPulse(List<_HelmetPin> pins) {
    final needed = pins.any((p) => p.emergency);
    if (needed && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!needed && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  // ------------------------------------------------------------- layers

  /// Oldest segment faint, newest bright: a gradient along the line.
  Widget _trailLine(List<TrailPoint> trail) => PolylineLayer(
    polylines: [
      Polyline(
        points: [for (final p in trail) LatLng(p.lat, p.lng)],
        strokeWidth: 3,
        gradientColors: [
          NovaColors.cyan.withValues(alpha: 0.12),
          NovaColors.cyan.withValues(alpha: 0.85),
        ],
      ),
    ],
  );

  Widget _trailDots(List<TrailPoint> trail) => CircleLayer(
    circles: [
      for (var i = 0; i < trail.length; i++)
        CircleMarker(
          point: LatLng(trail[i].lat, trail[i].lng),
          radius: 2.6,
          color: NovaColors.cyan.withValues(
            alpha:
                0.25 + 0.7 * (trail.length == 1 ? 1 : i / (trail.length - 1)),
          ),
        ),
    ],
  );

  Marker _helmetMarker(_HelmetPin pin) => Marker(
    key: ValueKey('helmet-marker-${pin.id}'),
    point: pin.point,
    width: NovaMapPin.markerSize(compact: widget.compactPins),
    height: NovaMapPin.markerSize(compact: widget.compactPins),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _popup = _HelmetPopup(pin.id));
        widget.onRiderTap?.call(pin.id);
      },
      child: Tooltip(
        message: pin.rider?.fullName ?? '${pin.id} (unassigned)',
        child: _HelmetMarker(
          color: pin.color,
          emergency: pin.emergency,
          selected: pin.id == widget.selectedRiderId,
          stale: pin.stale,
          pulse: _pulse,
          compact: widget.compactPins,
        ),
      ),
    ),
  );

  Marker _alertMarker(AlertEvent alert) {
    final color = _priorityColor(FleetController.priorityOf(alert));
    final size = NovaMapPin.markerSize(compact: widget.compactPins);
    return Marker(
      key: ValueKey('alert-marker-${alert.id}'),
      point: LatLng(alert.lat!, alert.lng!),
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _popup = _AlertPopup(alert.id)),
        child: Tooltip(
          message: '${alert.type.label} · ${alert.riderName}',
          child: _AlertMarker(color: color, compact: widget.compactPins),
        ),
      ),
    );
  }

  static Color _priorityColor(AlertPriority p) => switch (p) {
    AlertPriority.critical => NovaColors.red,
    AlertPriority.high => NovaColors.pink,
    AlertPriority.medium => NovaColors.amber,
    AlertPriority.low => NovaColors.cyan,
    AlertPriority.none => NovaColors.secondaryText,
  };

  // -------------------------------------------------------------- popups

  LatLng? _popupPoint(List<_HelmetPin> pins) {
    return switch (_popup) {
      _HelmetPopup(:final markerId) =>
        pins.where((p) => p.id == markerId).firstOrNull?.point,
      _AlertPopup(:final alertId) => () {
        final a = widget.alerts.where((a) => a.id == alertId).firstOrNull;
        return a == null || !a.hasPosition ? null : LatLng(a.lat!, a.lng!);
      }(),
      null => null,
    };
  }

  Widget? _popupCard(List<_HelmetPin> pins) {
    switch (_popup) {
      case _HelmetPopup(:final markerId):
        final pin = pins.where((p) => p.id == markerId).firstOrNull;
        return pin == null ? null : _helmetCard(pin);
      case _AlertPopup(:final alertId):
        final alert = widget.alerts.where((a) => a.id == alertId).firstOrNull;
        return alert == null ? null : _alertCard(alert);
      case null:
        return null;
    }
  }

  Widget _helmetCard(_HelmetPin pin) {
    final t = pin.telemetry;
    final rider = pin.rider;
    final fixAge = t.fixAt == null ? '—' : formatAgo(t.fixAt!);
    return _PopupCard(
      key: const ValueKey('helmet-popup'),
      onClose: () => setState(() => _popup = null),
      title: rider?.fullName ?? 'Unassigned helmet',
      subtitle: rider == null
          ? 'Helmet ${pin.id} · no rider paired'
          : '${rider.id} · Helmet ${rider.helmetId}',
      badge: pin.status == null
          ? const StatusPill(
              label: 'Unassigned',
              color: NovaColors.secondaryText,
            )
          : StatusPill.rider(pin.status!),
      rows: [
        ('Speed', t.speedLabel),
        ('Last seen', t.heardAt == null ? '—' : formatAgo(t.heardAt!)),
        ('GPS', '${t.satellitesLabel} sats · fix $fixAge'),
        ('Source', t.positionSourceLabel),
        ('Alcohol', t.alcoholThresholdLabel),
        ('Vibration', t.vibrationLabel),
        ('Tilt', t.tiltLabel),
        ('Safety', t.safetyEventLabel),
      ],
      actions: [
        if (rider != null && widget.onViewRider != null)
          _PopupAction(
            label: 'View rider',
            icon: Icons.person_search_outlined,
            onPressed: () => widget.onViewRider!(rider.id),
          ),
        _PopupAction(
          label: 'Open in Google Maps',
          icon: Icons.open_in_new,
          onPressed: () => _openInGoogleMaps(t, pin.point),
        ),
      ],
    );
  }

  Widget _alertCard(AlertEvent alert) {
    return _PopupCard(
      key: const ValueKey('alert-popup'),
      onClose: () => setState(() => _popup = null),
      title: alert.type.label,
      titleColor: AlertFeedTile.colorFor(alert.type),
      subtitle: '${alert.riderName} · ${alert.riderId}',
      badge: StatusPill.alert(alert.status),
      rows: [
        (
          'Raised',
          '${formatAgo(alert.timestamp)} · '
              '${formatManila(alert.timestamp)}',
        ),
        ('Location', alert.address),
        ('Alert', alert.id),
      ],
      actions: [
        if (widget.onAlertTap != null)
          _PopupAction(
            label: 'View on Alerts page',
            icon: Icons.notifications_active_outlined,
            onPressed: () => widget.onAlertTap!(alert),
          ),
      ],
    );
  }

  /// The firmware's own link when it sent one, else a search link for the
  /// coordinates — https://maps.google.com/?q=lat,lng.
  static Uri googleMapsUri(HelmetTelemetry t, LatLng point) {
    final firmware = t.mapsUrl;
    if (firmware != null) {
      final parsed = Uri.tryParse(firmware);
      if (parsed != null && parsed.hasScheme) return parsed;
    }
    return Uri.parse(
      'https://maps.google.com/?q=${point.latitude},${point.longitude}',
    );
  }

  Future<void> _openInGoogleMaps(HelmetTelemetry t, LatLng point) async {
    final uri = googleMapsUri(t, point);
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (error) {
      debugPrint('FleetMapView: could not open $uri — $error');
    }
  }

  // ------------------------------------------------------------ controls

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ControlStack(
          children: [
            _ControlButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onPressed: () => _zoomBy(1),
            ),
            _ControlButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: () => _zoomBy(-1),
            ),
            _ControlButton(
              key: const ValueKey('map-fit-all'),
              icon: Icons.fit_screen_outlined,
              tooltip: 'Fit all',
              onPressed: fitAll,
            ),
            _ControlButton(
              key: const ValueKey('map-recentre'),
              icon: Icons.my_location,
              tooltip: 'Recentre',
              onPressed: recentre,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _LayerPanel(
          entries: [
            ('Riders', _showRiders, (v) => setState(() => _showRiders = v)),
            (
              'Unassigned',
              _showUnassigned,
              (v) => setState(() => _showUnassigned = v),
            ),
            ('Alerts', _showAlerts, (v) => setState(() => _showAlerts = v)),
            ('Trail', _showTrail, (v) => setState(() => _showTrail = v)),
            ('Follow selected', _follow, (_) => _toggleFollow()),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- widgets

/// Positions [child] above [point], following the camera. A layer of its
/// own so the card pans and zooms with the map; transparent everywhere
/// else, so it never swallows a drag.
class _PopupLayer extends StatelessWidget {
  final LatLng? point;
  final Widget? child;

  /// Distance from the marker's centre to the card's edge.
  final double gap;

  const _PopupLayer({
    required this.point,
    required this.child,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    final p = point;
    final c = child;
    if (p == null || c == null) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final offset = camera.latLngToScreenOffset(p);
    final size = camera.size;
    // Above the marker, unless the marker is in the top half — then below,
    // so a marker near the top edge never opens its card off screen. Kept
    // inside the map horizontally for the same reason.
    final above = offset.dy > size.height / 2;
    final left = (offset.dx - _PopupCard.width / 2).clamp(
      4.0,
      (size.width - _PopupCard.width - 4).clamp(4.0, double.infinity),
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: above ? offset.dy - gap : offset.dy + gap,
          child: above
              ? FractionalTranslation(
                  translation: const Offset(0, -1),
                  child: c,
                )
              : c,
        ),
      ],
    );
  }
}

class _PopupAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PopupAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class _PopupCard extends StatelessWidget {
  static const double width = 268;

  final String title;
  final Color? titleColor;
  final String subtitle;
  final Widget badge;
  final List<(String, String)> rows;
  final List<_PopupAction> actions;
  final VoidCallback onClose;

  const _PopupCard({
    super.key,
    required this.title,
    this.titleColor,
    required this.subtitle,
    required this.badge,
    required this.rows,
    required this.actions,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: NovaColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NovaColors.cardBorder),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor ?? NovaColors.primaryText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: NovaMapStyle.label,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: NovaMapStyle.label,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            badge,
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 66,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: NovaMapStyle.label,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final a in actions)
                    TextButton.icon(
                      onPressed: a.onPressed,
                      icon: Icon(a.icon, size: 14),
                      label: Text(a.label),
                      style: TextButton.styleFrom(
                        foregroundColor: NovaColors.cyan,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 11.5),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One helmet: the mobile app's pin ([NovaMapPin]) in its status colour,
/// with the admin's states drawn on top of it — a pulse ring out of the
/// halo in an emergency, a locator ring when selected, and faded to half
/// with a "stale" badge when its fix is old.
class _HelmetMarker extends StatelessWidget {
  final Color color;
  final bool emergency;
  final bool selected;
  final bool stale;
  final Animation<double> pulse;
  final bool compact;

  const _HelmetMarker({
    required this.color,
    required this.emergency,
    required this.selected,
    required this.stale,
    required this.pulse,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final halo = NovaMapPin.haloSize(compact: compact);
    final scale = NovaMapPin.scaleOf(compact: compact);
    Widget marker = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        NovaMapPin(color: color, compact: compact),
        if (emergency)
          _Unclipped(
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                // Starts at the halo's edge, grows 28 px and fades out.
                final t = pulse.value;
                final size = halo + 28 * scale * t;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: (1 - t) * 0.9),
                      width: 2 * scale,
                    ),
                  ),
                );
              },
            ),
          ),
        if (selected) _Unclipped(child: _LocatorRing(haloSize: halo)),
        if (stale)
          Positioned(
            bottom: 0,
            child: Container(
              key: const ValueKey('stale-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: NovaColors.background,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: NovaColors.cardBorder),
              ),
              child: Text(
                'stale',
                style: TextStyle(
                  color: NovaMapStyle.label,
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
    if (stale) marker = Opacity(opacity: 0.5, child: marker);
    return marker;
  }
}

/// Lets a ring be wider than the marker box: the pulse and the locator
/// ring reach past the 64 px marker the pin fills.
class _Unclipped extends StatelessWidget {
  final Widget child;

  const _Unclipped({required this.child});

  @override
  Widget build(BuildContext context) => OverflowBox(
    maxWidth: double.infinity,
    maxHeight: double.infinity,
    child: child,
  );
}

/// Static ring just outside the halo, plus crosshair ticks — reads as
/// "this one" even in a cluster.
class _LocatorRing extends StatelessWidget {
  final double haloSize;

  const _LocatorRing({required this.haloSize});

  @override
  Widget build(BuildContext context) {
    final side = haloSize + 2 * (_LocatorPainter.gap + _LocatorPainter.tick);
    return SizedBox(
      width: side,
      height: side,
      child: CustomPaint(painter: _LocatorPainter(haloSize / 2)),
    );
  }
}

class _LocatorPainter extends CustomPainter {
  static const gap = 3.0;
  static const tick = 5.0;

  final double haloRadius;

  const _LocatorPainter(this.haloRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = haloRadius + gap;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = NovaColors.cyan,
    );
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = NovaColors.cyan;
    for (final dir in const [
      Offset(0, -1),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(1, 0),
    ]) {
      canvas.drawLine(center + dir * r, center + dir * (r + tick), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LocatorPainter oldDelegate) =>
      oldDelegate.haloRadius != haloRadius;
}

/// An active alert: the warning triangle in its priority colour, given the
/// pin's look — the same soft halo and the same dark ring — so it reads as
/// one family with the helmets while its shape still says "alert".
class _AlertMarker extends StatelessWidget {
  final Color color;
  final bool compact;

  const _AlertMarker({required this.color, required this.compact});

  @override
  Widget build(BuildContext context) {
    final halo = NovaMapPin.haloSize(compact: compact);
    final scale = NovaMapPin.scaleOf(compact: compact);
    return Center(
      child: Container(
        width: halo,
        height: halo,
        decoration: BoxDecoration(
          color: color.withValues(alpha: NovaMapStyle.haloAlpha),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: _AlertTriangle(
          color: color,
          size: 30 * scale,
          ringWidth: NovaMapPin.ringWidth(compact: compact),
        ),
      ),
    );
  }
}

/// A warning triangle with an exclamation mark, filled in [color] and
/// outlined in the pin's dark ring. Also the legend's alert mark.
class _AlertTriangle extends StatelessWidget {
  final Color color;
  final double size;
  final double ringWidth;

  const _AlertTriangle({
    required this.color,
    required this.size,
    required this.ringWidth,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _TrianglePainter(color, ringWidth)),
  );
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final double ringWidth;

  const _TrianglePainter(this.color, this.ringWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The fill covers the inner half of the stroke, so a stroke twice the
    // ring width shows exactly [ringWidth] of dark ring — the pin's — and
    // an inset of one ring width keeps it inside the box.
    final inset = ringWidth;
    final path = Path()
      ..moveTo(w / 2, inset + h * 0.04)
      ..lineTo(w - inset, h * 0.9 - inset)
      ..lineTo(inset, h * 0.9 - inset)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth * 2
        ..strokeJoin = StrokeJoin.round
        ..color = NovaMapStyle.ink,
    );
    canvas.drawPath(path, Paint()..color = color);

    // The exclamation mark, in the pin's dark ink.
    final x = w / 2;
    canvas.drawLine(
      Offset(x, h * 0.36),
      Offset(x, h * 0.6),
      Paint()
        ..color = NovaMapStyle.ink
        ..strokeWidth = w * 0.1
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(x, h * 0.74),
      w * 0.055,
      Paint()..color = NovaMapStyle.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.ringWidth != ringWidth;
}

class _MapNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MapNote({
    required this.icon,
    required this.text,
    this.color = NovaMapStyle.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NovaMapStyle.inkTranslucent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlStack extends StatelessWidget {
  final List<Widget> children;

  const _ControlStack({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaMapStyle.inkTranslucent,
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 15, color: NovaColors.primaryText),
        ),
      ),
    );
  }
}

/// Layer toggles and Follow, in one small panel under the zoom buttons.
class _LayerPanel extends StatelessWidget {
  final List<(String, bool, ValueChanged<bool>)> entries;

  const _LayerPanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: NovaMapStyle.inkTranslucent,
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, on, onChanged) in entries)
            InkWell(
              key: ValueKey('map-layer-$label'),
              onTap: () => onChanged(!on),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      on ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 13,
                      color: on ? NovaColors.cyan : NovaMapStyle.label,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rider statuses, plus the alert marker and the stale look.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    // The pin in miniature: halo, dot, dark ring.
    Widget dot(Color color, {double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        width: 13,
        height: 13,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: NovaMapStyle.haloAlpha),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: NovaMapStyle.ink),
          ),
        ),
      ),
    );
    Widget entry(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: NovaMapStyle.label, fontSize: 9),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: NovaMapStyle.inkTranslucent,
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final status in RiderStatus.values)
            entry(dot(StatusPill.colorForRider(status)), status.label),
          entry(dot(_HelmetPin.unassignedColor), 'Unassigned'),
          entry(
            const _AlertTriangle(color: NovaColors.red, size: 13, ringWidth: 1),
            'Alert',
          ),
          entry(dot(NovaColors.cyan, opacity: 0.45), 'Stale fix'),
        ],
      ),
    );
  }
}
