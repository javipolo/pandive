/// Copies dives from another .ddb into our own logbook (e.g. handing the trip to a
/// buddy without a computer). Reuses `importExternalDive` (dedupe by
/// date/time, copies profile, site with coords, buddies, tags and cylinders).
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// A source .ddb dive and whether it already exists in the logbook (same date/time).
class DdbImportEntry {
  final Dive dive;
  final bool duplicate;
  const DdbImportEntry(this.dive, {required this.duplicate});
}

/// Import summary: added, ignored for matching the time of an
/// existing one, not selected, and new sites/buddies created.
class DdbImportResult {
  final int imported;
  final int duplicates;
  final int notSelected;
  final int newSites;
  final int newBuddies;
  const DdbImportResult({
    required this.imported,
    required this.duplicates,
    required this.notSelected,
    required this.newSites,
    required this.newBuddies,
  });
}

/// Dated dives of [source], marking those already in [target].
List<DdbImportEntry> planDdbImport(DivemateDb target, DivemateDb source) => [
      for (final d in source.listDives())
        if (d.date != null)
          DdbImportEntry(d, duplicate: target.hasDiveAt(d.date!)),
    ];

/// Imports the dives of [source] into [target] (only those in [only] if given).
/// Those matching the date/time of an existing one are ignored. Writes in
/// chunks (one transaction each) and yields the thread between chunks so as not
/// to freeze the UI (on Android, >5 s in a row = "app not responding").
Future<DdbImportResult> importDivesFromDb(DivemateDb target, DivemateDb source,
    {Set<int>? only, void Function(int done, int total)? onProgress}) async {
  final all = planDdbImport(target, source);
  final sitesBefore = target.listSites().length;
  final buddiesBefore = target.listBuddies().length;
  final chosen = [
    for (final e in all)
      if (only == null || only.contains(e.dive.id)) e
  ];
  final notSel = all.length - chosen.length;
  var imported = 0;
  const chunk = 20;
  for (var i = 0; i < chosen.length; i += chunk) {
    final part = chosen.sublist(i, (i + chunk).clamp(0, chosen.length));
    imported += target.inTransaction(() => part
        .where((e) => !e.duplicate && _importOne(target, source, e.dive))
        .length);
    onProgress?.call(i + part.length, chosen.length);
    await Future<void>.delayed(Duration.zero);
  }
  final dups = chosen.length - imported;
  if (imported > 0) target.autoRenumber();
  return DdbImportResult(
    imported: imported,
    duplicates: dups,
    notSelected: notSel,
    newSites: target.listSites().length - sitesBefore,
    newBuddies: target.listBuddies().length - buddiesBefore,
  );
}

bool _importOne(DivemateDb target, DivemateDb source, Dive d) {
  final site = d.placeId != null ? source.getSite(d.placeId!) : null;
  return target.importExternalDive(
    dateTime: d.date!,
    placeName: site?.name ?? d.place,
    country: site?.country ?? d.country,
    lat: site?.lat,
    lon: site?.lon,
    comments: d.comments,
    buddies: [for (final b in source.diveBuddies(d.id)) b.name],
    tagNames: [for (final tg in source.tagsForDive(d.id)) tg.name],
    maxDepth: d.maxDepth,
    avgDepth: d.avgDepth,
    durationMin: d.durationMin,
    waterTemp: d.waterTemp,
    airTemp: d.airTemp,
    computer: d.computer,
    o2: d.o2,
    samples: _samples(source, d.id),
    cylinders: source.cylinders(d.id),
  );
}

List<DiveSample> _samples(DivemateDb source, int diveId) {
  final p = source.diveProfile(diveId);
  if (p == null) return const [];
  double? at(List<double?> xs, int i) => i < xs.length ? xs[i] : null;
  return [
    for (var i = 0; i < p.depths.length; i++)
      DiveSample(
        (p.timesMinutes[i] * 60000).round(),
        p.depths[i],
        at(p.temps, i),
      ),
  ];
}
