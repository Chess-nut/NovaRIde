import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// Which legal document to render. Kept as an enum (rather than two
/// separate screens) since both are just a title + a list of sections —
/// no reason to duplicate the scaffold and styling twice.
enum LegalDocument { terms, privacy }

/// One section of a legal document: a heading and its body text.
class _LegalSection {
  final String heading;
  final String body;

  const _LegalSection(this.heading, this.body);
}

/// "Terms of Service" / "Privacy Policy" screen — reached from the
/// consent checkbox on Signup.
///
/// The copy below is placeholder text written to match what NovaRide
/// actually does per the Capstone scope (GPS tracking, alcohol/impact
/// sensor data, sharing location with emergency contacts and TNVS
/// operators during an SOS, Firebase cloud storage) — it is NOT reviewed
/// legal language and should be replaced before any real launch.
class LegalDocumentPage extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentPage({super.key, required this.document});

  String get _title => switch (document) {
        LegalDocument.terms => 'Terms of Service',
        LegalDocument.privacy => 'Privacy Policy',
      };

  List<_LegalSection> get _sections => switch (document) {
        LegalDocument.terms => const [
            _LegalSection(
              '1. Acceptance of Terms',
              'By creating a NovaRide account, you agree to these Terms of Service and to '
                  'the Privacy Policy. If you do not agree, please do not use the app.',
            ),
            _LegalSection(
              '2. What NovaRide Does',
              'NovaRide pairs a smart helmet IoT device with this mobile application to '
                  'detect crashes, monitor breath alcohol level, and share your live GPS '
                  'location with your emergency contacts and your ride-hailing operator '
                  'when an emergency SOS is triggered.',
            ),
            _LegalSection(
              '3. Account Responsibilities',
              'You are responsible for keeping your login credentials secure and for '
                  'keeping your emergency contact list accurate and up to date. Emergency '
                  'response depends on this information being correct.',
            ),
            _LegalSection(
              '4. Emergency Alerts Are Not Guaranteed',
              'NovaRide is designed to reduce emergency response time, but it cannot '
                  'guarantee that an alert will be delivered, that GPS location will be '
                  'accurate, or that help will arrive. NovaRide is not a substitute for '
                  'calling local emergency services directly when you are able to.',
            ),
            _LegalSection(
              '5. Acceptable Use',
              'You agree not to misuse the app, tamper with the helmet hardware in a way '
                  'that disables crash detection, or submit false emergency contact '
                  'information.',
            ),
            _LegalSection(
              '6. Changes to These Terms',
              'We may update these Terms as the app evolves. Continued use of NovaRide '
                  'after an update means you accept the revised Terms.',
            ),
          ],
        LegalDocument.privacy => const [
            _LegalSection(
              '1. Information We Collect',
              'To provide crash detection and emergency response, NovaRide collects: your '
                  'name, email, and phone number; your emergency contacts\' names and phone '
                  'numbers; real-time GPS location; speed; helmet impact (accelerometer) '
                  'readings; breath alcohol sensor readings; and helmet battery and '
                  'connection status.',
            ),
            _LegalSection(
              '2. How We Use Your Information',
              'This data is used to detect possible crashes, run the SOS abort countdown, '
                  'notify your emergency contacts and ride-hailing operator during an '
                  'emergency, show your ride history and safety score, and improve crash '
                  'detection accuracy.',
            ),
            _LegalSection(
              '3. Who We Share It With',
              'Your live location and emergency status are shared with your registered '
                  'emergency contacts and your ride-hailing operator only when an SOS is '
                  'triggered, or when you choose to share your location manually. We do not '
                  'sell your personal data.',
            ),
            _LegalSection(
              '4. Where Your Data Is Stored',
              'Ride and sensor data is stored on our cloud database (Firebase) so that it '
                  'remains available even if your phone is offline or your app is closed.',
            ),
            _LegalSection(
              '5. Your Choices',
              'You can edit or remove emergency contacts, change notification preferences, '
                  'and adjust GPS tracking intervals at any time from your Profile settings. '
                  'You may request deletion of your account and associated data by '
                  'contacting support.',
            ),
            _LegalSection(
              '6. Data Retention',
              'We retain ride history and alert logs for as long as your account is active, '
                  'so you can review past trips and safety reports.',
            ),
          ],
      };

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
                    _buildPlaceholderNotice(),
                    const SizedBox(height: 20),
                    const Text(
                      'Last updated: August 2026',
                      style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    for (final section in _sections) ...[
                      Text(
                        section.heading,
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section.body,
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
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
          Text(
            _title,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: NovaColors.amber, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Placeholder copy for development. Replace with reviewed legal '
              'text before release.',
              style: TextStyle(color: NovaColors.secondaryText, fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}