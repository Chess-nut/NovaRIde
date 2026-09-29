import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../legal_document_page.dart';

/// "About NovaRide" screen — app identity, version, and legal links.
/// Reuses the existing [LegalDocumentPage] (already built for Signup)
/// instead of duplicating that content here.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
                    _buildAppCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('LEGAL'),
                    const SizedBox(height: 12),
                    _buildCard(context, [
                      _AboutTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalDocumentPage(document: LegalDocument.terms),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 16),
                      _AboutTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalDocumentPage(document: LegalDocument.privacy),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    const Center(
                      child: Text(
                        'NovaRide v4.2.0',
                        style: TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Built by Group 13 · IT 400 Capstone Project',
                        style: TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                      ),
                    ),
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
          const Text(
            'About NovaRide',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_motorsports, color: NovaColors.green, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'NovaRide',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'An IoT smart-helmet framework for real-time accident detection '
            'and emergency response for ride-hailing riders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 12.5, height: 1.5),
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

  Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AboutTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: NovaColors.secondaryText, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: NovaColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}