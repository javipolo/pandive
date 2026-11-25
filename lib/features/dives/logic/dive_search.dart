/// Dive search match, accent- and case-insensitive.
/// Searches site, country, notes, buddies (text) and type; or by exact number.
library;

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';

bool diveMatches(Dive d, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  for (final s in [d.place, d.country, d.comments, d.buddy, d.diveType]) {
    if (s != null && foldContains(s, q)) return true;
  }
  return d.number?.toString() == q;
}

List<Dive> filterDives(List<Dive> dives, String query) =>
    query.trim().isEmpty
        ? dives
        : [for (final d in dives) if (diveMatches(d, query)) d];
