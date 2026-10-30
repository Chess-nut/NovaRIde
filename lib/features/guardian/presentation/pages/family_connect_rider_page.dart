import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/shared/theme.dart';

class FamilyConnectRiderPage extends ConsumerStatefulWidget {
  const FamilyConnectRiderPage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  ConsumerState<FamilyConnectRiderPage> createState() =>
      _FamilyConnectRiderPageState();
}

class _FamilyConnectRiderPageState
    extends ConsumerState<FamilyConnectRiderPage> {
  final _codeController = TextEditingController();
  late final FamilyRepository _repository =
      widget.repository ?? ref.read(familyRepositoryProvider);
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _acceptInvite() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the invite code shared by the rider.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _repository.acceptInvite(code);
      if (mounted) context.go(AppRoutes.guardianHomePath);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  onPressed: () => context.go(AppRoutes.guardianProfilePath),
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
              'Enter family invite code',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                filled: true,
                fillColor: NovaColors.card,
                hintText: 'Enter the one-use code',
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
                errorText: _error,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _acceptInvite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NovaColors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Accept family invitation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Invite codes can be used once and expire after 24 hours. If the code was sent to a specific email address, sign in with that account.',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
