/// Small formatting helpers shared across the console.
///
/// Hand-rolled rather than pulling in `intl` — the project has zero
/// non-Flutter dependencies and these are three format strings.
library;

/// "1m 04s" / "2h 13m" / "—" for null.
String formatDuration(Duration? duration) {
  if (duration == null) return '—';
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) {
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '${duration.inMinutes}m ${seconds}s';
  }
  return '${duration.inSeconds}s';
}

/// "2:28:04 PM"
String formatClock(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final second = t.second.toString().padLeft(2, '0');
  return '$hour12:$minute:$second ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "12 Mar 2025"
String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// ISO-8601 without the sub-second noise — used by the CSV export.
String formatIso(DateTime? t) =>
    t == null ? '' : t.toIso8601String().split('.').first;
