import 'package:flutter/material.dart';
import 'package:novaride/family/data/family_repository.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/family/widgets/family_status_badge.dart';
import 'package:novaride/shared/theme.dart';

class FamilyMonitoringPage extends StatelessWidget {
  const FamilyMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FamilyRepository();
    return StreamBuilder<FamilyConnectedRider>(
      stream: repo.watchRiderStatus(),
      initialData: repo.connectedRider,
      builder: (context, snapshot) {
        final rider = snapshot.data ?? repo.connectedRider;
        return Scaffold(
          backgroundColor: NovaColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/family-dashboard'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Rider Monitoring',
                        style: TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: NovaColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: NovaColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: NovaColors.cyan,
                          child: Text('JD', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Juan dela Cruz',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FamilyStatusBadge(status: rider.status, isCompact: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: rider.status.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: rider.status.color.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.status == FamilyRiderStatus.safe || rider.status == FamilyRiderStatus.riding
                              ? 'RIDER IS SAFE'
                              : rider.status.label,
                          style: TextStyle(
                            color: rider.status.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'NovaRide is monitoring the rider.',
                          style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoGrid(rider: rider),
                  const SizedBox(height: 24),
                  const FamilySectionTitle(label: 'ACTIVITY TIMELINE'),
                  const SizedBox(height: 12),
                  _buildTimeline(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 0),
        );
      },
    );
  }

  Widget _buildTimeline() {
    final items = [
      _TimelineItem(time: '10:32 AM', title: 'Trip Started'),
      _TimelineItem(time: '10:45 AM', title: 'GPS Updated'),
      _TimelineItem(time: '10:51 AM', title: 'Normal Impact'),
      _TimelineItem(time: '10:55 AM', title: 'Location Updated'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.circle, size: 10, color: index == 0 ? NovaColors.green : NovaColors.cyan),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 44,
                      color: NovaColors.cardBorder,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.time,
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TimelineItem {
  final String time;
  final String title;

  const _TimelineItem({required this.time, required this.title});
}

class _InfoGrid extends StatelessWidget {
  final FamilyConnectedRider rider;

  const _InfoGrid({required this.rider});

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoBox(label: 'Current Speed', value: '${rider.speedKmh.toInt()} km/h', color: NovaColors.cyan),
      _InfoBox(label: 'Location', value: rider.address, color: NovaColors.green),
      _InfoBox(label: 'GPS Accuracy', value: '±5.2 m', color: NovaColors.pink),
      _InfoBox(label: 'Last Update', value: '2 seconds ago', color: NovaColors.amber),
      _InfoBox(label: 'Trip Duration', value: '${rider.tripDurationMinutes} min', color: NovaColors.green),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.75,
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              item.value,
              style: TextStyle(
                color: item.color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _InfoBox {
  final String label;
  final String value;
  final Color color;

  const _InfoBox({required this.label, required this.value, required this.color});
}
