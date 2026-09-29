import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "Emergency Contacts" screen — the people who get an SMS + GPS location
/// the moment SOS is triggered (see AlertsPage's "Contacts to be Notified").
/// Opened from the Profile screen's ACCOUNT card.
class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContact {
  String name;
  String relationship;
  String phone;

  _EmergencyContact({required this.name, required this.relationship, required this.phone});
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final List<_EmergencyContact> _contacts = [
    _EmergencyContact(name: 'David Chester M. Legarde', relationship: 'Sibling', phone: '+63 917 234 5678'),
    _EmergencyContact(name: 'Denzil P. Legarde', relationship: 'Sibling', phone: '+63 918 345 6789'),
    _EmergencyContact(name: 'Ralph Lluewyne U. Natal', relationship: 'Sibling', phone: '+63 919 456 7890'),
    _EmergencyContact(name: 'Hanz Jibriel C. Agbayani', relationship: 'Sibling', phone: '+63 920 567 8901'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('YOUR CONTACTS'),
                    const SizedBox(height: 12),
                    if (_contacts.isEmpty)
                      _buildEmptyState()
                    else
                      ..._contacts.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ContactCard(
                                contact: entry.value,
                                onEdit: () => _openContactSheet(existingIndex: entry.key),
                                onDelete: () => _deleteContact(entry.key),
                              ),
                            ),
                          ),
                    const SizedBox(height: 8),
                    _buildAddButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                'Emergency Contacts',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'People notified when SOS is triggered',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.pink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.pink.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: NovaColors.pink, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'These contacts automatically receive an SMS with your GPS '
              'location whenever the emergency SOS is activated.',
              style: TextStyle(
                color: NovaColors.secondaryText.withValues(alpha: 0.95),
                fontSize: 12,
                height: 1.4,
              ),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.contact_phone_outlined, color: NovaColors.secondaryText, size: 30),
          SizedBox(height: 10),
          Text(
            'No emergency contacts yet',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _openContactSheet(),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: NovaColors.cyan),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.add, color: NovaColors.cyan, size: 20),
        label: const Text(
          'ADD CONTACT',
          style: TextStyle(
            color: NovaColors.cyan,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _deleteContact(int index) {
    final removed = _contacts[index];
    setState(() => _contacts.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NovaColors.card,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${removed.name} removed',
          style: const TextStyle(color: NovaColors.primaryText),
        ),
      ),
    );
  }

  void _openContactSheet({int? existingIndex}) {
    final isEditing = existingIndex != null;
    final existing = isEditing ? _contacts[existingIndex] : null;

    final nameController = TextEditingController(text: existing?.name ?? '');
    final relationshipController = TextEditingController(text: existing?.relationship ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NovaColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isEditing ? 'Edit Contact' : 'Add Contact',
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _buildSheetField(
                  controller: nameController,
                  hint: 'Full name',
                  icon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                _buildSheetField(
                  controller: relationshipController,
                  hint: 'Relationship (e.g. Spouse, Parent)',
                  icon: Icons.people_outline,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Relationship is required' : null,
                ),
                const SizedBox(height: 12),
                _buildSheetField(
                  controller: phoneController,
                  hint: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NovaColors.cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        if (isEditing) {
                          _contacts[existingIndex] = _EmergencyContact(
                            name: nameController.text.trim(),
                            relationship: relationshipController.text.trim(),
                            phone: phoneController.text.trim(),
                          );
                        } else {
                          _contacts.add(_EmergencyContact(
                            name: nameController.text.trim(),
                            relationship: relationshipController.text.trim(),
                            phone: phoneController.text.trim(),
                          ));
                        }
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    child: Text(
                      isEditing ? 'SAVE CHANGES' : 'ADD CONTACT',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: NovaColors.secondaryText, fontSize: 13),
        prefixIcon: Icon(icon, color: NovaColors.secondaryText, size: 19),
        filled: true,
        fillColor: NovaColors.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: border(NovaColors.cardBorder),
        enabledBorder: border(NovaColors.cardBorder),
        focusedBorder: border(NovaColors.cyan),
        errorBorder: border(NovaColors.red),
        focusedErrorBorder: border(NovaColors.red),
        errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final _EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({required this.contact, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: NovaColors.pink.withValues(alpha: 0.18),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: NovaColors.pink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.relationship} · ${contact.phone}',
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: NovaColors.secondaryText, size: 19),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: NovaColors.red, size: 19),
          ),
        ],
      ),
    );
  }
}