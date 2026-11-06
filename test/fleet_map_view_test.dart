// The interactive fleet map (lib/admin/widgets/fleet_map_view.dart). No
// tile layer is built under `flutter test` — network images fail here — so
// these exercise exactly what must work with the tiles down: markers,
// popups, the camera controls, and a camera that stays put.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/fleet_map_view.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/maps/nova_map_style.dart';
import 'package:novaride/shared/models/models.dart';

final _riders = [
  Rider(
    id: 'R-001',
    fullName: 'Juan Dela Cruz',
    helmetId: 'tracker-001',
    phone: '0917',
    status: RiderStatus.idle,
  ),
  Rider(
    id: 'R-002',
    fullName: 'Maria Santos',
    helmetId: 'tracker-002',
    phone: '0918',
    status: RiderStatus.riding,
  ),
  Rider(
    id: 'R-003',
    fullName: 'No Fix Yet',
    helmetId: 'tracker-003',
    phone: '0919',
    status: RiderStatus.idle,
  ),
];

HelmetTelemetry _t(
  String? riderId,
  String deviceId, {
  double? lat,
  double? lng,
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  return HelmetTelemetry(
    riderId: riderId,
    deviceId: deviceId,
    speedKmh: lat == null ? null : 18,
    batteryPct: null,
    gpsFix: lat != null,
    lat: lat,
    lng: lng,
    lastUpdate: now,
    fixAt: lat == null ? null : now,
    satellites: lat == null ? null : 8,
    alcoholRawIndex: 210,
    alcoholThreshold: 900,
    alcoholDetected: false,
    sw420Active: true,
    tiltDegrees: 4.2,
    orientation: 'Upright',
    safetyEvent: 'Monitoring',
    positionSource: lat == null ? null : PositionSource.deviceStatus,
  );
}

List<HelmetTelemetry> _telemetry({double r1Lat = 14.6091}) => [
  _t('R-001', 'tracker-001', lat: r1Lat, lng: 121.0223),
  _t('R-002', 'tracker-002', lat: 14.6537, lng: 121.0687),
  _t('R-003', 'tracker-003'), // reporting, but no position
  _t(null, 'tracker-900', lat: 14.5547, lng: 121.0244), // nobody's helmet
];

Future<void> _pump(
  WidgetTester tester, {
  List<HelmetTelemetry>? telemetry,
  String? selected,
  ValueChanged<String?>? onRiderTap,
  ValueChanged<String>? onViewRider,
  List<AlertEvent> alerts = const [],
  MapController? controller,
}) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 600,
          child: FleetMapView(
            riders: _riders,
            telemetry: telemetry ?? _telemetry(),
            selectedRiderId: selected,
            onRiderTap: onRiderTap,
            onViewRider: onViewRider,
            alerts: alerts,
            mapController: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder _marker(String id) => find.byKey(ValueKey('helmet-marker-$id'));

void main() {
  testWidgets('one marker per helmet with a position', (tester) async {
    await _pump(tester);
    expect(_marker('R-002'), findsOneWidget);
    expect(_marker('tracker-900'), findsOneWidget, reason: 'unassigned');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no marker for a helmet with no position — never at 0,0', (
    tester,
  ) async {
    await _pump(tester);
    expect(_marker('R-003'), findsNothing);
  });

  testWidgets('tapping a marker opens its popup, for the right rider', (
    tester,
  ) async {
    String? tapped;
    String? viewed;
    await _pump(
      tester,
      onRiderTap: (id) => tapped = id,
      onViewRider: (id) => viewed = id,
    );
    expect(find.byKey(const ValueKey('helmet-popup')), findsNothing);

    await tester.tap(_marker('R-002'));
    await tester.pump();

    final popup = find.byKey(const ValueKey('helmet-popup'));
    expect(popup, findsOneWidget);
    expect(
      find.descendant(of: popup, matching: find.text('Maria Santos')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: popup, matching: find.text('Juan Dela Cruz')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: popup,
        matching: find.text('Raw 210 / threshold 900 — Below threshold'),
      ),
      findsOneWidget,
    );
    expect(tapped, 'R-002');

    await tester.tap(
      find.descendant(of: popup, matching: find.text('View rider')),
    );
    expect(viewed, 'R-002');
  });

  testWidgets('an unassigned helmet opens a popup with no View rider', (
    tester,
  ) async {
    await _pump(tester, onViewRider: (_) {});
    await tester.tap(_marker('tracker-900'));
    await tester.pump();
    final popup = find.byKey(const ValueKey('helmet-popup'));
    expect(
      find.descendant(of: popup, matching: find.text('Unassigned helmet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: popup, matching: find.text('View rider')),
      findsNothing,
    );
    expect(
      find.descendant(of: popup, matching: find.text('Open in Google Maps')),
      findsOneWidget,
    );
  });

  testWidgets('the camera controls are there: zoom, Fit all, Recentre', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await _pump(tester, controller: controller);

    expect(find.byKey(const ValueKey('map-fit-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-recentre')), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);

    final before = controller.camera.zoom;
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(controller.camera.zoom, closeTo(before + 1, 1e-9));
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
    expect(controller.camera.zoom, closeTo(before, 1e-9));
  });

  testWidgets('Fit all frames every marker', (tester) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await _pump(tester, controller: controller);

    controller.move(const LatLng(10, 100), 5); // somewhere else entirely
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('map-fit-all')));
    await tester.pump();

    final bounds = controller.camera.visibleBounds;
    for (final p in const [
      LatLng(14.6091, 121.0223),
      LatLng(14.6537, 121.0687),
      LatLng(14.5547, 121.0244),
    ]) {
      expect(bounds.contains(p), isTrue, reason: '$p is off screen');
    }
  });

  testWidgets(
    'with helmets known on the first frame, it opens framed on them',
    (tester) async {
      // The one-time auto-fit is the map's initial camera fit when the
      // fleet is already known (a page reopened after it loaded), not a
      // move from onMapReady: in the browser that move aborted every tile
      // request and left the basemap blank until the operator moved the
      // map. Tile loading cannot be observed under `flutter test`, so this
      // checks the framing; the blank basemap was checked in Edge.
      final controller = MapController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      final bounds = controller.camera.visibleBounds;
      for (final p in const [
        LatLng(14.6091, 121.0223),
        LatLng(14.6537, 121.0687),
        LatLng(14.5547, 121.0244),
      ]) {
        expect(bounds.contains(p), isTrue, reason: '$p is off screen');
      }
      expect(controller.camera.zoom, greaterThan(kMetroManilaZoom));
    },
  );

  testWidgets('Recentre with nothing to show goes to Metro Manila', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await _pump(tester, telemetry: const [], controller: controller);

    controller.move(const LatLng(10, 100), 5);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('map-recentre')));
    await tester.pump();

    expect(controller.camera.center.latitude, closeTo(14.6091, 1e-6));
    expect(controller.camera.center.longitude, closeTo(121.0223, 1e-6));
    expect(controller.camera.zoom, 12);
  });

  testWidgets('with Follow off, new fixes never move the camera', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await _pump(tester, selected: 'R-001', controller: controller);

    final center = controller.camera.center;
    final zoom = controller.camera.zoom;

    // The selected rider moves a long way.
    await _pump(
      tester,
      selected: 'R-001',
      controller: controller,
      telemetry: _telemetry(r1Lat: 14.7180),
    );

    expect(controller.camera.center, center);
    expect(controller.camera.zoom, zoom);
  });

  testWidgets('with Follow on, the camera keeps the selected rider centred', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await _pump(tester, selected: 'R-001', controller: controller);

    await tester.tap(find.byKey(const ValueKey('map-layer-Follow selected')));
    await tester.pump();
    final state = tester.state<FleetMapViewState>(find.byType(FleetMapView));
    expect(state.following, isTrue);

    await _pump(
      tester,
      selected: 'R-001',
      controller: controller,
      telemetry: _telemetry(r1Lat: 14.7180),
    );
    expect(controller.camera.center.latitude, closeTo(14.7180, 1e-6));
  });

  testWidgets('Follow keeps the operator\'s zoom, as the mobile map does', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await _pump(tester, selected: 'R-001', controller: controller);

    await tester.tap(find.byKey(const ValueKey('map-layer-Follow selected')));
    await tester.pump();
    // The operator zooms in on their own.
    controller.move(controller.camera.center, 17.5);
    await tester.pump();

    await _pump(
      tester,
      selected: 'R-001',
      controller: controller,
      telemetry: _telemetry(r1Lat: 14.7180),
    );
    expect(controller.camera.center.latitude, closeTo(14.7180, 1e-6));
    expect(controller.camera.center.longitude, closeTo(121.0223, 1e-6));
    expect(controller.camera.zoom, 17.5);
  });

  testWidgets('a fix older than 7 min is drawn stale; a fresh one is not', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pump(
      tester,
      telemetry: [
        _t(
          'R-001',
          'tracker-001',
          lat: 14.6091,
          lng: 121.0223,
          at: now.subtract(const Duration(minutes: 6)),
        ),
        _t(
          'R-002',
          'tracker-002',
          lat: 14.6537,
          lng: 121.0687,
          at: now.subtract(const Duration(minutes: 8)),
        ),
      ],
    );

    Finder badge(String id) => find.descendant(
      of: _marker(id),
      matching: find.byKey(const ValueKey('stale-badge')),
    );
    Finder faded(String id) => find.descendant(
      of: _marker(id),
      matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5),
    );

    expect(badge('R-002'), findsOneWidget);
    expect(faded('R-002'), findsOneWidget);
    expect(badge('R-001'), findsNothing);
    expect(faded('R-001'), findsNothing);
  });

  testWidgets('helmet markers are the shared pin, at mobile size or compact', (
    tester,
  ) async {
    await _pump(tester);
    final pin = find.descendant(
      of: _marker('R-002'),
      matching: find.byType(NovaMapPin),
    );
    expect(pin, findsOneWidget);
    expect(tester.getSize(_marker('R-002')), const Size(64, 64));
    expect(
      tester.widget<NovaMapPin>(pin).color,
      StatusPill.colorForRider(RiderStatus.riding),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: FleetMapView(
              riders: _riders,
              telemetry: _telemetry(),
              compactPins: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(_marker('R-002')), const Size(48, 48));
  });

  testWidgets('with a tile layer, the OpenStreetMap credit is bottom-left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: FleetMapView(
              riders: _riders,
              telemetry: _telemetry(),
              // A stand-in: no network under test.
              tileLayerBuilder: (context, onError) =>
                  const SizedBox.expand(key: ValueKey('fake-tiles')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('fake-tiles')), findsOneWidget);
    final credit = find.text(NovaMapStyle.credit);
    expect(credit, findsOneWidget);
    final map = tester.getRect(find.byType(FleetMapView));
    final chip = tester.getRect(credit);
    expect(chip.left - map.left, lessThan(20));
    expect(map.bottom - chip.bottom, lessThan(20));
    // The legend sits to the right of it, not on top of it.
    final legend = find.ancestor(
      of: find.text('Stale fix'),
      matching: find.byType(Wrap),
    );
    expect(legend, findsOneWidget);
    expect(tester.getRect(legend).overlaps(chip), isFalse);
  });

  testWidgets('active alerts with a position get a marker and a popup', (
    tester,
  ) async {
    String? opened;
    await tester.runAsync(() async {});
    final alerts = [
      AlertEvent(
        id: 'A-1',
        riderId: 'R-002',
        riderName: 'Maria Santos',
        type: AlertType.sos,
        lat: 14.62,
        lng: 121.05,
        address: 'Near Cubao',
        timestamp: DateTime.now(),
        status: AlertStatus.open,
      ),
      // No position of its own: not on the map.
      AlertEvent(
        id: 'A-2',
        riderId: 'R-001',
        riderName: 'Juan Dela Cruz',
        type: AlertType.crash,
        lat: null,
        lng: null,
        address: 'Location unavailable',
        timestamp: DateTime.now(),
        status: AlertStatus.open,
      ),
      // Closed: not on the map.
      AlertEvent(
        id: 'A-3',
        riderId: 'R-001',
        riderName: 'Juan Dela Cruz',
        type: AlertType.alcoholWarning,
        lat: 14.60,
        lng: 121.0,
        address: 'Near Sampaloc',
        timestamp: DateTime.now(),
        status: AlertStatus.resolved,
      ),
    ];
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: FleetMapView(
              riders: _riders,
              telemetry: _telemetry(),
              alerts: alerts,
              onAlertTap: (a) => opened = a.id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('alert-marker-A-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('alert-marker-A-2')), findsNothing);
    expect(find.byKey(const ValueKey('alert-marker-A-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('alert-marker-A-1')));
    await tester.pump();
    final popup = find.byKey(const ValueKey('alert-popup'));
    expect(popup, findsOneWidget);
    expect(
      find.descendant(of: popup, matching: find.text('SOS Triggered')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: popup, matching: find.text('View on Alerts page')),
    );
    expect(opened, 'A-1');
  });

  test('Google Maps link: the firmware\'s own, else built from the fix', () {
    final withUrl = _t(
      'R-001',
      'tracker-001',
      lat: 14.6,
      lng: 121.0,
    ).copyWith(mapsUrl: 'https://maps.google.com/?q=14.600000,121.000000');
    expect(
      FleetMapViewState.googleMapsUri(
        withUrl,
        const LatLng(14.6, 121.0),
      ).toString(),
      'https://maps.google.com/?q=14.600000,121.000000',
    );
    final without = _t('R-001', 'tracker-001', lat: 14.6, lng: 121.0);
    expect(
      FleetMapViewState.googleMapsUri(
        without,
        const LatLng(14.6, 121.0),
      ).toString(),
      'https://maps.google.com/?q=14.6,121.0',
    );
  });

  test('the basemap is the mobile map\'s, sent as the admin app', () {
    expect(FleetMapView.background, NovaMapStyle.background);
    expect(FleetMapView.background, const Color(0xFF0D1220));
    expect(FleetMapView.userAgentPackageName, 'ph.edu.tip.novaride.admin');
    expect(kMetroManilaLat, 14.6091);
    expect(kMetroManilaLng, 121.0223);
  });
}
