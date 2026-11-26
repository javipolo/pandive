# PROJECT_MAP — index of `lib/`

Read this BEFORE searching with Grep/Glob: it takes you straight to the right `.dart`.
Keep it up to date when creating/moving/deleting files in `lib/`.

Feature-first structure: `core/` (cross-cutting) + `features/<name>/` (each
with `screens/` and, if needed, `widgets/`).

## Core / Config

- `lib/main.dart` -> startup: init locale, load settings, launch the app
- `lib/core/app.dart` -> MaterialApp, global text scale
- `lib/core/build_info.dart` -> appVersion / appCommit baked in by the Makefile (--dart-define) for the About screen
- `lib/core/app_root.dart` -> AppRoot: picks the screen; creates an empty DB on first launch, or the load screen (Change DB / error)
- `lib/core/text/relative_date.dart` -> "human" date: "Today 17:12" / "Yesterday 21:23" / full date (backup list)
- `lib/core/services/home_navigation.dart` -> section requests to HomeScreen (requestDivesList: back to the dive list after importing)
- `lib/core/services/share_file.dart` -> shareOrSaveFile: share (mobile) or "Save as…" (Linux) a generated file + appMessengerKey (snackbars without context)
- `lib/core/services/opened_file.dart` -> incoming .ddb file (open with / share): consume + stream
- `lib/core/services/data_revision.dart` -> global signal for soft tab refresh (without reopening the DB)
- `lib/core/theme/app_theme.dart` -> Material 3 theme (dive blue)
- `lib/core/settings/settings.dart` -> preferences: text scale, DB path, language, theme, night hours, merge gap
- `lib/l10n/app_<code>.arb` -> translations (EN template + ES/CA/EU/FR); `AppLocalizations` is generated with `flutter gen-l10n`
- `lib/core/services/dive_computer.dart` -> libdivecomputer bridge: models, BLE scan, permissions
- `lib/core/services/drive_backup.dart` -> Google Drive backup/restore: native OAuth (flutter_appauth + refresh token in secure_storage, headless), folder, hash (parts)
- `lib/core/services/desktop_oauth.dart` -> Google OAuth on desktop (Linux): loopback 127.0.0.1 + PKCE, refresh over HTTP
- `lib/core/services/drive_backup_ops.dart` -> operations: backupNow/backupIfNeeded/backupIfChanged/list/downloadBackup+applyRestore/pruning
- `lib/core/services/drive_sync_ops.dart` -> Drive for sync: sync-logbook.ddb.gz file (gzip, md5), discarded version as backup, documents zip if changed, per-device presence
- `lib/core/services/network.dart` -> onUnmeteredNetwork (WiFi/ethernet vs mobile data) for the "WiFi only" options
- `lib/core/services/sync_logic.dart` -> pure sync decision (none/upload/download/diverged) from remote md5 + local stamp vs base
- `lib/core/services/image_clipboard.dart` -> copy PNG to the clipboard (Linux: native channel `pandive/clipboard`, GTK)
- `lib/core/services/sync_controller.dart` -> global SyncController (syncController): state, triggers (open/resume, after editing, ~2 min, exit), upload/download/resolve divergence; syncUploadInBackground for the worker
- `lib/core/services/backup_worker.dart` -> WorkManager: periodic background backup (~12h, WiFi) if the DB changed + fallback sync upload on exit (enqueueSyncUpload)
- `lib/core/services/backup_util.dart` -> pure helpers: names (PanDive-….ddb.gz; old latest/pandive-/.ddb names still listed and pruned), maybeGunzip, prune to 10, restoreWouldLoseData
- `lib/core/storage/documents_storage.dart` -> documents/ folder on disk (save/delete/path); used by UI and backup
- `lib/core/services/doc_notifications.dart` -> local expiry notifications (30/7/1/0 days); permission only if there are docs with expiry; payload=docId, tapping opens the document (tappedDocId / consumeNotificationLaunch)

### Core · database (one library with `part`s)
- `lib/core/db/divemate_db.dart` -> opens .ddb, owner, helpers; declares the parts
- `lib/core/db/db_queries.dart` -> reads: list/get dives, cylinders, next number
- `lib/core/db/db_profile.dart` -> profile decode (depth/temperature)
- `lib/core/db/db_stats.dart` -> dive sites and aggregate stats + personalRecords
- `lib/core/db/db_writes.dart` -> writes: edit and create dives
- `lib/core/db/db_import.dart` -> import downloaded dives (dedupe, Profile4 deco, gas)
- `lib/core/db/db_encode.dart` -> encode profiles to DiveMate format (Profile/Profile2/Profile4)
- `lib/core/db/db_sync.dart` -> per-dive fingerprint + sync point (debug) +
  `sampleExtra`/`storeSampleExtra` (PandiveSampleExtra: ppo2/cns/pressure/rbt per sample)
- `lib/core/db/db_create.dart` -> create a new empty .ddb (DiveMate schema + diver)
- `lib/core/db/db_helpers.dart` -> library helpers (parse, uuid, timestamp, row mapping)
- `lib/core/db/db_buddies.dart` -> buddies (Buddy): list, create/rename/delete, dives per buddy, backfillBuddyIds (links old Buddy text)
- `lib/core/db/db_buddies_merge.dart` -> mergeBuddies: merges several buddies into one (reassigns BuddyIDs, deletes the rest)
- `lib/core/db/db_trips.dart` -> trips: create/rename/delete, assign dives (PandiveTripId), trip buddies
- `lib/core/db/db_sites.dart` -> sites (Place): get/create/update, find-or-create
- `lib/core/db/db_tanks.dart` -> cylinders per dive, "my cylinders" presets, dives per site/buddy
- `lib/core/db/db_merge.dart` -> merge dives (concatenated profile, union of data)
- `lib/core/db/db_pending.dart` -> cache of downloaded-but-unsaved dives (they reappear once)
- `lib/core/db/db_dive_types.dart` -> dive types + cylinder template + tags (PandiveDiveTypeTag)
- `lib/core/db/db_computers.dart` -> saved dive computers (by MAC)
- `lib/core/db/db_meta.dart` -> UTC last-write stamp (PandiveMeta + per-table triggers); lastWriteUtc / lastWriteUtcOf(path); key/value in PandiveMeta
- `lib/core/db/db_numbering.dart` -> automatic numbering (consecutive, chronological, from a first number; config in PandiveMeta): renumberPlan/renumberDives/autoRenumber, isOutOfOrder, numberForNewDive
- `lib/core/db/db_documents.dart` -> documents (PandiveDocument): metadata CRUD (image on disk)
- `lib/core/sac.dart` -> SAC/RMV calculation (l/min)
- `lib/core/gas_plan.dart` -> gas planning: gas needed, end pressure, max time (pure logic)
- `lib/core/export/subsurface_export.dart` -> generates the Subsurface XML (.ssrf)
- `lib/core/export/ddb_dive_copy.dart` -> copyDiveToDdb: copies a full dive (data, site, buddies, computer, cylinders, tags, optional profile) to an exported .ddb; used by trip and selection export
- `lib/core/import/subsurface_import.dart` -> imports the Subsurface XML (.ssrf) into the logbook
- `lib/core/import/ssi_csv_import.dart` -> imports the SSI logbook CSV (columns by position; tags; dedupe by day+depth+duration+time with the closest candidate)
- `lib/core/import/ssi_csv_fields.dart` -> SSI CSV cell parsing: CSV, multi-language dates, duration, depth, glued buddies + center + computer
- `lib/core/widgets/import_progress.dart` -> progress-bar dialog for long imports (withProgressBar; importSsrfWithProgress)
- `lib/core/db/db_import_ext.dart` -> inserts an external dive (profile, cylinders, site, buddies, tags) + copyDiveDetailsFrom (copies computer/cylinders/tags/profile between .ddb files)
- `lib/core/text/collate.dart` -> accent-insensitive alphabetical comparison

### Core · models (`models.dart` is the barrel)
- `lib/core/models/models.dart` -> barrel: re-exports all models
- `lib/core/models/dive.dart` -> dive (Logbook row)
- `lib/core/models/dive_profile.dart` -> sampled profile (times/depths/temps)
- `lib/core/models/cylinder.dart` -> cylinder/mix (+ gas label)
- `lib/core/models/dive_site.dart` -> dive site with dive count
- `lib/core/models/dive_computer_ref.dart` -> saved dive computer (MAC+name+model)
- `lib/core/models/dive_type.dart` -> dive type (name + cylinder template + inherited tags)
- `lib/core/models/tag.dart` -> tag + InheritedTag/TagSource (tag a dive gets from its site or dive type)
- `lib/core/models/document.dart` -> diver document (image + expiry); DiveDoc + DocStatus
- `lib/core/models/downloaded_dive.dart` -> dive downloaded from the computer (+ samples/gases, JSON parse)
- `lib/core/models/logbook_stats.dart` -> aggregate stats
- `lib/core/models/personal_records.dart` -> personal records (deepest/longest/coldest dive)
- `lib/core/models/trip.dart` -> trip (name, dive/buddy count, date range)

### Core · shared widgets
- `lib/core/widgets/profile_chart.dart` -> profile chart (depth + temp on right axis, touch line)
- `lib/core/widgets/profile_chart_axes.dart` -> profile chart axes and tooltip
- `lib/core/widgets/save_action.dart` -> AppBar Save button
- `lib/core/widgets/labeled_field.dart` -> text field with label/border
- `lib/core/widgets/star_rating.dart` -> star rating selector
- `lib/core/widgets/date_time_field.dart` -> date+time picker (ListTile)
- `lib/core/widgets/selection_bar.dart` -> action bar in selection (batch) mode
- `lib/core/widgets/confirm_dialog.dart` -> reusable confirmation dialog
- `lib/core/widgets/name_dialog.dart` -> reusable single-field (name) dialog
- `lib/core/widgets/scroll_helpers.dart` -> scrollToHighlight: scrolls the list to the newly added item
- `lib/core/widgets/progress_dialog.dart` -> modal progress dialog (withProgress) for long export/import
- `lib/core/widgets/site_map.dart` -> reusable map (Esri satellite tiles + attribution)

## Features

### home
- `lib/features/home/screens/home_screen.dart` -> shell with tabs and menu
- `lib/features/home/widgets/home_nav_bar.dart` -> bottom bar (Dives/Sites/Buddies)
- `lib/features/home/widgets/home_app_bar.dart` -> AppBar: title/search + actions (sync, search, map/sort, collapse)
- `lib/features/home/widgets/home_tabs.dart` -> tabs (IndexedStack); listens to data_revision for soft refresh
- `lib/features/home/widgets/home_drawer.dart` -> side menu (Tags/Equipment/Stats + Trips/Documents/Tools/Backup/Settings)

### load_db
- `lib/features/load_db/screens/load_db_screen.dart` -> pick/create a .ddb or import .ssrf (with enum DbLoadError)
- `lib/features/load_db/widgets/load_db_buttons.dart` -> buttons: open .ddb / create new / import Subsurface

### tags
- `lib/features/tags/screens/tags_tab.dart` -> tag list (create/rename/delete, view dives)
- `lib/core/db/db_tags.dart` -> tags: per-dive link + per-site link (PandiveSiteTag) + per-dive-type link (PandiveDiveTypeTag, matched by Logbook.Divetype name); effective tags = own ∪ site ∪ type (effectiveTagsForDive); inheritedTags(placeId, diveType) with source; diveIdsWithTag/listDivesByTag include inherited

### sync (between devices)
- `lib/features/sync/widgets/sync_indicator.dart` -> status icon in the top bar (+ syncStatusText)
- `lib/features/sync/widgets/sync_sheet.dart` -> sheet: status, other device open, sync/update/choose version

### backup (Drive backup)
- `lib/features/backup/screens/backup_screen.dart` -> connect account, manual backup, daily auto backup, sync between devices, restore
- `lib/features/backup/widgets/restore_list.dart` -> list of Drive backups to restore; warns if the local DB is newer than the backup

### settings
- `lib/features/settings/screens/settings_screen.dart` -> settings: language, theme, text size, numbering, merge gap, night, DB
- `lib/features/settings/screens/tools_screen.dart` -> tools: renumber dives, import hashtags, export DDB/Subsurface, import SSI CSV, trash, debug sync (from drawer)
- `lib/features/settings/screens/about_screen.dart` -> about / contact: description + report email (mailto, from drawer)
- `lib/features/settings/screens/fill_from_ddb_screen.dart` -> fills own dives by matching against a buddy's .ddb (site/notes/buddies)
- `lib/features/settings/logic/import_dives.dart` -> plan (new/duplicate by date/time) + copy of selected dives from another .ddb (profile/site/buddies/tags/cylinders) with summary (DdbImportResult)
- `lib/features/settings/logic/enrich_logbook.dart` -> matches by date/time and copies data between logbooks
- `lib/features/settings/logic/renumber_tool.dart` -> "Renumber dives" tool: preview of changes + confirmation
- `lib/features/settings/logic/link_buddies_tool.dart` -> tool: fills BuddyIDs of old dives (Buddy text without IDs) so they count
- `lib/features/settings/screens/preview_ddb_screen.dart` -> previews a .ddb read-only; "Import options" FAB with menu (fill / import dives / replace DB)
- `lib/features/settings/screens/import_ddb_dives_screen.dart` -> pick dives from the .ddb to import (green new / amber already exists, skipped) + summary dialog
- `lib/features/settings/screens/import_ssi_screen.dart` -> review the SSI CSV before importing (green new / amber seems to exist, tickable), imports with a bar and goes back to the dive list
- `lib/features/settings/widgets/import_dive_tile.dart` -> checkbox row for the import lists (ddb and SSI)
- `lib/features/settings/screens/trash_screen.dart` -> trash: lists deleted dives (Status=2) and restores them (undelete)
- `lib/features/settings/screens/debug_sync_screen.dart` -> debug: set sync point and delete later dives
- `lib/features/settings/widgets/text_scale_control.dart` -> text size control (slider + −/+)
- `lib/features/settings/widgets/export_tools.dart` -> export to DiveMate (.ddb)/Subsurface (.ssrf)/all sites (JSON) with notice/progress bar, and import from Subsurface / SSI CSV
- `lib/features/settings/widgets/language_theme_selectors.dart` -> language and theme radios
- `lib/features/settings/widgets/merge_gap_control.dart` -> merge gap control (slider + visible value)
- `lib/features/settings/widgets/numbering_control.dart` -> numbering settings: automatic on/off + first number (renumbers)
- `lib/features/settings/widgets/night_hours_control.dart` -> night dive time window (from/to)

### buddies
- `lib/features/buddies/screens/buddies_tab.dart` -> buddy list (add/rename/delete/batch merge); in-tab sort (name/dives/recent) + toggle for collapsed ">2 years" section at the end
- `lib/features/buddies/widgets/buddy_tile.dart` -> buddy row (avatar, dive count, menu, opens their dives)
- `lib/features/buddies/logic/merge_buddies_action.dart` -> dialog to pick which one to keep + merge
- `lib/features/buddies/logic/buddy_sort.dart` -> enum BuddySort {name,dives,recent} + sortBuddiesBy
- `lib/features/buddies/screens/buddy_picker_screen.dart` -> buddy multi-select (for editing a dive): search, dive count, sort (alphabetical/dives/recent)

### dives
- `lib/features/dives/screens/dives_screen.dart` -> list + search + "New" + batch selection (delete/merge)
- `lib/features/dives/screens/dive_detail_screen.dart` -> detail: data, profile, cylinders, edit
- `lib/features/dives/screens/filtered_dives_screen.dart` -> filtered list (site/buddy/tag) with batch actions + inner search
- `lib/features/dives/screens/edit_dive_screen.dart` -> edit editable fields
- `lib/features/dives/screens/new_dive_screen.dart` -> manual entry form
- `lib/features/dives/screens/profile_fullscreen_screen.dart` -> full-screen profile (landscape)
- `lib/features/dives/screens/tag_picker_screen.dart` -> tag multi-select
- `lib/features/dives/widgets/cylinder_tile.dart` -> cylinder card in the detail
- `lib/features/dives/widgets/month_grouped_dives.dart` -> dive list by year and month (collapsible, selectable)
- `lib/features/dives/widgets/dive_group_header.dart` -> group header (year/month) collapsible/selectable
- `lib/features/dives/widgets/dive_row.dart` -> DiveMate-style dive row (big number + 2 lines)
- `lib/features/dives/widgets/add_dive_sheet.dart` -> "add" sheet: manual entry or transfer
- `lib/features/dives/widgets/dives_selection_bar.dart` -> selection bar (stats/merge/delete)
- `lib/features/dives/widgets/dive_editor_form.dart` -> shared body for new/edit (site/buddies/tags/type/fields/cylinders)
- `lib/features/dives/widgets/dive_type_picker_field.dart` -> field + picker sheet for dive type
- `lib/features/dives/widgets/gas_segments.dart` -> gas switches (color/label) for the enlarged chart
- `lib/features/dives/widgets/tags_picker_field.dart` -> chosen tags field (chips)
- `lib/features/dives/widgets/dives_action_list.dart` -> dive list with batch selection + actions (stats/merge/export/delete); used by the tab and filtered lists
- `lib/features/dives/logic/export_selection.dart` -> exports the selected dives to a full .ddb (optional profiles) and shares it; works for "Import dives" and "Fill"
- `lib/features/dives/widgets/export_selection_dialog.dart` -> dialog: logbook name + "also export profiles" checkbox
- `lib/features/dives/widgets/dive_detail_body.dart` -> detail body by sections (number/date, site, profile+metrics, gases, deco, cylinders)
- `lib/features/dives/widgets/profile_section.dart` -> profile section: compact chart + share / full-screen buttons
- `lib/features/dives/logic/share_profile.dart` -> PNG image of the profile (ProfileShareCard: title, chart and footer with duration/min temp/depths/deco; same on all platforms): share (mobile) or copy to clipboard (Linux)
- `lib/features/dives/logic/dive_facts.dart` -> DiveFacts: duration, max/avg depth, min temp, deco (TTS/max ceiling, time with ceiling) from the record + profile; used by the detail and the exported image
- `lib/features/dives/logic/apply_dive_type.dart` -> apply type: drops empty cylinders (no pressures) and adds the type's not already filled (same size+material)
- `lib/features/dives/logic/renumber_after_save.dart` -> after create/edit: renumbers (automatic) or offers to renumber if the dive is out of order
- `lib/features/dives/logic/dive_search.dart` -> accent-insensitive dive search filter (foldContains)
- `lib/features/dives/widgets/dive_detail_fields.dart` -> label/value cell, 2/3-column rows, section separator
- `lib/features/dives/widgets/dive_form.dart` -> editable scalar fields (+ controllers)
- `lib/features/dives/widgets/site_picker_field.dart` -> chosen site field
- `lib/features/dives/widgets/buddies_picker_field.dart` -> chosen buddies field (chips)
- `lib/features/dives/widgets/tanks_editor.dart` -> cylinder editor + SAC
- `lib/features/dives/widgets/tank_edit_sheet.dart` -> sheet to add/edit a cylinder

### plan (gas planner)
- `lib/features/plan/screens/plan_dive_screen.dart` -> interactive planner: preloads averages, recalculates live
- `lib/features/plan/widgets/plan_inputs.dart` -> fields (dive type, RMV, depth, time, volume, start pressure, reserve)
- `lib/features/plan/widgets/plan_results.dart` -> results (gas, colored end pressure per cylinder, margin, max time)
- `lib/features/plan/widgets/plan_reserve_field.dart` -> reserve selector (35/50 bar, thirds 1/3, quarters 1/2, custom)
- `lib/features/plan/widgets/plan_cylinders_field.dart` -> editable cylinder list (litres + reserve/empties flag); PlanCyl

### documents
- `lib/features/documents/screens/documents_screen.dart` -> list with expiry status + add + multi-export to PDF
- `lib/features/documents/screens/document_detail_screen.dart` -> view large image, edit, delete, share (PDF)
- `lib/features/documents/screens/document_edit_screen.dart` -> add/edit metadata (title/notes/expiry)
- `lib/features/documents/screens/crop_screen.dart` -> custom crop (crop_your_image): rotate 90°, free rectangle, confirm
- `lib/features/documents/logic/document_import.dart` -> pick source (camera/gallery/PDF), render PDF, crop, save
- `lib/features/documents/logic/document_export.dart` -> generates a PDF with the selected ones and shares it
- `lib/features/documents/widgets/document_tile.dart` -> row (thumbnail + title + status)
- `lib/features/documents/widgets/document_status.dart` -> color/label per expiry status
- `lib/features/documents/widgets/documents_banner.dart` -> summary notice (expired/expiring soon)

### trips
- `lib/features/trips/screens/trips_screen.dart` -> trip list (create/rename/delete)
- `lib/features/trips/screens/trip_detail_screen.dart` -> detail: buddies (edit/from dives) + view dives
- `lib/features/trips/logic/assign_trip_action.dart` -> dialog to assign the selection to a trip (pick/create)
- `lib/features/trips/logic/export_trip.dart` -> exports/shares trips as .ddb (trip+dives+buddies+cylinders+tags, optional profiles; name Year-Name-PanDive)
- `lib/features/trips/widgets/export_trips_dialog.dart` -> confirmation: trip list + "also export profiles" checkbox (off)

### sites
- `lib/features/sites/screens/sites_screen.dart` -> site list: tap name = dives; eye = info; multi-select (export JSON / delete)
- `lib/features/sites/screens/import_sites_screen.dart` -> JSON import preview (update-only/+new mode, per-row checkbox, add/modify color, confirms count)
- `lib/features/sites/logic/site_import.dart` -> JSON import plan (add/modify, null doesn't overwrite) + applySiteImport
- `lib/features/sites/logic/export_sites.dart` -> exports sites to JSON and shares (sitesToJson/writeSitesJson, JSON generated in another isolate; shared or saved with shareOrSaveFile)
- `lib/features/sites/screens/site_info_screen.dart` -> site info (fields, tags, edit/delete, swipe between sites)
- `lib/features/sites/screens/site_edit_screen.dart` -> add/edit site (fields + GPS location + tags)
- `lib/features/sites/screens/map_picker_screen.dart` -> pick a location on the map (tap + my GPS)
- `lib/features/sites/screens/sites_map_screen.dart` -> viewer of all sites with coords (markers -> view dives)
- `lib/features/sites/widgets/sites_grouped_list.dart` -> list grouped by country (collapse/search by name/country/region/tags/sort by dives); filterSites = the search filter, also used by "select all"
- `lib/features/sites/widgets/site_tile.dart` -> site row (avatar, region · dive count, tag chips, info eye)

### stats
- `lib/features/stats/screens/stats_screen.dart` -> global logbook stats tab
- `lib/features/stats/screens/selection_stats_screen.dart` -> stats for a selection of dives only
- `lib/features/stats/widgets/stats_view.dart` -> reusable view (cards + bars, year/month/week selector; records in global)
- `lib/features/stats/widgets/records_card.dart` -> personal records card (tappable -> opens the dive) + next milestone
- `lib/features/stats/widgets/year_bars.dart` -> PeriodBars: label/value bars
- `lib/features/stats/widgets/stats_buckets.dart` -> group dates by year/month/week (ISO)

### dive_computer
- `lib/features/dive_computer/screens/computer_pick_screen.dart` -> "Dive transfer": tap=download; menu (download all/mark/delete); Search
- `lib/features/dive_computer/screens/scan_screen.dart` -> BLE scan; on pick, offers to save (checkbox)
- `lib/features/dive_computer/screens/download_screen.dart` -> downloads dives from a device and shows them
- `lib/features/dive_computer/widgets/scan_widgets.dart` -> device row, error view, action sheet (download/mark)
- `lib/features/dive_computer/widgets/download_progress.dart` -> circular progress indicator with %
- `lib/features/dive_computer/widgets/downloaded_dive_tile.dart` -> downloaded dive row
- `lib/features/dive_computer/widgets/baseline_done.dart` -> "mark as already imported" confirmation
- `lib/features/dive_computer/widgets/download_result_list.dart` -> selectable list (pick what to save) + mark all
- `lib/features/dive_computer/widgets/download_items.dart` -> builds items (new+pending) and applies the selection

### equipment (dive / cylinder types)
- `lib/features/equipment/screens/equipment_tab.dart` -> hub: dive types + cylinder types
- `lib/features/dive_types/screens/dive_types_screen.dart` -> dive type list (cylinders · #tags summary)
- `lib/features/dive_types/screens/dive_type_edit_screen.dart` -> create/edit type (name + tags + cylinders)
- `lib/features/tank_types/screens/tank_types_screen.dart` -> cylinder type management (presets)
- `lib/features/tank_types/widgets/tank_type_edit_sheet.dart` -> create/edit cylinder type sheet

Native (outside lib/), same channels `pandive/dc`, `pandive/dc/scan`,
`pandive/dc/progress` on both platforms:
- `native/pandive_dc_core.{c,h}` -> shared core over libdivecomputer (matchName, download to JSON; I/O via `pdc_io_t`)
- Android: `android/app/src/main/kotlin/org/drslump/pandive/` (DiveComputer,
  BleScanner, BleConnection, MainActivity) and `android/app/src/main/cpp/pandive_dc.c`
  (JNI adapter for the core).
- Linux: `linux/runner/dc/dc_plugin.c` (MethodChannel + progress + download thread),
  `dc_scanner.c` (BlueZ scan), `bluez_ble.c` (GATT connection over D-Bus);
  `linux/ldc/libdivecomputer.a` (static, `make ldc-linux`).
