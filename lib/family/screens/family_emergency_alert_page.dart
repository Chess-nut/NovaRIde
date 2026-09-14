import 'package:flutter/material.dart';
import 'package:novaride/family/data/family_repository.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyEmergencyAlertPage extends StatelessWidget {
  const FamilyEmergencyAlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FamilyRepository();
    return StreamBuilder<FamilyConnectedRider>(
      stream: repo.watchRiderStatus(),
      initialData: repo.connectedRider,
      builder: (context, snapshot) {
        final rider = snapshot.data ?? repo.connectedRider;
        final isResolved = rider.status == FamilyRiderStatus.resolved;

        return Scaffold(
          backgroundColor: isResolved ? NovaColors.background : const Color(0xFF1B0D12),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/family-dashboard'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Text(
                        isResolved ? 'Emergency Resolved' : 'EMERGENCY ALERT',
                        style: TextStyle(
                          color: isResolved ? NovaColors.primaryText : NovaColors.red,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!isResolved)
                    const Text(
                      'Juan dela Cruz may need help.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    const Text(
                      'The emergency has been resolved.',
                      style: TextStyle(
                        color: NovaColors.secondaryText,
                        fontSize: 17,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isResolved ? NovaColors.card : NovaColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isResolved ? NovaColors.cardBorder : NovaColors.red.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            color: NovaColors.secondaryText,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isResolved ? 'RESOLVED' : 'ACCIDENT DETECTED',
                          style: TextStyle(
                            color: isResolved ? NovaColors.green : NovaColors.red,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(label: 'Impact', value: 'High'),
                        _InfoRow(label: 'Location', value: 'EDSA, Quezon City'),
                        _InfoRow(label: 'Time', value: '10:56 AM'),
                        _InfoRow(label: 'GPS', value: '14.5995° N / 120.9842° E'),
                        if (isResolved) ...[
                          _InfoRow(label: 'Duration', value: '00:03:12'),
                          _InfoRow(label: 'Final Status', value: 'Rider Confirmed Safe'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isResolved)
                    const Text(
                      'Emergency contacts have been notified.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (!isResolved) ...[
                    _EmergencyActionButton(label: 'CALL RIDER', icon: Icons.call, color: NovaColors.green),
                    const SizedBox(height: 12),
                    _EmergencyActionButton(label: 'VIEW LIVE LOCATION', icon: Icons.map_outlined, color: NovaColors.cyan),
                    const SizedBox(height: 12),
                    _EmergencyActionButton(label: 'CONTACT EMERGENCY SERVICES', icon: Icons.local_hospital, color: NovaColors.red),
                  ] else ...[
                    _EmergencyActionButton(label: 'RETURN TO DASHBOARD', icon: Icons.home, color: NovaColors.cyan),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 2, showAlertBadge: true),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _EmergencyActionButton({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          if (label == 'RETURN TO DASHBOARD') {
            Navigator.of(context).pushReplacementNamed('/family-dashboard');
          }
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
