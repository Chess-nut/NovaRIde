/// Initials for an avatar, from a real name.
///
/// One place, because the rider home and the profile page both draw one
/// and they must not disagree about what a person's initials are.
library;

/// Up to two letters from [name] — first and last word.
///
/// Returns an empty string for a blank name rather than a placeholder
/// letter: an avatar showing "?" is better drawn by the caller, which
/// knows how much room it has.
String initialsFrom(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    final word = words.first;
    // A single name gives up its first two letters rather than one, so
    // the avatar is not lopsided next to two-word ones.
    return word.characters2.toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

extension on String {
  /// The first one or two characters, whichever there are.
  String get characters2 => length >= 2 ? substring(0, 2) : this;
}
