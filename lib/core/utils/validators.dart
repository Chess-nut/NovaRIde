/// Form validation for the auth screens.
///
/// One place, because the same rule has to hold in more than one screen —
/// the password rule on sign-up is the rule the reset screen will enforce
/// too — and because a rule that lives in a widget is a rule nobody can
/// test without pumping that widget.
///
/// Every function returns null when the value is fine and a sentence when
/// it is not, which is the signature Flutter's [FormFieldValidator] wants.
/// The sentences say what to do, not what went wrong: "Enter your email"
/// rather than "Email is required".
library;

abstract final class Validators {
  /// Deliberately permissive. The real check is whether the confirmation
  /// email arrives; a clever regex here only ever rejects the small number
  /// of people with unusual but valid addresses.
  static String? email(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email address.';
    final at = value.indexOf('@');
    final dot = value.lastIndexOf('.');
    if (at < 1 || dot < at + 2 || dot == value.length - 1 || value.contains(' ')) {
      return 'That does not look like an email address.';
    }
    return null;
  }

  /// Sign-in accepts either, so it cannot apply the username rules — an
  /// address contains characters a username may not.
  static String? emailOrUsername(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email or username.';
    if (value.contains('@')) return email(value);
    return null;
  }

  /// At least 8 characters, with a letter and a digit.
  ///
  /// Both halves are reported in one sentence rather than one at a time:
  /// a form that reveals its rules one failure per attempt is the most
  /// irritating kind.
  static String? password(String? raw) {
    final value = raw ?? '';
    if (value.isEmpty) return 'Enter a password.';
    final tooShort = value.length < 8;
    final noLetter = !RegExp(r'[A-Za-z]').hasMatch(value);
    final noDigit = !RegExp(r'\d').hasMatch(value);
    if (tooShort || noLetter || noDigit) {
      return 'Use at least 8 characters, with a letter and a number.';
    }
    return null;
  }

  /// Sign-in must not apply the sign-up rules: an older account may have a
  /// password that would fail them, and refusing to submit it would lock
  /// someone out of their own account.
  static String? passwordPresent(String? raw) =>
      (raw ?? '').isEmpty ? 'Enter your password.' : null;

  static String? confirmPassword(String? raw, String original) {
    if ((raw ?? '').isEmpty) return 'Type the password again.';
    if (raw != original) return 'The two passwords do not match.';
    return null;
  }

  /// 3–20 characters, letters, digits and underscore. The lowercased form
  /// becomes a document id under `usernames/`, so the character set has to
  /// be one Firestore accepts in a key and a person can say out loud.
  static String? username(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Choose a username.';
    if (value.length < 3) return 'Usernames are at least 3 characters.';
    if (value.length > 20) return 'Usernames are at most 20 characters.';
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(value)) {
      return 'Letters, numbers and underscores only.';
    }
    return null;
  }

  static String? fullName(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Enter your name.';
    if (value.length < 2) return 'Enter your full name.';
    return null;
  }

  /// Optional. Accepts the shapes a Philippine mobile number is written
  /// in — 09xx, +639xx, 639xx — and ignores spaces and dashes.
  static String? phoneNumber(String? raw) {
    final value = (raw ?? '').replaceAll(RegExp(r'[\s-()]'), '');
    if (value.isEmpty) return null;
    if (!RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(value)) {
      return 'Enter a mobile number like 09171234567.';
    }
    return null;
  }
}
