/// The NovaRide map look, shared by the mobile app's live map and the web
/// admin's fleet map so the two read as one product.
///
/// OpenStreetMap's own tiles, tinted dark with flutter_map's
/// [darkModeTilesContainerBuilder]; a dot-with-halo pin; and the
/// "© OpenStreetMap contributors" chip the tile licence asks for.
///
/// Each app passes its own [TileLayer.userAgentPackageName]: OpenStreetMap's
/// tile policy wants every app identified separately.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class NovaMapStyle {
  /// OpenStreetMap's own tile server.
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const maxNativeZoom = 19;

  static const minZoom = 4.0;
  static const maxZoom = 19.0;

  /// What shows under and between the tiles, and all that shows without
  /// them.
  static const background = Color(0xFF0D1220);

  /// The pin's ring and the credit chip's surface. The same value as
  /// `NovaColors.background`; kept here so this file stands alone.
  static const ink = Color(0xFF0A0E1A);

  /// [ink] at 80 %: the credit chip.
  static const inkTranslucent = Color(0xCC0A0E1A);

  /// Secondary text over the map (the credit line).
  static const label = Color(0xFFB8C0D0);

  /// The pin halo's opacity over the pin colour.
  static const haloAlpha = 0.22;

  static const credit = '© OpenStreetMap contributors';
  static const creditCompact = '© OSM';
  static final copyrightUri = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  /// The dark OpenStreetMap layer. One colour filter over the whole layer,
  /// cheaper than filtering each tile.
  static Widget darkTiles(
    BuildContext context, {
    required String userAgentPackageName,
    ErrorTileCallBack? errorTileCallback,
  }) {
    return darkModeTilesContainerBuilder(
      context,
      TileLayer(
        urlTemplate: tileUrl,
        userAgentPackageName: userAgentPackageName,
        maxNativeZoom: maxNativeZoom,
        errorTileCallback: errorTileCallback,
      ),
    );
  }
}

/// The helmet: a solid dot with a dark ring and a soft halo.
///
/// Full size is the mobile app's pin: a 64 px marker, a 56 px halo and a
/// 22 px dot with a 3 px ring. [compact] is the same pin at 0.75×, for a
/// small map with many helmets on it.
class NovaMapPin extends StatelessWidget {
  const NovaMapPin({super.key, required this.color, this.compact = false});

  final Color color;
  final bool compact;

  static const compactScale = 0.75;

  static double scaleOf({required bool compact}) => compact ? compactScale : 1;

  /// The [Marker]'s width and height.
  static double markerSize({bool compact = false}) =>
      64 * scaleOf(compact: compact);
  static double haloSize({bool compact = false}) =>
      56 * scaleOf(compact: compact);
  static double dotSize({bool compact = false}) =>
      22 * scaleOf(compact: compact);
  static double ringWidth({bool compact = false}) =>
      3 * scaleOf(compact: compact);

  @override
  Widget build(BuildContext context) {
    final halo = haloSize(compact: compact);
    final dot = dotSize(compact: compact);
    return Center(
      child: Container(
        width: halo,
        height: halo,
        decoration: BoxDecoration(
          color: color.withValues(alpha: NovaMapStyle.haloAlpha),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: NovaMapStyle.ink,
              width: ringWidth(compact: compact),
            ),
          ),
        ),
      ),
    );
  }
}

/// "© OpenStreetMap contributors" in the bottom-left corner, which the
/// map's licence requires. Tapping it opens the copyright page. Place it as
/// a child of [FlutterMap] (or anywhere that fills the map).
class NovaMapCredit extends StatelessWidget {
  const NovaMapCredit({super.key, this.compact = false});

  /// "© OSM", for a small preview map.
  final bool compact;

  static const _style = TextStyle(color: NovaMapStyle.label, fontSize: 12);
  static const _margin = 6.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);

  /// The corner the chip takes, margin included, so other overlays can
  /// keep clear of it. Measured with the same text and style the chip
  /// draws, so it holds for any font and text scale.
  static Size footprint(BuildContext context, {bool compact = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: compact ? NovaMapStyle.creditCompact : NovaMapStyle.credit,
        style: DefaultTextStyle.of(context).style.merge(_style),
      ),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = Size(
      painter.width + _padding.horizontal + 2 * _margin,
      painter.height + _padding.vertical + 2 * _margin,
    );
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: GestureDetector(
        onTap: () => launchUrl(
          NovaMapStyle.copyrightUri,
          mode: LaunchMode.externalApplication,
        ).ignore(),
        child: Container(
          margin: const EdgeInsets.all(_margin),
          padding: _padding,
          decoration: BoxDecoration(
            color: NovaMapStyle.inkTranslucent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            compact ? NovaMapStyle.creditCompact : NovaMapStyle.credit,
            style: _style,
          ),
        ),
      ),
    );
  }
}
