/// How a position reads on screen, everywhere it appears.
library;

/// "14.30416° N" — five decimals is about a metre.
String formatLatitude(double lat) =>
    '${lat.abs().toStringAsFixed(5)}° ${lat >= 0 ? 'N' : 'S'}';

/// "121.12337° E".
String formatLongitude(double lng) =>
    '${lng.abs().toStringAsFixed(5)}° ${lng >= 0 ? 'E' : 'W'}';

/// When the GPS fix was taken.
///
/// `gpsAgeMs` is how old the fix was *when the helmet wrote* — so the fix
/// was taken at `lastSeen - gpsAgeMs`, not `now - gpsAgeMs`. Null when
/// either is missing.
DateTime? fixTakenAt(DateTime? lastSeen, int? gpsAgeMs) {
  if (lastSeen == null || gpsAgeMs == null) return null;
  return lastSeen.subtract(Duration(milliseconds: gpsAgeMs));
}
