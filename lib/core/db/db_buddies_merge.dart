part of 'divemate_db.dart';

/// Buddy merge: unifies several buddies into one.
extension DivemateDbBuddiesMerge on DivemateDb {
  /// Merges buddies [fromIds] into [keepId]: reassigns the dives that
  /// reference them (in BuddyIDs, without duplicates), rebuilds the Buddy text and
  /// deletes the merged buddies. [keepId] is kept.
  void mergeBuddies(int keepId, Iterable<int> fromIds) {
    final from = fromIds.where((id) => id != keepId).toSet();
    if (from.isEmpty) return;
    final rows = _db.select(
        "SELECT ID, BuddyIDs FROM Logbook WHERE TRIM(IFNULL(BuddyIDs,'')) != ''");
    for (final r in rows) {
      final ids = (_str(r['BuddyIDs']) ?? '')
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
      if (!ids.any(from.contains)) continue;
      final remapped =
          ids.map((id) => from.contains(id) ? keepId : id).toSet().toList();
      updateDive(r['ID'] as int, {'BuddyIDs': remapped.join(',')});
    }
    for (final id in from) {
      deleteBuddy(id);
    }
    _refreshBuddyNames(keepId); // rebuilds Buddy (text) of the affected dives
  }
}
