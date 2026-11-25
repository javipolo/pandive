/// Exports a minimal .ddb with only the selected dives (date/time + site).
/// Meant for another diver to use "Fill from a buddy's logbook".
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/core/widgets/text_prompt_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Asks for a name, creates a temp .ddb with [dives] (date/time and place only)
/// and shares it. The file is named `name - PanDive.ddb`.
Future<void> exportSelectionDdb(
    BuildContext context, DivemateDb source, List<Dive> dives) async {
  final name =
      await showTextPrompt(context, title: AppLocalizations.of(context).exportName);
  if (name == null) return;
  if (!context.mounted) return;
  final f = await withProgress(context, AppLocalizations.of(context).exporting,
      () => _writeSelection(source, dives, name));
  await shareOrSaveFile(f);
}

// Writes [dives] to a temp .ddb "<name> - PanDive.ddb". In chunks
// within a transaction, yielding the thread between chunks (don't freeze the UI).
Future<File> _writeSelection(
    DivemateDb source, List<Dive> dives, String name) async {
  final dir = await getTemporaryDirectory();
  final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  final base = safe.isEmpty ? 'PanDive' : '$safe - PanDive';
  final f = File('${dir.path}/$base.ddb');
  if (f.existsSync()) f.deleteSync();
  final out = DivemateDb.createEmpty(f.path);
  try {
    for (var i = 0; i < dives.length; i += 50) {
      final part = dives.sublist(i, (i + 50).clamp(0, dives.length));
      out.inTransaction(() {
        for (final d in part) {
          _copyDive(source, out, d);
        }
      });
      await Future<void>.delayed(Duration.zero);
    }
  } finally {
    out.close();
  }
  return f;
}

void _copyDive(DivemateDb source, DivemateDb out, Dive d) {
  final dt = d.date;
  if (dt == null) return;
  final site = d.placeId != null ? source.getSite(d.placeId!) : null;
  final name = site?.name ?? d.place;
  int? placeId;
  if (name != null && name.trim().isNotEmpty) {
    placeId = out.findOrCreateSite(name,
        country: site?.country ?? d.country, lat: site?.lat, lon: site?.lon);
  }
  out.createDive(
    dateTime: dt,
    number: d.number,
    place: name,
    country: site?.country ?? d.country,
    placeId: placeId,
  );
}
