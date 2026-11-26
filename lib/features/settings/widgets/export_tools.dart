/// Export/import actions: DiveMate (native .ddb), Subsurface
/// (.ssrf XML), SSI CSV and sites (JSON).
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/export/subsurface_export.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/features/settings/logic/import_from_file.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/sites/logic/export_sites.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Copies the active .ddb to a temp file with a clean name and shares it (like
/// the Subsurface export; a snapshot, it doesn't share the file in use).
Future<void> exportDdb(BuildContext context, Settings settings) async {
  final path = settings.dbPath;
  if (path == null) return;
  final f = await withProgress(
      context, AppLocalizations.of(context).exporting, () async {
    final dir = await getTemporaryDirectory();
    return File(path).copy('${dir.path}/pandive.ddb');
  });
  await shareOrSaveFile(f);
}

/// Exports all sites to JSON (the "Import sites" format).
Future<void> exportAllSites(BuildContext context, DivemateDb db) async {
  final f = await withProgress(context, AppLocalizations.of(context).exporting,
      () => writeSitesJson(db.listSites()));
  await shareOrSaveFile(f);
}

/// Generates the Subsurface XML (with a progress bar) and shares it.
Future<void> exportSubsurface(BuildContext context, DivemateDb db) async {
  final t = AppLocalizations.of(context);
  final f = await withProgressBar(context, title: t.exporting, (p) async {
    final xml = await buildSubsurfaceXml(db, onProgress: p);
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/pandive.ssrf').writeAsString(xml);
  });
  await shareOrSaveFile(f);
}

/// Picks a .ssrf and imports its dives, showing a progress dialog.
/// Returns how many were added, or null if cancelled.
Future<int?> importSubsurface(BuildContext context, DivemateDb db) async {
  final res = await FilePicker.platform.pickFiles(withData: false);
  final path = res?.files.single.path;
  if (path == null || !context.mounted) return null;
  return importSubsurfaceFile(context, db, path);
}

/// Picks the CSV exported from MySSI, parses it (with a "reading" notice) and
/// opens the list to review and untick before importing.
Future<void> importSsi(BuildContext context, DivemateDb db) async {
  final res = await FilePicker.platform.pickFiles(withData: false);
  final path = res?.files.single.path;
  if (path == null || !context.mounted) return;
  await importSsiFile(context, db, path);
}
