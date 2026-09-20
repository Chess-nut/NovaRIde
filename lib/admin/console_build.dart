/// What the console says it is, in the muted line at the foot of the login
/// page. Operations tools show what they are running; during a demo it is
/// also the fastest way to confirm the build on the projector is the one
/// that was meant to be there.
///
/// Flutter injects no dart-define for the app's own version and the project
/// takes no package to read `pubspec.yaml` at runtime, so [consoleVersion]
/// mirrors the pubspec by hand — bump both together. [consoleBuild] defaults
/// to the pubspec build number and can be overridden for a tagged build:
///
///     flutter build web --dart-define=NOVARIDE_BUILD=$(git rev-parse --short HEAD)
library;

/// Mirrors `version:` in `pubspec.yaml`.
const consoleVersion = '1.0.0';

/// Mirrors the `+N` build number in `pubspec.yaml` unless overridden.
const consoleBuild = String.fromEnvironment('NOVARIDE_BUILD', defaultValue: '1');

/// "v1.0.0 (1)", or "v1.0.0 (df2feb1)" for a tagged build.
const consoleVersionLabel = 'v$consoleVersion ($consoleBuild)';
