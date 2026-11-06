/// A real street map centred on the helmet, with a pin where it is.
///
/// OpenStreetMap through `flutter_map`: no API key, no billing account,
/// and the same map in Chrome and on Android. The tiles are tinted dark to
/// match the app. OpenStreetMap's licence asks for the credit line in the
/// corner; keep it.
///
/// Used by the rider's Location screen and the guardian's Map and Home.
/// Falls back to [fallback] — the street-grid drawing those screens had —
/// before the helmet has a position (a map with no pin would look like a
/// location), and under `flutter test`, which has no network.
///
/// The pin follows the helmet: when a new fix arrives the map glides to
/// it. Between fixes the rider or guardian can pan and zoom freely.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// OpenStreetMap's own tile server. Free for light use like this app's;
/// its policy asks for an identifying user agent, which
/// [TileLayer.userAgentPackageName] supplies.
const String _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// True under `flutter test`. dart:io's [Platform] cannot be read on the
/// web, so that is checked first.
bool get _underTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class NovaLiveMap extends StatefulWidget {
  const NovaLiveMap({
    super.key,
    required this.lat,
    required this.lng,
    required this.pinColor,
    required this.fallback,
    required this.semanticLabel,
    this.padding = EdgeInsets.zero,
    this.zoom = 16,
    this.preview = false,
  });

  final double? lat;
  final double? lng;
  final Color pinColor;

  /// Shown instead before there is a position, and in tests.
  final Widget fallback;

  /// Read out instead of the map.
  final String semanticLabel;

  /// Space covered by overlays (a header on top, a sheet at the bottom), so
  /// the pin sits in the middle of what is visible and the map credit is
  /// not hidden under the sheet.
  final EdgeInsets padding;
  final double zoom;

  /// A small, still map inside a scrolling page: no gestures, so the page
  /// scrolls instead.
  final bool preview;

  @override
  State<NovaLiveMap> createState() => _NovaLiveMapState();
}

class _NovaLiveMapState extends State<NovaLiveMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  LatLng? get _position {
    final lat = widget.lat;
    final lng = widget.lng;
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  /// Puts the pin in the middle of the uncovered part of the map.
  Offset get _offset =>
      Offset(0, (widget.padding.top - widget.padding.bottom) / 2);

  void _centre(double zoom) {
    final to = _position;
    if (to == null || !_ready) return;
    _controller.move(to, zoom, offset: _offset);
  }

  @override
  void didUpdateWidget(NovaLiveMap old) {
    super.didUpdateWidget(old);
    if (old.lat == widget.lat && old.lng == widget.lng) return;
    // Keep the zoom the person chose; only follow the helmet.
    _centre(_ready ? _controller.camera.zoom : widget.zoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    if (position == null || _underTest) return widget.fallback;

    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: position,
          initialZoom: widget.zoom,
          minZoom: 4,
          maxZoom: 19,
          backgroundColor: const Color(0xFF0D1220),
          onMapReady: () {
            _ready = true;
            _centre(widget.zoom);
          },
          interactionOptions: InteractionOptions(
            flags: widget.preview
                ? InteractiveFlag.none
                : InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // Dark tiles: one colour filter over the whole layer, cheaper
          // than filtering each tile.
          darkModeTilesContainerBuilder(
            context,
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: 'ph.edu.tip.novaride',
              maxNativeZoom: 19,
            ),
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 64,
                height: 64,
                child: _Pin(color: widget.pinColor),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(bottom: widget.padding.bottom),
            child: _Credit(compact: widget.preview),
          ),
        ],
      ),
    );
  }
}

/// The helmet: a dot with a ring and a soft halo, like the drawn map's.
class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF0A0E1A), width: 3),
          ),
        ),
      ),
    );
  }
}

/// "© OpenStreetMap contributors", which the map's licence requires.
/// Tapping it opens the copyright page.
class _Credit extends StatelessWidget {
  const _Credit({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ).ignore(),
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xCC0A0E1A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            compact ? '© OSM' : '© OpenStreetMap contributors',
            style: const TextStyle(color: Color(0xFFB8C0D0), fontSize: 12),
          ),
        ),
      ),
    );
  }
}
