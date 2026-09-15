import 'package:novaride/shared/models/models.dart';

/// Field rules for rider onboarding, kept out of the dialog so they can be
/// unit-tested without pumping a widget tree.
///
/// Firebase seam: these run client-side today. The same predicates become
/// Firestore security rules plus a uniqueness constraint on `helmetId` when
/// the mock repository is replaced.
class RiderValidation {
  const RiderValidation._();

  /// Helmet serials are `NR-H1-` followed by exactly three digits.
  static final RegExp helmetIdPattern = RegExp(r'^NR-H1-\d{3}$');

  /// Normalized Philippine mobile: `+63 9XX XXX XXXX`.
  static final RegExp normalizedPhonePattern =
      RegExp(r'^\+63 9\d{2} \d{3} \d{4}$');

  static const int minNameLength = 3;

  // ------------------------------------------------------------------- name

  static String? validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Full name is required';
    if (name.length < minNameLength) {
      return 'Full name must be at least $minNameLength characters';
    }
    return null;
  }

  // -------------------------------------------------------------- helmet ID

  /// [editingRiderId] exempts the rider being edited from the uniqueness
  /// check, so saving an unchanged form does not report a clash with itself.
  static String? validateHelmetId(
    String? value, {
    required Iterable<Rider> existing,
    String? editingRiderId,
  }) {
    final helmetId = value?.trim().toUpperCase() ?? '';
    if (helmetId.isEmpty) return 'Helmet ID is required';
    if (!helmetIdPattern.hasMatch(helmetId)) {
      return 'Helmet ID must look like NR-H1-001';
    }

    final clash = existing.any(
      (r) => r.helmetId.toUpperCase() == helmetId && r.id != editingRiderId,
    );
    if (clash) return 'Helmet $helmetId is already assigned';

    return null;
  }

  // ------------------------------------------------------------------ phone

  /// Accepts `09XXXXXXXXX`, `+639XXXXXXXXX`, `639XXXXXXXXX` and any of those
  /// with spaces or dashes, and returns the canonical `+63 9XX XXX XXXX`.
  /// Returns null when the input is not a valid PH mobile number.
  static String? normalizePhone(String? value) {
    if (value == null) return null;

    // Strip everything the user might have typed as separators.
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');

    String? subscriber;
    if (cleaned.startsWith('+63')) {
      subscriber = cleaned.substring(3);
    } else if (cleaned.startsWith('63') && cleaned.length == 12) {
      subscriber = cleaned.substring(2);
    } else if (cleaned.startsWith('0')) {
      subscriber = cleaned.substring(1);
    } else {
      subscriber = cleaned;
    }

    // A PH mobile subscriber number is 10 digits starting with 9.
    if (subscriber.length != 10) return null;
    if (!RegExp(r'^9\d{9}$').hasMatch(subscriber)) return null;

    return '+63 ${subscriber.substring(0, 3)} '
        '${subscriber.substring(3, 6)} ${subscriber.substring(6)}';
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    if (normalizePhone(value) == null) {
      return 'Use a PH mobile number, e.g. 0917 402 8813';
    }
    return null;
  }

  // --------------------------------------------------------------- next IDs

  /// Next free `R-###`, one past the highest currently in use.
  static String nextRiderId(Iterable<Rider> riders) =>
      'R-${_nextSequence(riders.map((r) => r.id), r'^R-(\d+)$')}';

  /// Suggested helmet serial for a new rider — the operator can override it.
  static String nextHelmetId(Iterable<Rider> riders) =>
      'NR-H1-${_nextSequence(riders.map((r) => r.helmetId), r'^NR-H1-(\d+)$')}';

  static String _nextSequence(Iterable<String> values, String pattern) {
    final regex = RegExp(pattern);
    var highest = 0;
    for (final value in values) {
      final match = regex.firstMatch(value.toUpperCase());
      if (match == null) continue;
      final number = int.tryParse(match.group(1)!) ?? 0;
      if (number > highest) highest = number;
    }
    return (highest + 1).toString().padLeft(3, '0');
  }
}
