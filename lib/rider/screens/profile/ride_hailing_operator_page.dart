import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "Ride-Hailing Operator" screen.
///
/// NovaRide is currently scoped to Angkas riders only, so this isn't a
/// multi-operator picker (yet) — it shows the linked operator and lets the
/// rider save the Angkas rider ID that ties their NovaRide account to
/// their Angkas account. Local state only for now; saving to a backend
/// comes later.
class RideHailingOperatorPage extends StatefulWidget {
  const RideHailingOperatorPage({super.key});

  @override
  State<RideHailingOperatorPage> createState() => _RideHailingOperatorPageState();
}

class _RideHailingOperatorPageState extends State<RideHailingOperatorPage> {
  final _idController = TextEditingController(text: 'AK-2291045');

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: NovaColors.card,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Saved locally — syncing to your account comes with backend integration',
          style: TextStyle(color: NovaColors.primaryText),
        ),
      ),
    );
  }

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
                    _buildOperatorCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('LINKED ACCOUNT'),
                    const SizedBox(height: 12),
                    _buildIdCard(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NovaColors.cyan,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
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
            'Ride-Hailing Operator',
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

  Widget _buildOperatorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.two_wheeler, color: NovaColors.green, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Angkas',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your registered ride-hailing operator',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: NovaColors.green, size: 7),
                SizedBox(width: 5),
                Text(
                  'Linked',
                  style: TextStyle(
                    color: NovaColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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

  Widget _buildIdCard() {
    return Container(
      width: double.infinity,
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
            'Angkas Rider ID',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _idController,
            style: const TextStyle(color: NovaColors.primaryText, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: NovaColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NovaColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NovaColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NovaColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This links your NovaRide safety data to your Angkas account so '
            'trip and alert history stay consistent across both apps.',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}