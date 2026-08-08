import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import 'login_page.dart';

/// The two account types NovaRide supports, per the Capstone scope:
/// Motorcycle Rider (wears the helmet) and Emergency Contact (monitors
/// a rider from home). Login is shared between them — only Signup and
/// the resulting dashboard actually differ, so this is the one place
/// the app needs to ask.
enum UserRole { rider, emergencyContact }

/// "Select User Type" screen — shown once, right after Welcome, before
/// Login. Existing users pick their role and land on Login; if they then
/// tap "Sign Up" from there, the role carries forward to Signup.
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: NovaColors.primaryText),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Select User Type',
                        style: TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Are you a Rider or a Family / Emergency Contact user?',
                        style: TextStyle(color: NovaColors.secondaryText, fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      _RoleCard(
                        icon: Icons.sports_motorsports,
                        color: NovaColors.cyan,
                        title: 'Motorcycle Rider',
                        description: 'Wear the smart helmet. Monitor your own helmet status, '
                            'trip stats, and safety score, and trigger SOS if you crash.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(role: UserRole.rider),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        icon: Icons.family_restroom,
                        color: NovaColors.pink,
                        title: 'Family / Emergency Contact',
                        description: "Watch over a rider you care about. Get notified "
                            'instantly during an SOS and track their live location.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(role: UserRole.emergencyContact),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: NovaColors.secondaryText, size: 22),
          ],
        ),
      ),
    );
  }
}