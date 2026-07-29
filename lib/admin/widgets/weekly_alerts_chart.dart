import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// Seven-bar weekly alert chart drawn with CustomPainter, matching the
/// hand-painted approach already used on the rider analytics page.
class WeeklyAlertsChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;

  const WeeklyAlertsChart({
    super.key,
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _WeeklyAlertsPainter(values: values, labels: labels),
        size: Size.infinite,
      ),
    );
  }
}

class _WeeklyAlertsPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;

  _WeeklyAlertsPainter({required this.values, required this.labels});

  static const _labelGutter = 22.0;
  static const _valueGutter = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return;

    final plotHeight = size.height - _labelGutter - _valueGutter;
    final slot = size.width / values.length;
    final barWidth = (slot * 0.46).clamp(8.0, 36.0);

    _paintGridlines(canvas, size, plotHeight);

    for (var i = 0; i < values.length; i++) {
      final ratio = values[i] / maxValue;
      final barHeight = plotHeight * ratio;
      final centerX = slot * i + slot / 2;
      final top = _valueGutter + (plotHeight - barHeight);

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(centerX - barWidth / 2, top, barWidth, barHeight),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );

      /// Peak day is highlighted in pink so it reads without a legend.
      final isPeak = values[i] == maxValue;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isPeak
              ? [NovaColors.pink, NovaColors.pink.withValues(alpha: 0.35)]
              : [NovaColors.cyan, NovaColors.cyan.withValues(alpha: 0.28)],
        ).createShader(Rect.fromLTWH(0, top, size.width, barHeight));

      canvas.drawRRect(rect, paint);

      _paintText(
        canvas,
        '${values[i]}',
        Offset(centerX, _valueGutter - 6),
        color: isPeak ? NovaColors.pink : NovaColors.primaryText,
        fontSize: 11,
        weight: FontWeight.w700,
        anchorBottom: true,
      );

      _paintText(
        canvas,
        labels[i],
        Offset(centerX, size.height - _labelGutter + 6),
        color: NovaColors.secondaryText,
        fontSize: 10.5,
      );
    }
  }

  void _paintGridlines(Canvas canvas, Size size, double plotHeight) {
    final paint = Paint()
      ..color = NovaColors.cardBorder
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = _valueGutter + plotHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    bool anchorBottom = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(
        center.dx - painter.width / 2,
        anchorBottom ? center.dy - painter.height : center.dy,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WeeklyAlertsPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.labels != labels;
}
