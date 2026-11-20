part of 'divemate_db.dart';

/// Fusión de compañeros: unifica varios buddies en uno.
extension DivemateDbBuddiesMerge on DivemateDb {
  /// Fusiona los buddies [fromIds] en [keepId]: reasigna las inmersiones que
  /// los referencian (en BuddyIDs, sin duplicar), recompone el texto Buddy y
  /// borra los buddies fusionados. [keepId] se preserva.
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
    _refreshBuddyNames(keepId); // recompone Buddy (texto) de las afectadas
  }
}
