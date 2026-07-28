import 'package:flutter/material.dart';
import 'home_page.dart';

/// "Analytics & History" screen — average impact chart, alert history,
/// safety score, and most frequent routes. Opened from the bottom nav
/// bar's ANALYTICS tab.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildSectionTitle('Average Impact Levels'),
              const SizedBox(height: 14),
              _buildImpactChartCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Alert History'),
              const SizedBox(height: 14),
              _buildAlertHistoryCard(),
              const SizedBox(height: 20),
              _buildSafetyScoreCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Most Frequent Routes'),
              const SizedBox(height: 14),
              _buildFrequentRoutesCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 1),
    );
  }

  // ---- Back arrow + title ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics & History',
              style: TextStyle(
                color: NovaColors.primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Your riding insights',
              style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: NovaColors.primaryText,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ---- Average Impact Levels line chart ----
  Widget _buildImpactChartCard() {
    const values = [0.32, 0.18, 0.6, 0.42, 0.62, 0.28, 0.2];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: _ImpactLineChart(values: values, days: days),
          ),
          const SizedBox(height: 10),
          const Text(
            'Measured in G-force (gravity units)',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ---- Alert History list ----
  Widget _buildAlertHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _AlertTile(
            dotColor: NovaColors.cyan,
            title: 'Minor Impact',
            badgeLabel: 'Low',
            badgeColor: NovaColors.cyan,
            dateText: 'May 24, 2026 at 3:45 PM',
            locationText: 'EDSA, Quezon City',
          ),
          Divider(height: 1, color: NovaColors.cardBorder),
          _AlertTile(
            dotColor: Color(0xFFF5A623),
            title: 'Alcohol Warning',
            badgeLabel: 'Medium',
            badgeColor: Color(0xFFF5A623),
            dateText: 'May 20, 2026 at 9:20 AM',
            locationText: 'Makati Avenue',
          ),
          _AlertTile(
            dotColor: NovaColors.cyan,
            title: 'GPS Signal Lost',
            badgeLabel: 'Low',
            badgeColor: NovaColors.cyan,
            dateText: 'May 15, 2026 at 6:30 PM',
            locationText: 'C5 Road, Taguig',
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ---- Safety Score highlight card ----
  Widget _buildSafetyScoreCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NovaColors.green.withValues(alpha: 0.22),
            NovaColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Score',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '92',
                  style: TextStyle(
                    color: NovaColors.green,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Excellent riding behavior',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Based on riding patterns  ',
                        style: TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                      ),
                      TextSpan(
                        text: '+5 this week',
                        style: TextStyle(
                          color: NovaColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up, color: NovaColors.green, size: 26),
          ),
        ],
      ),
    );
  }

  // ---- Most Frequent Routes list ----
  Widget _buildFrequentRoutesCard() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _RouteTile(
            iconColor: NovaColors.cyan,
            title: 'Home to Work',
            subtitle: 'EDSA - Makati CBD',
            trips: '18 trips',
          ),
          Divider(height: 1, color: NovaColors.cardBorder),
          _RouteTile(
            iconColor: NovaColors.green,
            title: 'Work to Mall',
            subtitle: 'Makati - BGC',
            trips: '12 trips',
          ),
          Divider(height: 1, color: NovaColors.cardBorder),
          _RouteTile(
            iconColor: NovaColors.pink,
            title: 'Weekend Route',
            subtitle: 'Quezon City - Laguna',
            trips: '6 trips',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

/// One row inside the Alert History card.
class _AlertTile extends StatelessWidget {
  final Color dotColor;
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final String dateText;
  final String locationText;
  final bool isLast;

  const _AlertTile({
    required this.dotColor,
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    required this.dateText,
    required this.locationText,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: dotColor, size: 8),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: NovaColors.secondaryText, size: 13),
              const SizedBox(width: 6),
              Text(
                dateText,
                style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: NovaColors.secondaryText, size: 13),
              const SizedBox(width: 6),
              Text(
                locationText,
                style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row inside the Most Frequent Routes card.
class _RouteTile extends StatelessWidget {
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trips;
  final bool isLast;

  const _RouteTile({
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trips,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            trips,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple line chart drawn with CustomPainter (no extra chart dependency).
class _ImpactLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> days;

  const _ImpactLineChart({required this.values, required this.days});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYAxisLabels(),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LineChartPainter(values: values),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: days
                    .map((d) => Text(
                          d,
                          style: const TextStyle(
                            color: NovaColors.secondaryText,
                            fontSize: 10,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYAxisLabels() {
    const labels = ['0.6', '0.45', '0.3', '0.15', '0'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: labels
            .map((l) => Text(
                  l,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10),
                ))
            .toList(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  static const double maxValue = 0.6;

  _LineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final dx = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(dx * i, size.height - (values[i] / maxValue) * size.height),
    ];

    // Gridlines
    final gridPaint = Paint()
      ..color = NovaColors.cardBorder
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Fill under the line
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          NovaColors.green.withValues(alpha: 0.28),
          NovaColors.green.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    final linePaint = Paint()
      ..color = NovaColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = NovaColors.green;
    final dotHalo = Paint()..color = NovaColors.background;
    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotHalo);
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}