/// A person a rider wants told in an emergency who does not use the app —
/// a grandparent, a neighbour. Stored at
/// `riderProfiles/{uid}/emergencyContacts/{id}`; operations can read them
/// to call these people during an incident.
///
/// Nothing texts them automatically: the only automatic text is the one
/// the helmet sends to the number set on its own setup page.
library;

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.createdAt,
  });

  /// Empty for a contact not saved yet.
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final DateTime? createdAt;

  EmergencyContact copyWith({String? name, String? relationship, String? phone}) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      createdAt: createdAt,
    );
  }

  factory EmergencyContact.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyContact(
      id: id,
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      createdAt: _dateFrom(map['createdAt']),
    );
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is DateTime) return value;
    try {
      final converted = (value as dynamic)?.toDate();
      return converted is DateTime ? converted : null;
    } catch (_) {
      return null;
    }
  }
}
