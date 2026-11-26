/// Imports from a file already on disk: the SSI CSV, the sites JSON and the
/// Subsurface XML. Used by the Tools pickers and by files shared or opened
/// with PanDive (e.g. a document received on WhatsApp), whose kind is guessed
/// from the content because the name/MIME type may not say.
library;

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/ssi_csv_import.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/services/home_navigation.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/settings/screens/import_ssi_screen.dart';
import 'package:pandive/features/sites/logic/site_import.dart';
import 'package:pandive/features/sites/screens/import_sites_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

enum IncomingKind { ddb, subsurface, sitesJson, ssiCsv }

/// Kind of file from its first bytes: SQLite header = .ddb, XML = Subsurface,
/// JSON array/object = sites, anything else = CSV (SSI).
IncomingKind detectIncomingKind(List<int> head) {
  const sqlite = 'SQLite format 3';
  if (head.length >= sqlite.length &&
      String.fromCharCodes(head.take(sqlite.length)) == sqlite) {
    return IncomingKind.ddb;
  }
  var text = utf8.decode(head, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1); // BOM
  text = text.trimLeft();
  if (text.startsWith('<')) return IncomingKind.subsurface;
  if (text.startsWith('[') || text.startsWith('{')) {
    return IncomingKind.sitesJson;
  }
  return IncomingKind.ssiCsv;
}

Future<IncomingKind> detectFileKind(String path) async {
  final f = await File(path).open();
  try {
    return detectIncomingKind(await f.read(512));
  } finally {
    await f.close();
  }
}

/// Parses the SSI CSV (with a "reading" notice) and opens the review list.
Future<void> importSsiFile(
    BuildContext context, DivemateDb db, String path) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final plan = await withProgress(context, t.readingFile,
      () async => planSsiImport(db, await File(path).readAsString()));
  if (!context.mounted) return;
  if (plan.entries.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t.nothingToImport)));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportSsiScreen(db: db, entries: plan.entries)));
}

/// Plans the sites JSON import and opens its preview.
Future<void> importSitesFile(
    BuildContext context, DivemateDb db, String path) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  final plan = await withProgress(context, t.working,
      () async => planSiteImport(db, await File(path).readAsString()));
  if (plan.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t.nothingToImport)));
    return;
  }
  final n = await nav.push<int>(MaterialPageRoute(
      builder: (_) => ImportSitesScreen(db: db, entries: plan)));
  if (n != null && n > 0) {
    messenger.showSnackBar(SnackBar(content: Text(t.importResult(n))));
  }
}

/// Imports the dives of a Subsurface XML with a progress bar; how many.
Future<int> importSubsurfaceFile(
    BuildContext context, DivemateDb db, String path) async {
  final xml = await File(path).readAsString();
  if (!context.mounted) return 0;
  return importSsrfWithProgress(context, db, xml);
}

/// A file shared/opened with PanDive: routes it by content. A .ddb goes to
/// [onDdb] (the preview with its import options).
Future<void> openIncomingFile(BuildContext context, DivemateDb db,
    String path, void Function(String path) onDdb) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    switch (await detectFileKind(path)) {
      case IncomingKind.ddb:
        onDdb(path);
      case IncomingKind.ssiCsv:
        if (context.mounted) await importSsiFile(context, db, path);
      case IncomingKind.sitesJson:
        if (context.mounted) await importSitesFile(context, db, path);
      case IncomingKind.subsurface:
        if (!context.mounted) return;
        final n = await importSubsurfaceFile(context, db, path);
        bumpDataRevision();
        requestDivesList();
        messenger.showSnackBar(
            SnackBar(content: Text(t.importSubsurfaceResult(n))));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(t.unreadableFile('$e'))));
  }
}
