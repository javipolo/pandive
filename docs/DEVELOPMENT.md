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
- **Web (preview)**: the same app compiled for the browser. See
  [Web build](#web-build).

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
make web            # web app into build/web (see Web build)
make help           # all targets
```

`make linux` / `make run-linux` (rather than plain `flutter run`) inject the
Google OAuth client IDs. `make install-linux` installs the Linux build into
`~/.local` (or `sudo make install-linux PREFIX=/usr/local` system-wide).

### Web build

`make web` builds the browser version into `build/web`, served under
`WEB_BASE_HREF` (default `/pandive/`, the GitHub Pages project path).
`make run-web` builds it for the root and serves it on
<http://localhost:8765>, an authorized origin of the web OAuth client, so
Google login works locally (`127.0.0.1` does not: Google answers
`origin_mismatch`). `flutter run -d chrome` also works, but on a random port
where the login is refused.

**GitHub Pages**: `.github/workflows/web.yml` runs `make web` on every push
to `main` (or by hand from the Actions tab, "Run workflow") and publishes
`build/web` to <https://javipolo.github.io/pandive/>. One-time setup in the
repository: Settings → Pages → Build and deployment → Source: **GitHub
Actions**. The workflow pins the Flutter version (`flutter-version`): bump it
together with the local SDK. After a deploy, browsers may keep the previous
version cached for a while; a hard reload picks up the new one.

How it differs from the native apps (preview):

- **SQLite in WASM**: `lib/core/db/open/` picks the backend with a
  conditional import: FFI on Android/Linux, `package:sqlite3/wasm.dart` on
  web. The data layer only uses `CommonDatabase`, so it compiles for both.
  `web/sqlite3.wasm` must match the `sqlite3` package version in
  `pubspec.lock` (download it from the
  [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases),
  tag `sqlite3-<version>`) and be updated whenever that package is bumped.
- **In-memory only**: the logbook lives in an in-memory file system and is
  gone on reload; the app always starts on the load screen. Its banner says
  changes are lost, or, with Drive sync on, to wait until it syncs.
- **Google Drive**: *Open from Google Drive* on the load screen signs in
  (Google Identity Services popup, `lib/core/services/web_oauth*.dart`),
  downloads the sync file into memory and makes it the sync base, so the
  usual `SyncController` uploads edits back. The token lasts ~1 h and nothing
  is stored (`drive_web_session.dart`): after expiry, or on the next visit,
  the user taps Connect again. A logbook opened from a file starts with sync
  off and no base, so turning sync on asks what to keep instead of
  overwriting Drive. While changes aren't on Drive yet the page asks before
  closing (`unload_guard*.dart`). Backup there shows only the account and
  sync; gzip uses `package:archive` (dart:io's doesn't exist in the
  browser).
- **Platform checks**: use `lib/core/platform.dart` (`isWeb`, `isAndroid`,
  `isLinux`), never `dart:io`'s `Platform`, which throws in the browser.
  Importing `dart:io` compiles on web, but nothing that touches files may
  run there.
- **Hidden on web**: dive computer download, documents, tools
  (import/export), Drive backup/restore (sync stays), and every share/export
  button.

### Releases

The git tag is the version. `make apk` / `make run` / `make linux` pass
`--build-name` (`git describe` without the `v`: `1.1.0`, or
`1.1.0-3-gabc1234-dirty` for a dev build) and `--build-number` (commit
count, so Android's `versionCode` always grows). The `version:` in
`pubspec.yaml` is only a placeholder. The version and the short commit hash
are also passed as `--dart-define` (`PANDIVE_VERSION`, `PANDIVE_COMMIT`) and
shown in About; a plain `flutter run` shows "dev".

```bash
make release                 # v1.1.0 -> v1.2.0 (minor bump, the default)
make release BUMP=patch      # v1.1.0 -> v1.1.1  (or: make release-patch)
make release BUMP=major      # v1.1.0 -> v2.0.0  (or: make release-major)
DRY_RUN=1 make release       # only print the next version and the changelog
make version                 # what versionName / versionCode a build would get
```

`make release` (`scripts/release.sh`) must run on a clean `main` that is
not behind `origin`, with `gh` logged in. It:

1. Takes the latest `vX.Y.Z` tag and bumps it.
2. Writes `release/changelog-X.Y.Z.txt` from the commit subjects since the
   previous tag, grouped into features (`feat:`), fixes (`fix:`) and other. `chore:`
   commits are left out (they don't change the app).
3. Commits it (`chore: release vX.Y.Z`) and creates the annotated tag.
4. Builds the APK from the tagged commit (so `versionName` is exactly
   `X.Y.Z`) into `release/PanDive-Android-vX.Y.Z.apk`. If the build fails,
   the commit and tag are undone locally and nothing is pushed.
5. Pushes `main` and the tag atomically.
6. Runs `gh release create` with the changelog as notes and the APK attached.

APKs in `release/` are gitignored; the changelogs are versioned.

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
5. **Web**: in the same project, create a **Web application** client with
   authorized JavaScript origins `https://javipolo.github.io` and
   `http://localhost:8765` (no redirect URIs: the token model uses a popup).
   Its ID is public (it ships inside the page), so it lives in the
   `Makefile` (`GDRIVE_WEB_CLIENT_ID`), which the Pages workflow also uses.

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
