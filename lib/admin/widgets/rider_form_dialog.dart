import 'package:flutter/material.dart';
import 'package:novaride/admin/state/rider_validation.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Add / edit a rider.
///
/// Pops the built [Rider] on save, or null on cancel — the dialog never
/// touches the controller itself, so the page stays the only place that
/// mutates fleet state.
class RiderFormDialog extends StatefulWidget {
  /// Used for the helmet-ID uniqueness check.
  final Iterable<Rider> existingRiders;

  /// Null for an add, populated for an edit.
  final Rider? rider;

  final String suggestedRiderId;
  final String suggestedHelmetId;

  const RiderFormDialog({
    super.key,
    required this.existingRiders,
    required this.suggestedRiderId,
    required this.suggestedHelmetId,
    this.rider,
  });

  @override
  State<RiderFormDialog> createState() => _RiderFormDialogState();
}

class _RiderFormDialogState extends State<RiderFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _helmetController;
  late final TextEditingController _phoneController;
  late RiderStatus _status;

  bool get _isEdit => widget.rider != null;

  /// Fixed for an edit — reassigning a rider's ID would orphan their alerts.
  late final String _riderId;

  @override
  void initState() {
    super.initState();
    final rider = widget.rider;
    _riderId = rider?.id ?? widget.suggestedRiderId;
    _nameController = TextEditingController(text: rider?.fullName ?? '');
    _helmetController = TextEditingController(
      text: rider?.helmetId ?? widget.suggestedHelmetId,
    );
    _phoneController = TextEditingController(text: rider?.phone ?? '');
    _status = rider?.status ?? RiderStatus.idle;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _helmetController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Validation already proved the number parses, so the normalized form is
    // non-null here.
    final phone = RiderValidation.normalizePhone(_phoneController.text)!;
    final existing = widget.rider;

    final rider = Rider(
      id: _riderId,
      fullName: _nameController.text.trim(),
      helmetId: _helmetController.text.trim().toUpperCase(),
      phone: phone,
      status: _status,
      isActive: existing?.isActive ?? true,
      registeredAt: existing?.registeredAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(rider);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NovaColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: NovaColors.cardBorder),
      ),
      title: Text(
        _isEdit ? 'Edit rider — $_riderId' : 'Register rider — $_riderId',
        style: const TextStyle(
          color: NovaColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('FULL NAME'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: _fieldStyle,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('e.g. Renato Villanueva'),
                  validator: RiderValidation.validateFullName,
                ),
                const SizedBox(height: 14),
                _label('HELMET ID'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _helmetController,
                  style: _fieldStyle,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoration('NR-H1-011'),
                  validator: (value) => RiderValidation.validateHelmetId(
                    value,
                    existing: widget.existingRiders,
                    editingRiderId: widget.rider?.id,
                  ),
                ),
                const SizedBox(height: 14),
                _label('MOBILE NUMBER'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  style: _fieldStyle,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration('0917 402 8813'),
                  validator: RiderValidation.validatePhone,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Saved as +63 9XX XXX XXXX. 09XXXXXXXXX is accepted and '
                  'normalized.',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 14),
                _label('INITIAL STATUS'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final status in RiderStatus.values)
                      _StatusOption(
                        status: status,
                        selected: _status == status,
                        onTap: () => setState(() => _status = status),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: NovaColors.secondaryText),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: NovaColors.cyan,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(_isEdit ? 'Save changes' : 'Add rider'),
        ),
      ],
    );
  }

  static const _fieldStyle = TextStyle(
    color: NovaColors.primaryText,
    fontSize: 14,
  );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: NovaColors.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      );

  InputDecoration _decoration(String hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );

    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 13,
      ),
      filled: true,
      fillColor: NovaColors.background,
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      border: border(NovaColors.cardBorder),
      enabledBorder: border(NovaColors.cardBorder),
      focusedBorder: border(NovaColors.cyan),
      errorBorder: border(NovaColors.red),
      focusedErrorBorder: border(NovaColors.red),
      errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final RiderStatus status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RiderStatus.riding => NovaColors.green,
      RiderStatus.idle => NovaColors.cyan,
      RiderStatus.offline => NovaColors.secondaryText,
      RiderStatus.emergency => NovaColors.red,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.18) : NovaColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.65)
                  : NovaColors.cardBorder,
            ),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              color: selected ? color : NovaColors.secondaryText,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
