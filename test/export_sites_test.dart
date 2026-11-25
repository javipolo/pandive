import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/sites/logic/export_sites.dart';
import 'package:pandive/features/sites/widgets/sites_grouped_list.dart';

void main() {
  const sites = [
    DiveSite(id: 1, name: 'Cala Ferrera', country: 'España', region: 'Cabrera'),
    DiveSite(id: 2, name: 'Blue Hole', country: 'Malta', lat: 36.0, lon: 14.2),
  ];

  test('filterSites ignores case and accents, empty query = all', () {
    expect(filterSites(sites, ''), sites);
    expect(filterSites(sites, 'espana').map((s) => s.id), [1]);
    expect(filterSites(sites, 'BLUE').map((s) => s.id), [2]);
  });

  // writeSitesJson encodes in another isolate: sites must be sendable.
  test('sites JSON can be encoded in another isolate', () async {
    final json = await Isolate.run(() => sitesToJson(sites));
    final list = jsonDecode(json) as List;
    expect(list.length, 2);
    expect(list[1]['coordinates'], {'latitude': 36.0, 'longitude': 14.2});
    expect(list[0]['coordinates'], isNull);
  });
}
