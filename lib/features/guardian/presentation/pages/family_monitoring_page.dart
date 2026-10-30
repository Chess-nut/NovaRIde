import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_status_badge.dart';
import 'package:novaride/shared/theme.dart';

class FamilyMonitoringPage extends ConsumerWidget {
  const FamilyMonitoringPage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilyRepository repo =
        repository ?? ref.watch(familyRepositoryProvider);
    return StreamBuilder<FamilyConnectedRider?>(
      stream: repo.watchRiderStatus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _stateScaffold(
            Text(
              'Rider data unavailable: ${snapshot.error}',
              style: const TextStyle(color: NovaColors.primaryText),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _stateScaffold(
            const CircularProgressIndicator(color: NovaColors.cyan),
          );
        }
        final rider = snapshot.data;
        if (rider == null) {
          return _stateScaffold(
            const Text(
              'No rider connection',
              style: TextStyle(color: NovaColors.primaryText),
            ),
          );
        }
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
                        onPressed: () => context.go(AppRoutes.guardianHomePath),
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
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: NovaColors.cyan,
                          child: Text(
                            rider.avatarLetters,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rider.name,
                                style: const TextStyle(
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
                          rider.status.label,
                          style: TextStyle(
                            color: rider.status.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Status is based on the latest rider record.',
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
                  StreamBuilder<List<FamilyIncident>>(
                    stream: repo.watchIncidentHistory(),
                    builder: (context, incidentsSnapshot) {
                      if (incidentsSnapshot.hasError) {
                        return Text(
                          'Activity unavailable: ${incidentsSnapshot.error}',
                          style: const TextStyle(color: NovaColors.red),
                        );
                      }
                      if (incidentsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: NovaColors.cyan,
                          ),
                        );
                      }
                      return _buildTimeline(
                        incidentsSnapshot.data ?? const [],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 0),
        );
      },
    );
  }

  Widget _stateScaffold(Widget child) => Scaffold(
    backgroundColor: NovaColors.background,
    body: SafeArea(child: Center(child: child)),
    bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 0),
  );

  Widget _buildTimeline(List<FamilyIncident> incidents) {
    if (incidents.isEmpty) {
      return const Text(
        'No activity recorded.',
        style: TextStyle(color: NovaColors.secondaryText),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: List.generate(incidents.length, (index) {
          final incident = incidents[index];
          final isLast = index == incidents.length - 1;
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
                        '${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        incident.title,
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

class _InfoGrid extends StatelessWidget {
  final FamilyConnectedRider rider;

  const _InfoGrid({required this.rider});

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoBox(label: 'Current Speed', value: rider.speedKmh == null ? 'Unavailable' : '${rider.speedKmh!.toStringAsFixed(0)} km/h', color: NovaColors.cyan),
      _InfoBox(label: 'Location', value: rider.address ?? 'Unavailable', color: NovaColors.green),
      _InfoBox(label: 'GPS Accuracy', value: 'Unavailable', color: NovaColors.pink),
      _InfoBox(
        label: 'Last Update',
        value: rider.lastUpdated == null
            ? 'Unavailable'
            : '${DateTime.now().difference(rider.lastUpdated!).inMinutes} min ago',
        color: NovaColors.amber,
      ),
      _InfoBox(label: 'Trip Duration', value: rider.tripDurationMinutes == null ? 'Unavailable' : '${rider.tripDurationMinutes} min', color: NovaColors.green),
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
