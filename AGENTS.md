# Pandive — notes for agents

Pandive is an Android dive logbook (Flutter) that replaces DiveMate. One diver,
no photos. It reads/writes the **same SQLite `.ddb` format as DiveMate** (no
migration), so the user's `../divemate-cli` keeps working on Pandive's database.

## Reglas del proyecto (estrictas)

- **Localización rápida**: antes de buscar con Grep/Glob, lee `PROJECT_MAP.md`
  para ir directo al `.dart` exacto.
- **Arquitectura feature-first**: organiza `lib/` en `core/` (tema, rutas,
  servicios globales, widgets genéricos) y `features/<nombre>/` (subcarpetas
  `screens/`, `widgets/`, `logic/` o `providers/`).
- **Anti-anidamiento (regla de oro Flutter)**: objetivo **~200 líneas** por
  `.dart` (guía blanda, no límite duro). Si un `build()` crece o un fichero
  mezcla responsabilidades (UI + lógica, varias pantallas), extrae sub-widgets
  privados o ficheros en `features/<nombre>/widgets/` o `logic/`. El número
  orienta; manda la cohesión: un fichero de ~180 líneas coherente es mejor que
  tres de 60 troceados a la fuerza. NO comprimas código legible (borrar líneas en
  blanco, partir expresiones) solo para bajar del número. Pasado ~250 líneas casi
  siempre toca trocear de verdad.
- **Separación UI vs lógica**: la lógica de negocio y el estado van fuera de los
  widgets visuales (usa el gestor de estado que ya haya o el más simple, sin
  sobreingeniería).
- **Mantenimiento del mapa**: cada vez que crees, muevas o borres un fichero en
  `lib/`, actualiza `PROJECT_MAP.md` en el mismo turno.
- **Control de comandos**: NO ejecutes `flutter build` ni lances emuladores
  automáticamente, EXCEPTO el build obligatorio tras cada commit (`make
  apk-release`, ver Workflow). Fuera de ese caso, solo `flutter analyze` (o
  `make analyze`) tras un cambio grande para verificar.
- **Operaciones largas: feedback siempre y sin bloquear**. Toda acción que
  pueda tardar (importar, exportar, leer/escribir ficheros, red, procesar
  muchos registros) muestra **en el acto** un diálogo que diga qué está
  pasando: spinner con texto (`withProgress`, `core/widgets/progress_dialog.dart`)
  o barra de progreso (`withProgressBar`, `core/widgets/import_progress.dart`).
  Nunca dejar la app "pensando" sin aviso. Y no bloquear el hilo: en Android
  el código Dart corre en el hilo principal, y >5 s de trabajo síncrono es un
  ANR ("la app no responde"). Trocear con `await` entre bloques y agrupar
  escrituras en `db.inTransaction` (sin transacción cada sentencia hace su
  propio commit a disco).
- **Importaciones**: antes de importar, mostrar la lista de lo que se va a
  importar para revisarla y desmarcar (verde nuevo / ámbar ya existe), y al
  terminar llevar al usuario a la lista de buceos refrescada
  (`requestDivesList()` + volver a la raíz), no dejarlo en la pantalla de
  herramientas.
- **i18n obligatorio**: TODO texto visible al usuario va traducido. Nunca
  hardcodees cadenas en la UI; usa claves de `AppLocalizations`
  (`final t = AppLocalizations.of(context); ... t.miClave`). Al añadir cualquier
  feature, añade su texto a **todos** los `lib/l10n/app_<code>.arb` (mismas
  claves en todos; `app_en.arb` es la plantilla y lleva los `@clave` con
  placeholders) y ejecuta `flutter gen-l10n`. Fechas con
  `DateFormat(patrón, Localizations.localeOf(context).languageCode)`, no locale
  fijo. **Añadir un idioma nuevo** (p.ej. catalán) = crear `app_ca.arb` con las
  mismas claves traducidas; `supportedLocales` lo recoge solo. Mantén las claves
  sincronizadas entre idiomas (si falta una, el build avisa). Idioma elegible en
  Ajustes (`Settings.locale`).

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
  body only if it adds something. End with the Co-Authored-By trailer the harness
  specifies.
- **Build after every commit.** Right after committing, run `make apk-release`
  (arm64 release APK for sideload) so the user finds it ready. This overrides the
  "no `flutter build`" rule below, but only for the post-commit build.

## Commands (see `Makefile`)

- `make apk` — debug APK (sideload)        `make run` — build+install+run on device
- `make install` — install last APK        `make test` — unit + real-DB tests
- `make analyze` — static analysis         `make ldc-android` — cross-compile libdivecomputer
- `make help` — list all targets

Flutter is **not** on the PATH in non-interactive shells on this machine; the
Makefile resolves it. For raw commands, prepend:
`export PATH="$HOME/javi/git/flutter/bin:$HOME/javi/Android/platform-tools:$PATH"`.

Gradle needs **JDK 17** (not the default Java 25); already configured via
`flutter config --jdk-dir`.

## Layout

- `lib/models.dart` — domain models (Dive, DiveProfile, Cylinder, DiveSite, LogbookStats).
- `lib/db/divemate_db.dart` — the data layer: opens the `.ddb`, owner detection,
  queries, profile decode, and writes (allowlisted columns). **Frontend-agnostic.**
- `lib/settings.dart` — text scale (accessibility) + active DB path.
- `lib/ui/` — screens: load_db, home (tabs), dives_tab, sites_tab, stats_tab,
  dive_detail_screen, edit_dive_screen, profile_chart, text_scale_sheet.
- `scripts/build-libdivecomputer-android.sh` — NDK cross-compile.
- `vendor/libdivecomputer/` — upstream C library (gitignored clone).

## Database (DiveMate `.ddb`)

- Same schema as DiveMate; **do not redesign it**. "Simplify" = hide unused fields
  in the UI, not change columns.
- One diver: the DB may hold several `DiverID`s (demo/imports); the **owner** is the
  one with the most dives. Operate only on the owner.
- Profiles: `Logbook.Profile` = depth (12-char records, first 4 digits = decimetres),
  `Logbook.Profile2` = temperature (11-char records, first 4 = centi-°C; 0 = none),
  `Logbook.ProfileInt` = sample interval (s). Decode ported from `divemate-cli`.
- Sentinel temps like `-300` mean "no reading" — filter them (plausible range only).
- Writes: respect `UUID`/`Status`; set `Updated` to `YYYY-MM-DDTHH:MM:SS` (local).
  Only write columns in the allowlist in `divemate_db.dart`.
- The app edits its **own copy** of the `.ddb` (app documents dir), not the user's
  original. Syncing changes out = export / Drive backup (Fase 3).

## Testing

- `test/real_db_test.dart` runs against the real `DiveMate.ddb` at the repo root
  (skipped if absent) and cross-checks numbers against `divemate-cli` output.
- Write tests must operate on a **temp copy**, never the original `.ddb`.
- On the Linux test host only `libsqlite3.so.0` exists (the unversioned `.so` is in
  `sqlite-devel`); tests override the lib path. On Android, `sqlite3_flutter_libs`
  bundles it.

## Reference: dive computers

Targets (all BLE, confirmed in libdivecomputer): Shearwater Peregrine, Shearwater
Perdix, Mares Puck 4 (`0x35`). BLE bridge via `dc_custom_open` + `DC_TRANSPORT_BLE`
(Subsurface pattern). This is Fase 2.
