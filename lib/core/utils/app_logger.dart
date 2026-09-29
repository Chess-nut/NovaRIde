/// The mobile app's logging facade.
///
/// Mobile only. The admin console keeps its `debugPrint` calls: they are
/// few, they are already phrased as operator-facing diagnostics, and
/// swapping them out would touch 29 lines of code that 118 tests cover for
/// no behavioural gain.
///
/// Why a facade rather than calling `logger` directly:
///
/// - **Release builds stay quiet.** Everything below [Level.warning] is
///   dropped when `kReleaseMode` is set, so a defence-day APK does not
///   narrate a rider's session to logcat. This is a privacy property, not a
///   tidiness one: the app handles live GPS positions.
/// - **One place to change the destination.** If a later phase wants
///   Crashlytics, it replaces [_output] here and nothing else.
/// - **Feature code never holds a `Logger`.** It calls `AppLogger.d(...)`,
///   so no file needs to decide how a logger is constructed.
///
/// Never log a credential, an ID token, or a raw location. `AppLogger.d`
/// with a uid is fine; with a password is not.
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

abstract final class AppLogger {
  static Logger _logger = _build();

  static Logger _build() => Logger(
        // printTime is off: the debug console already stamps lines, and in
        // release only warnings and above survive, which are rare enough to
        // read in order.
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          lineLength: 100,
          colors: !kReleaseMode,
          printEmojis: !kReleaseMode,
        ),
        // Debug and info are development affordances; warning and above are
        // things someone should see wherever the app is running.
        level: kReleaseMode ? Level.warning : Level.debug,
      );

  /// Swaps the underlying logger. For tests that need to assert on output,
  /// and for a later phase that adds a remote sink.
  @visibleForTesting
  static void useLogger(Logger logger) => _logger = logger;

  @visibleForTesting
  static void reset() => _logger = _build();

  /// Fine-grained tracing. Dropped in release.
  static void d(Object? message) => _logger.d(message);

  /// Something worth knowing happened — a sign-in, a route redirect.
  /// Dropped in release.
  static void i(Object? message) => _logger.i(message);

  /// Something is wrong but the app carried on.
  static void w(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  /// Something failed. Pass the original [error] — this is where an
  /// exception's real text belongs, as opposed to the screen.
  static void e(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
