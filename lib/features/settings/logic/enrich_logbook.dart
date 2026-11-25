/// Enrich dives by cross-checking with another .ddb (a buddy's): pair by
/// date/time, copy site + notes + buddies and add a chosen buddy.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Copyable data of a source .ddb dive that pairs with one of ours.
class DiveMatch {
  final String? place;
  final String? country;
  final double? lat;
  final double? lon;
  const DiveMatch({this.place, this.country, this.lat, this.lon});
}

/// Pairs the dives of [her] with [source] (yields to the event loop so
/// the UI stays alive). Returns our dives with a match and their data.
Future<({List<Dive> dives, Map<int, DiveMatch> matches})> computeMatches(
    DivemateDb her, DivemateDb source,
    {Duration tol = const Duration(hours: 1)}) async {
  // Indexes the source by day once (avoids re-querying for each dive).
  final byDay = <String, List<Dive>>{};
  for (final d in source.listDives()) {
    final dt = d.date;
    if (dt != null) (byDay['${dt.year}-${dt.month}-${dt.day}'] ??= []).add(d);
  }
  final matches = <int, DiveMatch>{};
  final dives = <Dive>[];
  final all = her.listDives();
  for (var i = 0; i < all.length; i++) {
    final dt = all[i].date;
    if (dt != null) {
      Dive? best;
      Duration? bd;
      for (final s in byDay['${dt.year}-${dt.month}-${dt.day}'] ?? const []) {
        final diff = s.date!.difference(dt).abs();
        if (diff <= tol && (bd == null || diff < bd)) {
          best = s;
          bd = diff;
        }
      }
      if (best != null) {
        matches[all[i].id] = _matchFrom(source, best);
        dives.add(all[i]);
      }
    }
    if (i % 20 == 19) await Future<void>.delayed(Duration.zero);
  }
  return (dives: dives, matches: matches);
}

/// Builds the copyable data from a source .ddb dive.
DiveMatch _matchFrom(DivemateDb source, Dive best) {
  final site = best.placeId != null ? source.getSite(best.placeId!) : null;
  return DiveMatch(
    place: site?.name ?? best.place,
    country: site?.country ?? best.country,
    lat: site?.lat,
    lon: site?.lon,
  );
}

/// Finds in [source] the dive on the same day closest in time to [when]
/// (within [tol]); returns its copyable data, or null if none.
DiveMatch? findSourceMatch(DivemateDb source, DateTime when,
    {Duration tol = const Duration(hours: 1)}) {
  Dive? best;
  Duration? bestDiff;
  for (final d in source.listDives()) {
    final dt = d.date;
    if (dt == null) continue;
    if (dt.year != when.year || dt.month != when.month || dt.day != when.day) {
      continue;
    }
    final diff = dt.difference(when).abs();
    if (diff <= tol && (bestDiff == null || diff < bestDiff)) {
      best = d;
      bestDiff = diff;
    }
  }
  return best == null ? null : _matchFrom(source, best);
}

/// Applies the [matches] to the [selected] dives of logbook [db]: copies ONLY the
/// dive site and adds the chosen [buddy]. Doesn't touch cylinders, notes or anything
/// else of the dive. Returns the number of dives updated.
int applyEnrich(DivemateDb db, Map<int, DiveMatch> matches, Set<int> selected,
    String? buddy) {
  var n = 0;
  for (final id in selected) {
    final m = matches[id];
    if (m == null) continue;
    if (m.place != null && m.place!.trim().isNotEmpty) {
      db.updateDive(id, {
        'PlaceID': db.findOrCreateSite(m.place!,
            country: m.country, lat: m.lat, lon: m.lon),
        'Place': m.place,
        'Country': m.country,
      });
    }
    if (buddy != null && buddy.trim().isNotEmpty) {
      db.addDiveBuddies(id, [buddy]);
    }
    n++;
  }
  return n;
}
