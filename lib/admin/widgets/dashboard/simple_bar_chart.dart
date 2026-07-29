import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// The one bar chart on the dashboard. "Alerts by area", "alert priority" and
/// "alert types" differ only in data, colour and whether the y-axis is
/// labelled, so they all feed this widget rather than each owning a painter.
class SimpleBarChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final Color barColor;

  /// Off for the narrow "by area" panel, where eight slots need every pixel.
  final bool showYAxisLabels;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.barColor,
    this.showYAxisLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: SimpleBarChartPainter(
        values: values,
        labels: labels,
        barColor: barColor,
        showYAxisLabels: showYAxisLabels,
      ),
    );
  }
}

class SimpleBarChartPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color barColor;
  final bool showYAxisLabels;

  SimpleBarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    this.showYAxisLabels = true,
  });

  /// Room under the plot for the x-axis labels.
  static const _labelGutter = 14.0;

  /// Headroom so a full-height bar never touches the panel title.
  static const _topGutter = 6.0;
  static const _gridlines = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.height <= _labelGutter + _topGutter) return;

    final maxValue = _niceMax(values.reduce((a, b) => a > b ? a : b));
    final axisWidth = showYAxisLabels ? _measureAxis(maxValue) : 0.0;
    final plotLeft = axisWidth;
    final plotWidth = size.width - plotLeft;
    final plotHeight = size.height - _labelGutter - _topGutter;
    if (plotWidth <= 0) return;

    _paintGridlines(canvas, size, plotLeft, plotWidth, plotHeight, maxValue);

    final slot = plotWidth / values.length;
    final barWidth = (slot * 0.52).clamp(4.0, 30.0);
    final fill = Paint()..color = barColor;

    for (var i = 0; i < values.length; i++) {
      final centerX = plotLeft + slot * i + slot / 2;
      final barHeight = plotHeight * (values[i] / maxValue);

      if (barHeight > 0) {
        final top = _topGutter + (plotHeight - barHeight);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(centerX - barWidth / 2, top, barWidth, barHeight),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          fill,
        );
      }

      _paintLabel(
        canvas,
        labels[i],
        Offset(centerX, size.height - _labelGutter + 3),
        maxWidth: slot - 2,
        align: TextAlign.center,
      );
    }
  }

  void _paintGridlines(
    Canvas canvas,
    Size size,
    double plotLeft,
    double plotWidth,
    double plotHeight,
    int maxValue,
  ) {
    final paint = Paint()
      ..color = NovaColors.cardBorder
      ..strokeWidth = 1;

    for (var i = 0; i <= _gridlines; i++) {
      final y = _topGutter + plotHeight * (i / _gridlines);
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotLeft + plotWidth, y),
        paint,
      );

      if (!showYAxisLabels) continue;
      final value = (maxValue * (1 - i / _gridlines)).round();
      _paintLabel(
        canvas,
        '$value',
        Offset(0, y - 5),
        maxWidth: plotLeft - 4,
        align: TextAlign.left,
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset topLeft, {
    required double maxWidth,
    required TextAlign align,
  }) {
    if (maxWidth <= 0) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      // Long district names shrink to fit rather than colliding with the
      // neighbouring slot.
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final dx = align == TextAlign.center
        ? topLeft.dx - painter.width / 2
        : topLeft.dx;
    painter.paint(canvas, Offset(dx, topLeft.dy));
  }

  /// Widest y-axis label plus a little breathing room.
  double _measureAxis(int maxValue) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$maxValue',
        style: const TextStyle(fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 6;
  }

  /// Rounds up so the three gridlines land on whole numbers.
  int _niceMax(int raw) {
    if (raw <= 0) return _gridlines;
    return (raw / _gridlines).ceil() * _gridlines;
  }

  @override
  bool shouldRepaint(covariant SimpleBarChartPainter old) =>
      !listEquals(old.values, values) ||
      !listEquals(old.labels, labels) ||
      old.barColor != barColor ||
      old.showYAxisLabels != showYAxisLabels;
}
