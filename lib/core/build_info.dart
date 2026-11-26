/// Build identity baked in at compile time by the Makefile (`--dart-define`):
/// the version (`git describe` without the "v") and the short commit hash.
/// Builds made without the Makefile (plain `flutter run`) report "dev".
library;

const appVersion = String.fromEnvironment('PANDIVE_VERSION', defaultValue: 'dev');
const appCommit = String.fromEnvironment('PANDIVE_COMMIT');
