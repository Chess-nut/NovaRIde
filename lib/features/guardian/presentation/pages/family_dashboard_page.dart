import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_status_badge.dart';
import 'package:novaride/shared/theme.dart';

class FamilyDashboardPage extends ConsumerWidget {
  const FamilyDashboardPage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilyRepository repo =
        repository ?? ref.watch(familyRepositoryProvider);
    return StreamBuilder<FamilyConnectedRider?>(
      stream: repo.watchRiderStatus(),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: NovaColors.background,
          body: SafeArea(
            child: switch ((snapshot.connectionState, snapshot.hasError, snapshot.data)) {
              (_, true, _) => _MessageState(
                title: 'Family data unavailable',
                message: snapshot.error.toString(),
                icon: Icons.cloud_off_outlined,
              ),
              (ConnectionState.waiting, false, _) => const Center(
                child: CircularProgressIndicator(color: NovaColors.cyan),
              ),
              (_, false, null) => const _MessageState(
                title: 'No rider connected',
                message:
                    'Ask the rider to share a family invite code, then connect it from Profile.',
                icon: Icons.family_restroom,
              ),
              (_, false, final rider?) => _DashboardContent(rider: rider),
            },
          ),
          bottomNavigationBar: FamilyBottomNavBar(
            selectedIndex: 0,
            showAlertBadge: snapshot.data?.activeEmergency ?? false,
          ),
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.rider});

  final FamilyConnectedRider rider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family Safety',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: NovaColors.cyan,
                  child: Text(
                    rider.avatarLetters,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
                          color: NovaColors.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        rider.relationship,
                        style: const TextStyle(color: NovaColors.secondaryText),
                      ),
                    ],
                  ),
                ),
                FamilyStatusBadge(status: rider.status, isCompact: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('RIDER STATUS'),
          const SizedBox(height: 10),
          _Card(
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: rider.status.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rider.status.label,
                    style: TextStyle(
                      color: rider.status.color,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (rider.lastUpdated != null)
                  Text(
                    _relativeTime(rider.lastUpdated!),
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('CURRENT TRIP'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.isCurrentlyRiding == null
                      ? 'Trip status unavailable'
                      : rider.isCurrentlyRiding!
                      ? 'Currently riding'
                      : 'No active trip',
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Speed',
                        value: _formatNumber(rider.speedKmh, ' km/h'),
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Trip duration',
                        value: _formatNumber(rider.tripDurationMinutes, ' min'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  rider.destination ?? 'Destination unavailable',
                  style: const TextStyle(color: NovaColors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('LIVE LOCATION'),
          const SizedBox(height: 10),
          _Card(
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: NovaColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rider.address ?? 'No GPS location available',
                    style: const TextStyle(color: NovaColors.primaryText),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.guardianMapPath),
                  child: const Text('Open map'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('HELMET & SAFETY STATUS'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              children: [
                _StatusRow('Helmet', _booleanStatus(rider.helmetConnected)),
                _StatusRow('GPS', _booleanStatus(rider.gpsActive)),
                _StatusRow('Internet', _booleanStatus(rider.internetConnected)),
                _StatusRow('Battery', _formatNumber(rider.batteryPct, '%')),
                _StatusRow('Impact', _booleanStatus(rider.impactNormal)),
                _StatusRow('Alcohol sensor', _booleanStatus(rider.alcoholSafe)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _booleanStatus(bool? value) => switch (value) {
    true => 'Normal',
    false => 'Warning',
    null => 'Unavailable',
  };

  static String _formatNumber(num? value, String suffix) =>
      value == null ? 'Unavailable' : '${value.toStringAsFixed(0)}$suffix';

  static String _relativeTime(DateTime timestamp) {
    final seconds = DateTime.now().difference(timestamp).inSeconds;
    if (seconds < 0) return 'Updated recently';
    if (seconds < 60) return 'Updated $seconds seconds ago';
    final minutes = seconds ~/ 60;
    return 'Updated $minutes minutes ago';
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: NovaColors.cyan),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NovaColors.secondaryText),
          ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: NovaColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: NovaColors.cardBorder),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: NovaColors.secondaryText,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: NovaColors.primaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: NovaColors.secondaryText)),
        Text(value, style: const TextStyle(color: NovaColors.primaryText)),
      ],
    ),
  );
}
