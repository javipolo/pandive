/// Exporta sitios de buceo a un JSON (mismo formato que el import) y lo comparte.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/models/models.dart';

String sitesToJson(List<DiveSite> sites) {
  final list = [
    for (final s in sites)
      {
        'name': s.name,
        'region': s.region,
        'country': s.country,
        'coordinates': (s.lat != null && s.lon != null)
            ? {'latitude': s.lat, 'longitude': s.lon}
            : null,
      }
  ];
  return const JsonEncoder.withIndent('  ').convert(list);
}

Future<void> exportSitesJson(List<DiveSite> sites) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/dive-sites-PanDive.json');
  await f.writeAsString(sitesToJson(sites));
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
}
