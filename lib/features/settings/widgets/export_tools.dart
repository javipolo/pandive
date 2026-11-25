/// Acciones de exportación/importación: DiveMate (.ddb nativo), Subsurface
/// (.ssrf XML) y CSV de SSI.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/export/subsurface_export.dart';
import 'package:pandive/core/import/ssi_csv_import.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/settings/screens/import_ssi_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Copia el .ddb activo a un temporal con nombre limpio y lo comparte (igual
/// que la exportación a Subsurface; snapshot, no comparte el fichero en uso).
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

/// Genera el XML Subsurface (con barra de progreso) y lo comparte.
Future<void> exportSubsurface(BuildContext context, DivemateDb db) async {
  final t = AppLocalizations.of(context);
  final f = await withProgressBar(context, title: t.exporting, (p) async {
    final xml = await buildSubsurfaceXml(db, onProgress: p);
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/pandive.ssrf').writeAsString(xml);
  });
  await shareOrSaveFile(f);
}

/// Elige un .ssrf e importa sus inmersiones, mostrando un diálogo de progreso.
/// Devuelve cuántas añadió, o null si se canceló.
Future<int?> importSubsurface(BuildContext context, DivemateDb db) async {
  final res = await FilePicker.platform.pickFiles(withData: false);
  final path = res?.files.single.path;
  if (path == null) return null;
  final xml = await File(path).readAsString();
  if (!context.mounted) return null;
  return importSsrfWithProgress(context, db, xml);
}

/// Elige el CSV exportado de MySSI, lo analiza (con aviso de "leyendo") y
/// abre la lista para revisar y desmarcar antes de importar.
Future<void> importSsi(BuildContext context, DivemateDb db) async {
  final res = await FilePicker.platform.pickFiles(withData: false);
  final path = res?.files.single.path;
  if (path == null || !context.mounted) return;
  final t = AppLocalizations.of(context);
  final plan = await withProgress(context, t.readingFile,
      () async => planSsiImport(db, await File(path).readAsString()));
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportSsiScreen(db: db, entries: plan.entries)));
}
