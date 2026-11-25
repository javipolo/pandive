/// Buddy list order: alphabetical (default), by dive count
/// (desc) or by most recent dive (desc). The list arrives alphabetical from the DB.
library;

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';

enum BuddySort { name, dives, recent }

void sortBuddiesBy(List<Buddy> list, BuddySort by) {
  switch (by) {
    case BuddySort.name:
      list.sort((a, b) => compareFold(a.name, b.name));
    case BuddySort.dives:
      list.sort((a, b) => a.diveCount == b.diveCount
          ? compareFold(a.name, b.name)
          : b.diveCount.compareTo(a.diveCount));
    case BuddySort.recent:
      list.sort((a, b) {
        final x = a.lastDive, y = b.lastDive;
        if (x == null && y == null) return compareFold(a.name, b.name);
        if (x == null) return 1; // no dives last
        if (y == null) return -1;
        final c = y.compareTo(x); // most recent first
        return c != 0 ? c : compareFold(a.name, b.name);
      });
  }
}
