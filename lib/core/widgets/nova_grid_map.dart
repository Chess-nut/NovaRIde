/// A drawn stand-in for a map: a street grid and, when there is a
/// position, a marker in the middle.
///
/// It shows *that* there is a fix and its state (live, old, emergency),
/// not where it is — the coordinates and the "Open in Google Maps" button
/// next to it do that. Same look as the rider's GPS screen.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NovaGridMap extends StatelessWidget {
  const NovaGridMap({
    super.key,
    required this.semanticLabel,
    this.markerColor,
    this.showMarker = true,
    this.height,
    this.borderRadius = 12,
  });

  /// Read out instead of the drawing, e.g. "Chester's last position,
  /// 2 hours old".
  final String semanticLabel;

  /// Defaults to the "riding" colour.
  final Color? markerColor;
  final bool showMarker;

  /// Null fills the parent.
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final map = CustomPaint(
      painter: _GridMapPainter(
        ground: colors.surfaceSunken,
        grid: colors.border,
        avenue: colors.borderStrong,
        marker: markerColor ?? colors.riding,
        ring: colors.surfaceSunken,
        showMarker: showMarker,
      ),
      child: const SizedBox.expand(),
    );
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: height == null ? map : SizedBox(height: height, child: map),
      ),
    );
  }
}

class _GridMapPainter extends CustomPainter {
  _GridMapPainter({
    required this.ground,
    required this.grid,
    required this.avenue,
    required this.marker,
    required this.ring,
    required this.showMarker,
  });

  final Color ground;
  final Color grid;
  final Color avenue;
  final Color marker;
  final Color ring;
  final bool showMarker;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    final minor = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }

    final major = Paint()
      ..color = avenue
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.35), major);
    canvas.drawLine(Offset(size.width * 0.66, 0),
        Offset(size.width * 0.66, size.height), major);

    if (!showMarker) return;
    final centre = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(centre, 26, Paint()..color = marker.withValues(alpha: 0.16));
    canvas.drawCircle(centre, 11, Paint()..color = ring);
    canvas.drawCircle(centre, 8, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(_GridMapPainter old) =>
      old.ground != ground ||
      old.grid != grid ||
      old.marker != marker ||
      old.showMarker != showMarker;
}
