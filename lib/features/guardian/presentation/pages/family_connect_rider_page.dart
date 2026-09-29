import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

class FamilyConnectRiderPage extends StatelessWidget {
  const FamilyConnectRiderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'Connect to a Rider',
                    style: TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter Rider Code',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: NovaColors.card,
                  hintText: 'NOVA-XXXX',
                  hintStyle: const TextStyle(color: NovaColors.secondaryText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: NovaColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: NovaColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: NovaColors.cyan),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Send Connection Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(color: NovaColors.cardBorder),
              const SizedBox(height: 22),
              const Text(
                'Scan Rider QR Code',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: NovaColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: NovaColors.cardBorder),
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: NovaColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NovaColors.cyan, width: 1.5),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: NovaColors.cyan, size: 44),
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
