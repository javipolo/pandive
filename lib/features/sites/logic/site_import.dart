/// Site import plan from a JSON: computes which sites to add and
/// which to modify (filling/overwriting with the JSON's non-null fields; the
/// null ones touch nothing). Match by name (accent-insensitive), preferring country if given.
library;

import 'dart:convert';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';

enum SiteImportAction { add, modify }

class SiteImport {
  final String name;
  final SiteImportAction action;
  final int? existingId; // site to modify (null if add)
  final Map<String, Object?> fields; // Place columns to write
  const SiteImport(
      {required this.name,
      required this.action,
      this.existingId,
      required this.fields});

  /// Labels of the fields that change (for display), without "Place".
  List<String> get changedKeys =>
      fields.keys.where((k) => k != 'Place').toList();
}

String _norm(String? s) => foldAccents((s ?? '').trim().toLowerCase());
bool _sameNum(double? a, double? b) =>
    a != null && b != null && (a - b).abs() < 1e-6;

/// Computes the plan without touching the DB. Skips sites that don't change.
List<SiteImport> planSiteImport(DivemateDb db, String jsonStr) {
  final data = jsonDecode(jsonStr);
  if (data is! List) return const [];
  final sites = db.listSites();
  final out = <SiteImport>[];

  for (final e in data) {
    if (e is! Map) continue;
    final name = (e['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final region = (e['region'] as String?)?.trim();
    final country = (e['country'] as String?)?.trim();
    final coords = e['coordinates'];
    final lat = coords is Map ? (coords['latitude'] as num?)?.toDouble() : null;
    final lon = coords is Map ? (coords['longitude'] as num?)?.toDouble() : null;

    final matches = sites.where((s) => _norm(s.name) == _norm(name)).toList();
    DiveSite? target;
    if (matches.isNotEmpty) {
      target = country != null
          ? matches.firstWhere((s) => _norm(s.country) == _norm(country),
              orElse: () => matches.first)
          : matches.first;
    }

    if (target == null) {
      final fields = <String, Object?>{'Place': name};
      if (country != null && country.isNotEmpty) fields['Country'] = country;
      if (region != null && region.isNotEmpty) fields['Region'] = region;
      if (lat != null) fields['Lat'] = lat.toStringAsFixed(6);
      if (lon != null) fields['Lon'] = lon.toStringAsFixed(6);
      out.add(SiteImport(
          name: name, action: SiteImportAction.add, fields: fields));
    } else {
      final fields = <String, Object?>{};
      if (country != null &&
          country.isNotEmpty &&
          _norm(country) != _norm(target.country)) {
        fields['Country'] = country;
      }
      if (region != null &&
          region.isNotEmpty &&
          _norm(region) != _norm(target.region)) {
        fields['Region'] = region;
      }
      if (lat != null && !_sameNum(lat, target.lat)) {
        fields['Lat'] = lat.toStringAsFixed(6);
      }
      if (lon != null && !_sameNum(lon, target.lon)) {
        fields['Lon'] = lon.toStringAsFixed(6);
      }
      if (fields.isNotEmpty) {
        out.add(SiteImport(
            name: name,
            action: SiteImportAction.modify,
            existingId: target.id,
            fields: fields));
      }
    }
  }
  return out;
}

/// Applies the [selected] ones to the DB. Returns how many were added/modified.
int applySiteImport(DivemateDb db, Iterable<SiteImport> selected) {
  var n = 0;
  for (final si in selected) {
    if (si.action == SiteImportAction.add) {
      db.createSite(si.fields);
    } else if (si.existingId != null) {
      db.updateSite(si.existingId!, si.fields);
    }
    n++;
  }
  return n;
}
