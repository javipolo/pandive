/// Exports a .ddb with only the selected dives: full data (depths, duration,
/// temperatures, notes, buddies, computer, cylinders, tags, site with
/// coordinates) and, optionally, the profile. Works both for a buddy to
/// import them as their own ("Import dives") and for "Fill from a buddy's
/// logbook" (which only looks at date/time and site).
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/export/ddb_dive_copy.dart';
import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/dives/widgets/export_selection_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Asks for a name (and whether to include profiles), creates a temp .ddb
/// with [dives] and shares it. The file is named `name - PanDive.ddb`.
Future<void> exportSelectionDdb(
    BuildContext context, DivemateDb source, List<Dive> dives) async {
  final opts = await showExportSelectionDialog(context);
  if (opts == null || !context.mounted) return;
  final f = await withProgress(
      context,
      AppLocalizations.of(context).exporting,
      () => _buildSelection(source, dives, opts.name,
          withProfiles: opts.profiles));
  await shareOrSaveFile(f);
}

Future<File> _buildSelection(DivemateDb source, List<Dive> dives, String name,
    {required bool withProfiles}) async {
  final dir = await getTemporaryDirectory();
  final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  final base = safe.isEmpty ? 'PanDive' : '$safe - PanDive';
  final f = File('${dir.path}/$base.ddb');
  if (f.existsSync()) f.deleteSync();
  final out = DivemateDb.createEmpty(f.path);
  try {
    await writeSelectionDdb(source, out, dives, withProfiles: withProfiles);
  } finally {
    out.close();
  }
  return f;
}

/// Writes [dives] from [source] into [out]. In chunks within a transaction,
/// yielding the thread between chunks (don't freeze the UI). Testable (no IO).
Future<void> writeSelectionDdb(
    DivemateDb source, DivemateDb out, List<Dive> dives,
    {bool withProfiles = false}) async {
  for (var i = 0; i < dives.length; i += 50) {
    final part = dives.sublist(i, (i + 50).clamp(0, dives.length));
    out.inTransaction(() {
      for (final d in part) {
        copyDiveToDdb(source, out, d, withProfile: withProfiles);
      }
    });
    await Future<void>.delayed(Duration.zero);
  }
}
