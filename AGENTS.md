# Pandive — notes for agents

Pandive is a dive logbook for Android and Linux (Flutter). One diver, no photos.
It reads/writes the **same SQLite `.ddb` format as DiveMate** (no migration), so
DiveMate logbooks open as is and other tools that read them keep working.

## Project rules (strict)

- **Fast lookup**: before searching with Grep/Glob, read `PROJECT_MAP.md` to go
  straight to the right `.dart` file.
- **Feature-first architecture**: organize `lib/` into `core/` (theme, routes,
  global services, generic widgets) and `features/<name>/` (subfolders
  `screens/`, `widgets/`, `logic/` or `providers/`).
- **No deep nesting (Flutter golden rule)**: aim for **~200 lines** per `.dart`
  (soft guideline, not a hard limit). If a `build()` grows or a file mixes
  responsibilities (UI + logic, several screens), extract private sub-widgets
  or files into `features/<name>/widgets/` or `logic/`. The number is a guide;
  cohesion rules: one coherent ~180-line file beats three 60-line files split
  by force. Do NOT squash readable code (removing blank lines, cramming
  expressions) just to get under the number. Past ~250 lines it almost always
  needs a real split.
- **UI vs logic separation**: business logic and state live outside visual
  widgets (use the existing state management, or the simplest one, no
  over-engineering).
- **Keep the map up to date**: whenever you create, move or delete a file in
  `lib/`, update `PROJECT_MAP.md` in the same turn.
- **Command control**: do NOT run `flutter build` or launch emulators on your
  own, EXCEPT the mandatory build after each commit (`make apk`, see
  Workflow). Otherwise only `flutter analyze` (or `make analyze`) after a big
  change to verify.
- **Long operations: always give feedback, never block**. Any action that may
  take time (import, export, reading/writing files, network, processing many
  records) shows **immediately** a dialog saying what is going on: spinner
  with text (`withProgress`, `core/widgets/progress_dialog.dart`) or progress
  bar (`withProgressBar`, `core/widgets/import_progress.dart`). Never leave
  the app "thinking" without notice. And don't block the thread: on Android
  Dart code runs on the main thread, and >5 s of synchronous work is an ANR
  ("app not responding"). Split work with `await` between chunks and group
  writes in `db.inTransaction` (without a transaction every statement commits
  to disk on its own).
- **Imports**: before importing, show the list of what will be imported to
  review and untick (green new / amber already exists), and when done take
  the user to the refreshed dive list (`requestDivesList()` + pop to root),
  not leave them on the tools screen.
- **i18n is mandatory**: ALL user-visible text is translated. Never hardcode
  strings in the UI; use `AppLocalizations` keys
  (`final t = AppLocalizations.of(context); ... t.myKey`). When adding any
  feature, add its text to **every** `lib/l10n/app_<code>.arb` (same keys in
  all; `app_en.arb` is the template and carries the `@key` entries with
  placeholders) and run `flutter gen-l10n`. Dates with
  `DateFormat(pattern, Localizations.localeOf(context).languageCode)`, never a
  fixed locale. **Adding a language** = create `app_<code>.arb` with the same
  keys translated; `supportedLocales` picks it up automatically. Keep keys in
  sync across languages (the build warns if one is missing). Language is
  selectable in Settings (`Settings.locale`).
- **Docs in English**: all `.md` files are written in English. User docs go in
  `README.md` / `docs/importing.md`; developer docs in `docs/DEVELOPMENT.md`.

## Workflow

- **Commit per feature, automatically.** When you finish a logical feature (or a
  self-contained fix), commit it straight away — don't wait to be asked and don't
  batch several unrelated features into one commit. One logical change per commit.
- **Work on `main`.** No feature branches for this repo.
- Only **push** when the user asks.
- Keep commits focused: code + its tests + any doc/README update for that feature
  go together.
- Run `make test` and `make analyze` before committing; don't commit red.
- Commit messages: short imperative subject (`feat:`, `fix:`, `docs:`, `chore:`),
  body only if it adds something. Do **not** add a Co-Authored-By trailer.
- **Build after every commit.** Right after committing, run `make apk`
  (arm64 release APK for sideload) so it is ready to install. This overrides the
  "no `flutter build`" rule above, but only for the post-commit build.

## Commands (see `Makefile`)

- `make apk` — release APK (sideload)      `make run` — build+install+run on device
- `make install` — install release APK     `make test` — unit + real-DB tests
- `make analyze` — static analysis         `make ldc-android` — cross-compile libdivecomputer
- `make help` — list all targets

The Makefile finds `flutter` on the `PATH` (override with `FLUTTER=…`,
`ANDROID_HOME=…`). Gradle needs **JDK 17**. Setup details in
`docs/DEVELOPMENT.md`.

## Layout

See `PROJECT_MAP.md` for every file in `lib/`. Highlights:

- `lib/core/db/` — the data layer (one library with `part`s): opens the `.ddb`,
  owner detection, queries, profile decode/encode, writes. **Frontend-agnostic.**
- `lib/core/models/` — domain models. `lib/features/<name>/` — screens/widgets/logic.
- `native/` + `android/app/src/main/{kotlin,cpp}` + `linux/runner/dc/` — the
  libdivecomputer bridge and BLE transports.
- `scripts/build-libdivecomputer-*.sh` — native builds.
- `vendor/libdivecomputer/` — upstream C library (gitignored clone).

## Database (DiveMate `.ddb`)

- Same schema as DiveMate; **do not redesign it**. "Simplify" = hide unused fields
  in the UI, not change columns.
- One diver: the DB may hold several `DiverID`s (demo/imports); the **owner** is the
  one with the most dives. Operate only on the owner.
- Profiles: `Logbook.Profile` = depth (12-char records, first 4 digits = decimetres),
  `Logbook.Profile2` = temperature (11-char records, first 4 = centi-°C; 0 = none),
  `Logbook.ProfileInt` = sample interval (s).
- Sentinel temps like `-300` mean "no reading" — filter them (plausible range only).
- Writes: respect `UUID`/`Status`; set `Updated` to `YYYY-MM-DDTHH:MM:SS` (local).
  Only write columns in the allowlist in `divemate_db.dart`.
- The app edits its **own copy** of the `.ddb` (app documents dir), not the user's
  original. Changes leave the device via export, Drive backup or Drive sync.

## Testing

- `test/real_db_test.dart` runs against a `DiveMate.ddb` at the repo root
  (skipped if absent).
- Write tests must operate on a **temp copy**, never the original `.ddb`.
- Tests override the SQLite lib path for hosts with only `libsqlite3.so.0`
  (no `sqlite-devel`). On Android, `sqlite3_flutter_libs` bundles it.

## Dive computers

Download goes through libdivecomputer over BLE only: the app provides the
transport via `dc_custom_open` + `DC_TRANSPORT_BLE` (Subsurface pattern), Kotlin
on Android and BlueZ on Linux.
