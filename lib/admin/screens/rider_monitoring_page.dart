import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// Placeholder until the live GPS map lands in Phase 5.
class RiderMonitoringPage extends StatelessWidget {
  const RiderMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: NovaColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.map_outlined, color: NovaColors.cyan, size: 30),
            ),
            const SizedBox(height: 18),
            const Text(
              'Live map — Phase 5',
              style: TextStyle(
                color: NovaColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 420,
              child: Text(
                'Real-time helmet GPS tracking, per-rider drill-down and trip '
                'history will be integrated here once the ESP32 telemetry feed '
                'is connected.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
