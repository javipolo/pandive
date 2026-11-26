# Developing Pandive

## Architecture

- **App**: Flutter (Dart). Feature-first layout under `lib/` (`core/` +
  `features/<name>/`); [PROJECT_MAP.md](../PROJECT_MAP.md) maps every file.
- **Database**: the DiveMate SQLite `.ddb` schema, unchanged (see
  [below](#database)). The data layer is `lib/core/db/`.
- **Dive computer download**: [libdivecomputer](https://github.com/libdivecomputer/libdivecomputer)
  (C), with a shared core (`native/pandive_dc_core.c`) and a per-platform BLE
  transport plugged into libdivecomputer's custom I/O (`dc_custom_open`):
  - Android: Kotlin + JNI (`android/app/src/main/kotlin/…`, `android/app/src/main/cpp/`).
  - Linux: C over BlueZ / D-Bus (`linux/runner/dc/`), libdivecomputer linked statically.

  Flutter only receives parsed dives (JSON) over the `pandive/dc*` channels.
- **Google Drive**: backup, restore and phone↔PC sync with the `drive.file`
  scope. Design notes in [sync-plan.md](sync-plan.md).

## Requirements

- Flutter SDK (stable) and JDK 17 (Gradle does not support newer JDKs:
  `flutter config --jdk-dir <jdk17>` if your default is newer).
- Android SDK: platform-tools, platform 35, build-tools 35, NDK `27.2.12479018`.
  Android Studio is not needed; the command-line tools are enough.
- Native build tools: clang, cmake, ninja, autotools, pkg-config.
- A **physical Android device**: the emulator has no Bluetooth LE.

On Fedora:

```bash
sudo dnf install -y java-17-openjdk-devel git unzip clang cmake ninja-build \
  autoconf automake libtool pkgconf-pkg-config
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;27.2.12479018"
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor
```

The Makefile expects `flutter` on the `PATH` and `ANDROID_HOME` exported
(pointing to the Android SDK; only needed for the Android targets).

## Building

```bash
git clone https://github.com/libdivecomputer/libdivecomputer.git vendor/libdivecomputer
make dc-libs        # cross-compile libdivecomputer for Android (NDK) and copy it in
make deps           # flutter pub get
make run            # build, install and launch on the connected device
make apk            # arm64 release APK
make linux          # Linux desktop app (make ldc-linux first)
make help           # all targets
```

`make linux` / `make run-linux` (rather than plain `flutter run`) inject the
Google OAuth client IDs. `make install-linux` installs the Linux build into
`~/.local` (or `sudo make install-linux PREFIX=/usr/local` system-wide).

### Releases

The git tag is the version. `make apk` / `make run` / `make linux` pass
`--build-name` (`git describe` without the `v`: `1.1.0`, or
`1.1.0-3-gabc1234-dirty` for a dev build) and `--build-number` (commit
count, so Android's `versionCode` always grows). The `version:` in
`pubspec.yaml` is only a placeholder. The version and the short commit hash
are also passed as `--dart-define` (`PANDIVE_VERSION`, `PANDIVE_COMMIT`) and
shown in About; a plain `flutter run` shows "dev".

```bash
git tag v1.1.0
make release        # -> releases/PanDive-Android-v1.1.0.apk (gitignored)
make version        # what versionName / versionCode a build would get
```

`make release` refuses a dirty tree or an untagged HEAD. Upload the APK
to a GitHub release, e.g. `gh release create v1.1.0 releases/PanDive-Android-v1.1.0.apk`.

### Release signing

Release APKs are signed with `android/key.properties` (not versioned); without
it they fall back to the debug key.

```properties
storeFile=/path/to/keystore.jks
storePassword=…
keyAlias=…
keyPassword=…
```

### Google Drive (OAuth)

Without these client IDs the app works, but *Connect* in Backup does not.
They are read from untracked files and injected as `--dart-define`.

1. In [Google Cloud Console](https://console.cloud.google.com/), create a
   project and enable the **Google Drive API**.
2. OAuth consent screen: *External*, add your account as a test user (the
   `drive.file` scope is not sensitive, so no verification is needed).
3. **Android**: create an OAuth client of type **iOS** with bundle ID
   `org.drslump.pandive` (this only gets a secret-less reversed redirect scheme
   for `flutter_appauth`) and save its client ID in
   `android/gdrive_native_client_id.txt`.
4. **Linux**: in the same project, create a **Desktop app** client and save
   its ID and secret in `linux/gdrive_desktop_client_id.txt` and
   `linux/gdrive_desktop_client_secret.txt`. Same project means both apps see
   the same backups.

## Testing

```bash
make test       # unit tests + tests against a real logbook
make analyze
```

`test/real_db_test.dart` runs against a `DiveMate.ddb` at the repo root and is
skipped if it is absent. Tests that write always work on a temporary copy.

On Linux hosts with only `libsqlite3.so.0` (no `sqlite-devel`), the tests
override the SQLite library path.

## Database

Pandive reads and writes the **DiveMate `.ddb`** schema unchanged, so DiveMate
files open directly and other tools that read them keep working.

- Do not change DiveMate's tables or columns. Pandive-only data lives in its own
  `Pandive*` tables.
- A `.ddb` can hold several divers; Pandive works on the one with the most dives.
- Profiles: `Logbook.Profile` = depth (12-char records, first 4 digits =
  decimetres), `Profile2` = temperature (11-char records, first 4 = centi-°C),
  `ProfileInt` = sample interval in seconds. Sentinel temperatures like `-300`
  mean "no reading".
- Writes keep `UUID`/`Status` and set `Updated` (`YYYY-MM-DDTHH:MM:SS`, local).
  Deleted dives are `Status=2` (trash).
- `PandiveMeta` stores the last-write timestamp (kept by triggers, used by
  backup and sync) and logbook-wide settings such as dive numbering.

## Translations

All user-visible text lives in `lib/l10n/app_<code>.arb` (`app_en.arb` is the
template). Add a key to every file and run `flutter gen-l10n`. To add a
language, create `app_<code>.arb` with the same keys; it is picked up
automatically.
