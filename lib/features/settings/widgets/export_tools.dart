/// Acciones de exportación: DiveMate (.ddb nativo) y Subsurface (.ssrf XML).
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/export/subsurface_export.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/import_progress.dart';

/// Comparte el .ddb activo (formato nativo DiveMate).
void exportDdb(Settings settings) {
  final path = settings.dbPath;
  if (path != null) {
    SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }
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
