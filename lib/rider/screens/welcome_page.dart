import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import 'login_page.dart';
import 'role_selection_page.dart';

/// "Welcome" screen — the very first thing a rider or emergency contact
/// sees when opening NovaRide, before choosing to Log In or Sign Up.
///
/// Static for now (no entrance/pulse animation) — animation, motion, and
/// polish pass comes later.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _buildLogoMark(),
              const SizedBox(height: 32),
              _buildTitleBlock(),
              const SizedBox(height: 36),
              _buildFeatureRow(),
              const Spacer(flex: 4),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Logo mark ----
  Widget _buildLogoMark() {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NovaColors.card,
        border: Border.all(color: NovaColors.cyan, width: 1.5),
      ),
      child: const Icon(
        Icons.sports_motorsports,
        color: NovaColors.cyan,
        size: 48,
      ),
    );
  }

  // ---- Name + mission-led tagline ----
  Widget _buildTitleBlock() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.2),
            children: [
              TextSpan(text: 'Nova', style: TextStyle(color: NovaColors.primaryText)),
              TextSpan(text: 'Ride', style: TextStyle(color: NovaColors.cyan)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Every second counts after a crash.\nNovaRide makes sure help never waits.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ---- Three-pillar value proposition ----
  Widget _buildFeatureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _FeaturePill(
          icon: Icons.sensors,
          color: NovaColors.pink,
          label: 'Crash\nDetection',
        ),
        _FeaturePill(
          icon: Icons.sos_rounded,
          color: NovaColors.red,
          label: 'Instant\nSOS',
        ),
        _FeaturePill(
          icon: Icons.location_on,
          color: NovaColors.green,
          label: 'Live\nTracking',
        ),
      ],
    );
  }

  // ---- Get Started / Log In actions ----
  Widget _buildActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NovaColors.cyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text(
              'GET STARTED',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text(
                'Log In',
                style: TextStyle(
                  color: NovaColors.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One icon + label pillar in the value-proposition row.
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _FeaturePill({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}