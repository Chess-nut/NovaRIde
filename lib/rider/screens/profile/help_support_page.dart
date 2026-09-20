import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "Help & Support" screen — FAQs plus a contact card. Static content for
/// now; wiring "Contact Support" to an actual channel (email/ticket
/// backend) comes later.
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const _faqs = [
    (
      'My helmet won\'t connect',
      'Make sure Bluetooth is on and the helmet is charged. Hold the helmet\'s '
          'power button for 3 seconds until the LED blinks blue, then open '
          'Settings → Helmet Settings and enable Auto-Connect.',
    ),
    (
      'What happens when SOS triggers?',
      'NovaRide sends your live GPS location by SMS and push notification to '
          'every contact in Emergency Contacts, plus your ride-hailing operator. '
          'You have a short countdown to cancel a false alarm before it sends.',
    ),
    (
      'The alcohol sensor gave a false reading',
      'Breath sensors can be affected by mouthwash, hand sanitizer fumes, or '
          'humidity right after putting the helmet on. Wait a minute and let the '
          'sensor take a fresh reading before riding.',
    ),
    (
      'How is my Safety Score calculated?',
      'It factors in harsh-braking events, speeding, impact alerts, and trip '
          'consistency over your last 30 days of rides.',
    ),
    (
      'How do I unpair my helmet?',
      'Go to Settings → Helmet Settings and tap "Unpair Helmet" at the bottom. '
          'You\'ll stop receiving telemetry and safety alerts until you pair it '
          'again.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactCard(context),
                    const SizedBox(height: 24),
                    _buildSectionTitle('FREQUENTLY ASKED QUESTIONS'),
                    const SizedBox(height: 12),
                    _buildFaqCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back, color: NovaColors.primaryText, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help & Support',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'FAQs and ways to reach us',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NovaColors.cyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: NovaColors.cyan, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Still need help?',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'support@novaride.app · Mon–Sat, 8AM–8PM',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: NovaColors.card,
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Live chat support coming soon',
                    style: TextStyle(color: NovaColors.primaryText),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, color: NovaColors.secondaryText, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildFaqCard() {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (int i = 0; i < _faqs.length; i++) ...[
              if (i != 0) const Divider(height: 1, color: NovaColors.cardBorder, indent: 16),
              ExpansionTile(
                iconColor: NovaColors.secondaryText,
                collapsedIconColor: NovaColors.secondaryText,
                title: Text(
                  _faqs[i].$1,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedAlignment: Alignment.topLeft,
                children: [
                  Text(
                    _faqs[i].$2,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}