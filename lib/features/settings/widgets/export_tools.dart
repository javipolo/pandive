/// Acciones de exportación: DiveMate (.ddb nativo) y Subsurface (.ssrf XML).
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/export/subsurface_export.dart';
import 'package:pandive/core/settings/settings.dart';

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
