/// Acciones de exportación/importación: DiveMate (.ddb nativo), Subsurface
/// (.ssrf XML) y CSV de SSI.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/export/subsurface_export.dart';
import 'package:pandive/core/import/ssi_csv_import.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/import_progress.dart';

/// Copia el .ddb activo a un temporal con nombre limpio y lo comparte (igual
/// que la exportación a Subsurface; snapshot, no comparte el fichero en uso).
Future<void> exportDdb(Settings settings) async {
  final path = settings.dbPath;
  if (path == null) return;
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/pandive.ddb');
  await File(path).copy(f.path);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
}

/// Genera el XML Subsurface y lo comparte.
Future<void> exportSubsurface(DivemateDb db) async {
  final xml = buildSubsurfaceXml(db);
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/pandive.ssrf');
  await f.writeAsString(xml);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
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

/// Elige el CSV exportado de MySSI e importa sus inmersiones. Devuelve el
/// resultado, o null si se canceló.
Future<SsiImportResult?> importSsi(DivemateDb db) async {
  final res = await FilePicker.platform.pickFiles(withData: false);
  final path = res?.files.single.path;
  if (path == null) return null;
  return importSsiCsv(db, await File(path).readAsString());
}
