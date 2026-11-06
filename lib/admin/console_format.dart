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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// "12 s ago" / "4 min ago" / "3 h ago" / "2 d ago". A time slightly in the
/// future — the helmet's server clock ahead of this machine's — is "just
/// now", not a negative age.
String formatAgo(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds} s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 48) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

/// The absolute time in Asia/Manila, for tooltips: "6 Nov 2026, 2:28:04 PM
/// PHT". Manila is UTC+8 with no daylight saving, so a fixed offset is the
/// whole time-zone rule — no tz database needed, whatever zone the
/// operator's machine is set to.
String formatManila(DateTime t) {
  final manila = t.toUtc().add(const Duration(hours: 8));
  final wallClock = DateTime(
    manila.year,
    manila.month,
    manila.day,
    manila.hour,
    manila.minute,
    manila.second,
  );
  return '${formatDate(wallClock)}, ${formatClock(wallClock)} PHT';
}

/// [formatAgo] or a dash.
String formatAgoOrDash(DateTime? t) => t == null ? '—' : formatAgo(t);

/// ISO-8601 without the sub-second noise — used by the CSV export.
String formatIso(DateTime? t) =>
    t == null ? '' : t.toIso8601String().split('.').first;
