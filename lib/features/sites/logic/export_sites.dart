/// Exports dive sites to JSON (same format as the import).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

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

/// Writes the sites to a temp JSON (for shareOrSaveFile). The JSON is
/// generated in another isolate: with thousands of sites it doesn't freeze the UI.
Future<File> writeSitesJson(List<DiveSite> sites) async {
  final json = await _encodeOffThread(sites);
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/dive-sites-PanDive.json');
  return f.writeAsString(json);
}

// Top-level: the closure only captures the list (sendable between isolates).
Future<String> _encodeOffThread(List<DiveSite> sites) =>
    Isolate.run(() => sitesToJson(sites));
