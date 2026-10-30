import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import 'alerts_page.dart';
import 'gps_map_page.dart';
import 'notification_feed_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildProfileCard(context, ref.watch(authStateProvider).profile),
              const SizedBox(height: 16),
              const _FamilyAccessCard(),
              const SizedBox(height: 16),
              _buildQuickStatsRow(),
              const SizedBox(height: 16),
              _buildCircleStatsRow(context),
              const SizedBox(height: 24),
              // showLive is off: nothing is streaming, and a green LIVE
              // dot over three em dashes is the contradiction this pass
              // exists to remove.
              _buildSectionTitle('CURRENT TRIP'),
              const SizedBox(height: 12),
              _buildTripCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('EMERGENCY SOS'),
              const SizedBox(height: 20),
              _buildSosButton(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 0),
    );
  }

  // ---- Top app title + notification bell ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOVARIDE',
              style: TextStyle(
                color: NovaColors.primaryText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'SMART HELMET SYSTEM V4.2',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationFeedPage()),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: 26,
              ),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: NovaColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Rider identity, from `users/{uid}`.
  ///
  /// The name, the initials and the connection state were a hardcoded
  /// persona — "Deor the great", "Rider #NV-08567", "Connected". None of
  /// it was true of whoever was signed in.
  ///
  /// The rider number is gone rather than replaced: it belongs to the
  /// console's roster (`riders/{R-001}`), a mobile account cannot read
  /// that collection, and nothing links the two yet. The username is
  /// shown instead, which is real and is what they signed in with.
  Widget _buildProfileCard(BuildContext context, UserProfile? profile) {
    final name = profile?.displayName ?? '';
    final initials = initialsFrom(name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: NovaColors.pink,
            child: initials.isEmpty
                ? const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 20,
                  )
                : Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Loading…' : name,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile == null ? '' : '@${profile.username}',
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // No helmet reports to this account, so there is nothing to be
          // connected to. Saying "Connected" was the most misleading
          // thing on the screen.
          const _StatusPill(
            label: 'No helmet',
            color: NovaColors.secondaryText,
          ),
        ],
      ),
    );
  }

  // ---- Battery / Hardware / Signal row ----
  //
  // All three came from the helmet, and no helmet reports to a mobile
  // account: telemetry lives on devices/{id}, which the rules refuse,
  // and nothing links an account to a device anyway. 78%, ESP32 and
  // -62 dBm were invented. Em dashes until there is a feed.
  Widget _buildQuickStatsRow() {
    return Row(
      children: const [
        Expanded(
          child: _InfoCard(
            value: Unavailable.dash,
            valueColor: NovaColors.secondaryText,
            label: 'BATTERY',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            value: Unavailable.dash,
            valueColor: NovaColors.secondaryText,
            label: 'HARDWARE',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            value: Unavailable.dash,
            valueColor: NovaColors.secondaryText,
            label: 'SIGNAL',
          ),
        ),
      ],
    );
  }

  // ---- Impact / Air quality / GPS row ----
  Widget _buildCircleStatsRow(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _CircleStatCard(
            icon: Icons.bolt,
            iconColor: NovaColors.green,
            value: Unavailable.dash,
            label: 'IMPACT',
            statusText: 'NO HELMET',
            statusColor: NovaColors.secondaryText,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _CircleStatCard(
            icon: Icons.water_drop_outlined,
            iconColor: NovaColors.secondaryText,
            value: Unavailable.dash,
            // No unit: the helmet reports vapour above its own baseline,
            // not a percentage or a breath concentration.
            label: 'ALCOHOL',
            statusText: 'NO HELMET',
            statusColor: NovaColors.secondaryText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CircleStatCard(
            icon: Icons.location_on_outlined,
            iconColor: NovaColors.cyan,
            value: 'GPS',
            label: 'LOCATION',
            statusText: 'NO FIX',
            statusColor: NovaColors.secondaryText,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GpsMapPage()));
            },
          ),
        ),
      ],
    );
  }

  // ---- Section header, optionally with a "LIVE" indicator ----
  Widget _buildSectionTitle(String title, {bool showLive = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        if (showLive)
          Row(
            children: const [
              Icon(Icons.circle, color: NovaColors.green, size: 8),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  color: NovaColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---- Trip speed / distance / duration + route ----
  //
  // 42 km/h, 8.3 km, 23:47 and "Makati Ave → Bonifacio Global City"
  // were a scripted demo trip. Trips are not recorded anywhere yet —
  // there is no trips collection and no helmet feed to build one from.
  Widget _buildTripCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: _TripMetric(
                  value: Unavailable.dash,
                  unit: 'km/h',
                  label: 'SPEED',
                ),
              ),
              Expanded(
                child: _TripMetric(
                  value: Unavailable.dash,
                  unit: 'km',
                  label: 'DISTANCE',
                ),
              ),
              Expanded(
                child: _TripMetric(
                  value: Unavailable.dash,
                  unit: 'min',
                  label: 'DURATION',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(
                Icons.location_on,
                color: NovaColors.secondaryText,
                size: 16,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No trip in progress',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Big glowing SOS button ----
  Widget _buildSosButton(BuildContext context) {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: NovaColors.red.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Material(
          color: NovaColors.red,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AlertsPage()));
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 30),
                SizedBox(height: 6),
                Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyAccessCard extends ConsumerWidget {
  const _FamilyAccessCard();

  Future<void> _createInvite(
    BuildContext context,
    FamilyRepository repository,
  ) async {
    try {
      final code = await repository.createInvite();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Guardian invite code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This one-use code expires in 24 hours.'),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                  color: NovaColors.cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Copy code'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(familyRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FAMILY ACCESS',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Invite a guardian to your family group. You control what they can view.',
            style: TextStyle(color: NovaColors.primaryText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _createInvite(context, repository),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create guardian invite'),
            ),
          ),
          StreamBuilder<List<FamilyMember>>(
            stream: repository.watchFamilyMembers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: NovaColors.red, fontSize: 11),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final guardianCount = (snapshot.data ?? const [])
                  .where((member) => member.role == 'guardian')
                  .length;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$guardianCount active guardian${guardianCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Small rounded "Connected" badge shown on the profile card.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Battery / Hardware / Signal card.
class _InfoCard extends StatelessWidget {
  final String value;
  final Color valueColor;
  final String label;

  const _InfoCard({
    required this.value,
    required this.valueColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Impact / % Clean / GPS card with an icon circle and status dot.
class _CircleStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;

  const _CircleStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.statusText,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: statusColor, size: 6),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One metric (speed / distance / duration) inside the trip card.
class _TripMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _TripMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
