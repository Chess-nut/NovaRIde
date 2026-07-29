import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Fleet composition at a glance. Counts come straight from the live rider
/// list, so a spawned crash moves a slice from green to red in the same frame
/// it hits the feed.
class FleetStatusDonutPanel extends StatelessWidget {
  final Map<RiderStatus, int> counts;

  const FleetStatusDonutPanel({super.key, required this.counts});

  /// Offline rides at 40% so the "nothing to see here" bucket stays quiet.
  static Color colorFor(RiderStatus status) => switch (status) {
        RiderStatus.riding => NovaColors.green,
        RiderStatus.idle => NovaColors.cyan,
        RiderStatus.emergency => NovaColors.red,
        RiderStatus.offline => NovaColors.secondaryText.withValues(alpha: 0.4),
      };

  /// Fixed order — riding, idle, emergency, offline — so slices never swap
  /// places when the numbers move.
  static const _order = [
    RiderStatus.riding,
    RiderStatus.idle,
    RiderStatus.emergency,
    RiderStatus.offline,
  ];

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, v) => sum + v);

    return DashPanel(
      title: 'Type of rider status',
      child: Row(
        children: [
          Expanded(flex: 4, child: _buildLegend()),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: _buildDonut(total)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final status in _order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 8, height: 8, color: colorFor(status)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.label,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '${counts[status] ?? 0}',
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDonut(int total) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(side, side),
                  painter: _DonutPainter(
                    segments: [
                      for (final status in _order)
                        (
                          value: counts[status] ?? 0,
                          color: colorFor(status),
                        ),
                    ],
                    total: total,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'Riders',
                      style: TextStyle(
                        color: NovaColors.secondaryText,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

typedef _Segment = ({int value, Color color});

class _DonutPainter extends CustomPainter {
  final List<_Segment> segments;
  final int total;

  _DonutPainter({required this.segments, required this.total});

  static const _thickness = 14.0;

  /// 2° of breathing room between slices, in radians.
  static const _gap = 2 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - _thickness) / 2;
    if (radius <= 0) return;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _thickness
      ..color = NovaColors.cardBorder;

    if (total <= 0) {
      canvas.drawCircle(rect.center, radius, track);
      return;
    }

    // Start at 12 o'clock and run clockwise, the way a dial is read.
    var start = -math.pi / 2;

    for (final segment in segments) {
      if (segment.value <= 0) continue;

      final sweep = 2 * math.pi * (segment.value / total);
      // A lone full-circle slice has no neighbour to clear, so it keeps its
      // whole sweep; everything else gives up the gap.
      final drawn = sweep >= 2 * math.pi - _gap ? sweep : sweep - _gap;

      canvas.drawArc(
        rect,
        start + _gap / 2,
        math.max(drawn, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _thickness
          ..strokeCap = StrokeCap.butt
          ..color = segment.color,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total ||
      old.segments.length != segments.length ||
      !_sameValues(old.segments, segments);

  bool _sameValues(List<_Segment> a, List<_Segment> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].color != b[i].color) return false;
    }
    return true;
  }
}
