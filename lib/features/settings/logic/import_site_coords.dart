/// Importa coordenadas (lat/lon) a los sitios de buceo desde un JSON y las
/// rellena en los que coincidan por nombre (+ region/country si vienen en la
/// entrada). Ignora entradas sin coordenadas. Devuelve nº de sitios actualizados.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/text/collate.dart';

/// Elige un JSON e importa coordenadas a los sitios. Devuelve nº de sitios
/// actualizados, o null si se canceló.
Future<int?> pickAndImportSiteCoords(DivemateDb db) async {
  final res = await FilePicker.platform.pickFiles(withData: false);
  final path = res?.files.single.path;
  if (path == null) return null;
  return importSiteCoordsFromJson(db, await File(path).readAsString());
}

String _norm(String? s) => foldAccents((s ?? '').trim().toLowerCase());

int importSiteCoordsFromJson(DivemateDb db, String jsonStr) {
  final data = jsonDecode(jsonStr);
  if (data is! List) return 0;
  final sites = db.listSites();
  final updated = <int>{};

  for (final e in data) {
    if (e is! Map) continue;
    final coords = e['coordinates'];
    if (coords is! Map) continue;
    final lat = (coords['latitude'] as num?)?.toDouble();
    final lon = (coords['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) continue;

    final name = e['name'] as String?;
    if (name == null || name.trim().isEmpty) continue;
    final region = e['region'] as String?; // null => no filtrar por región
    final country = e['country'] as String?;

    for (final s in sites) {
      if (_norm(s.name) != _norm(name)) continue;
      if (region != null && _norm(s.region) != _norm(region)) continue;
      if (country != null && _norm(s.country) != _norm(country)) continue;
      db.updateSite(s.id, {
        'Lat': lat.toStringAsFixed(6),
        'Lon': lon.toStringAsFixed(6),
      });
      updated.add(s.id);
    }
  }
  return updated.length;
}
