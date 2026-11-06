import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:novaride/admin/console_format.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
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
/// **Basemap: CARTO Dark Matter raster tiles over OpenStreetMap data.** A
/// deliberate choice, not a placeholder: they need no API key and no
/// billing, and they match the console's dark theme. Google Maps for the
/// web needs a billing-enabled key, and the project is on the Spark plan.
/// The rider app's own Google Maps setup is separate and untouched. If the
/// tiles cannot load (offline), the markers still draw on a plain dark
/// background and a small note says so.
///
/// **The camera never moves on its own when data updates.** It fits every
/// marker once, on first load; after that only the operator moves it —
/// unless they switch on "Follow selected", which keeps the selected rider
/// centred as new fixes arrive.
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

  /// Null uses the CARTO tiles, except under `flutter test`, where no tile
  /// layer is built at all.
  final FleetTileLayerBuilder? tileLayerBuilder;

  /// Lets a test (or a parent) read and drive the camera. Owned by the
  /// caller when given.
  final MapController? mapController;

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
  });

  /// CARTO Dark Matter. `{r}` asks for @2x tiles on high-density screens.
  static const tileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const tileSubdomains = ['a', 'b', 'c', 'd'];
  static const attribution = '© OpenStreetMap contributors © CARTO';

  /// A fix older than this is drawn faded with a "stale" badge: the
  /// firmware uploads every 5 min, so two missed uploads.
  static const staleAfter = Duration(minutes: 7);

  /// Where the map opens, and where Recentre goes with nothing to show.
  static const metroManila = LatLng(kMetroManilaLat, kMetroManilaLng);

  /// The basemap colour the tiles are drawn over, and all that shows
  /// without them.
  static const background = Color(0xFF0B0F1E);

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
  Color get color => unassigned
      ? NovaColors.secondaryText
      : StatusPill.colorForRider(status!);
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

  /// Once, the first time there is anything to show.
  void _maybeAutoFit() {
    if (_autoFitted || !_mapReady) return;
    final points = _fitPoints();
    if (points.isEmpty) return;
    _autoFitted = true;
    _fit(points);
  }

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
      _controller.move(points.single, 15);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
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
    return TileLayer(
      urlTemplate: FleetMapView.tileUrl,
      subdomains: FleetMapView.tileSubdomains,
      retinaMode: MediaQuery.devicePixelRatioOf(context) > 1,
      userAgentPackageName: 'ph.edu.tip.novaride.admin',
      maxNativeZoom: 20,
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
              initialCenter: FleetMapView.metroManila,
              initialZoom: kMetroManilaZoom,
              minZoom: 3,
              maxZoom: 19,
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
              _PopupLayer(
                point: _popupPoint(allPins),
                child: _popupCard(allPins),
              ),
              if (tiles != null)
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomRight,
                  showFlutterMapAttribution: false,
                  popupBackgroundColor: NovaColors.card,
                  attributions: const [
                    TextSourceAttribution(FleetMapView.attribution),
                  ],
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
          if (widget.showLegend)
            const Positioned(bottom: 8, left: 8, child: _MapLegend()),
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
            alpha: 0.25 + 0.7 * (trail.length == 1 ? 1 : i / (trail.length - 1)),
          ),
        ),
    ],
  );

  Marker _helmetMarker(_HelmetPin pin) => Marker(
    key: ValueKey('helmet-marker-${pin.id}'),
    point: pin.point,
    width: 46,
    height: 46,
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
        ),
      ),
    ),
  );

  Marker _alertMarker(AlertEvent alert) {
    final color = _priorityColor(FleetController.priorityOf(alert));
    return Marker(
      key: ValueKey('alert-marker-${alert.id}'),
      point: LatLng(alert.lat!, alert.lng!),
      width: 34,
      height: 34,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _popup = _AlertPopup(alert.id)),
        child: Tooltip(
          message: '${alert.type.label} · ${alert.riderName}',
          child: Icon(
            Icons.warning_rounded,
            size: 28,
            color: color,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
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
          ? const StatusPill(label: 'Unassigned', color: NovaColors.secondaryText)
          : StatusPill.rider(pin.status!),
      rows: [
        ('Speed', t.speedLabel),
        (
          'Last seen',
          t.heardAt == null ? '—' : formatAgo(t.heardAt!),
        ),
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
        ('Raised', '${formatAgo(alert.timestamp)} · '
            '${formatManila(alert.timestamp)}'),
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

  const _PopupLayer({required this.point, required this.child});

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
          top: above ? offset.dy - 22 : offset.dy + 22,
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
          color: NovaColors.card.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NovaColors.cardBorder),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 12),
          ],
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
                          color: NovaColors.secondaryText,
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
                      color: NovaColors.secondaryText,
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
                          color: NovaColors.secondaryText,
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

/// One helmet: a dot in its status colour with a soft halo, a pulse ring in
/// an emergency, a locator ring when selected, and faded with a "stale"
/// badge when its fix is old.
class _HelmetMarker extends StatelessWidget {
  final Color color;
  final bool emergency;
  final bool selected;
  final bool stale;
  final Animation<double> pulse;

  const _HelmetMarker({
    required this.color,
    required this.emergency,
    required this.selected,
    required this.stale,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    Widget marker = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        ),
        if (emergency)
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              // Ring breathes 12 → 32 px and fades out over the loop — the
              // painted map's pulse, as a widget.
              final t = pulse.value;
              final size = 12 + 20 * t;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: (1 - t) * 0.9),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
        if (selected) const _LocatorRing(),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black54, width: 1),
          ),
        ),
        if (stale)
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: NovaColors.background,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: NovaColors.cardBorder),
              ),
              child: const Text(
                'stale',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 7.5,
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

/// Static ring plus crosshair ticks — reads as "this one" even in a
/// cluster.
class _LocatorRing extends StatelessWidget {
  const _LocatorRing();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(painter: _LocatorPainter()),
    );
  }
}

class _LocatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = NovaColors.cyan;
    canvas.drawCircle(center, 11, ring);
    final tick = Paint()
      ..strokeWidth = 1.4
      ..color = NovaColors.cyan;
    for (final d in const [
      [Offset(0, -15), Offset(0, -12)],
      [Offset(0, 12), Offset(0, 15)],
      [Offset(-15, 0), Offset(-12, 0)],
      [Offset(12, 0), Offset(15, 0)],
    ]) {
      canvas.drawLine(center + d[0], center + d[1], tick);
    }
  }

  @override
  bool shouldRepaint(covariant _LocatorPainter oldDelegate) => false;
}

class _MapNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MapNote({
    required this.icon,
    required this.text,
    this.color = NovaColors.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
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
        color: NovaColors.card.withValues(alpha: 0.94),
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(4),
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
        color: NovaColors.card.withValues(alpha: 0.94),
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(4),
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
                      color: on ? NovaColors.cyan : NovaColors.secondaryText,
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
    Widget dot(Color color, {double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
    Widget entry(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 9),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: NovaColors.card.withValues(alpha: 0.88),
        border: Border.all(color: NovaColors.cardBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final status in RiderStatus.values)
            entry(dot(StatusPill.colorForRider(status)), status.label),
          entry(
            const Icon(Icons.warning_rounded, size: 11, color: NovaColors.red),
            'Alert',
          ),
          entry(dot(NovaColors.cyan, opacity: 0.45), 'Stale fix'),
        ],
      ),
    );
  }
}
