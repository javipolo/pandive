part of 'divemate_db.dart';

/// Batch edits over a selection of dives: dive type and own tags. They don't
/// open a transaction themselves: the caller wraps them in [inTransaction]
/// (together with any related write, e.g. the type's cylinders).
extension DivemateDbBulk on DivemateDb {
  /// Sets (or clears, with null) `Logbook.Divetype` on [diveIds]. Returns how
  /// many dives actually changed.
  int setDivesType(List<int> diveIds, String? typeName) {
    final name = typeName?.trim();
    final value = (name == null || name.isEmpty) ? null : name;
    final now = _nowStamp();
    var n = 0;
    for (final id in diveIds) {
      _db.execute(
        'UPDATE Logbook SET Divetype = ?, Updated = ? WHERE ID = ? '
        'AND Divetype IS NOT ?',
        [value, now, id, value],
      );
      n += _db.updatedRows;
    }
    return n;
  }

  /// Gives [tagId] as an own tag to the [diveIds] that don't have it yet.
  /// Returns how many dives got it.
  int addTagToDives(int tagId, List<int> diveIds) {
    var n = 0;
    for (final id in diveIds) {
      _db.execute(
        'INSERT OR IGNORE INTO PandiveDiveTag (DiveId, TagId) VALUES (?,?)',
        [id, tagId],
      );
      n += _db.updatedRows;
    }
    return n;
  }

  /// Unlinks [tagId] from the [diveIds] (own link only: a tag inherited from
  /// the site or dive type stays). Returns how many dives lost it.
  int removeTagFromDives(int tagId, List<int> diveIds) {
    var n = 0;
    for (final id in diveIds) {
      _db.execute(
          'DELETE FROM PandiveDiveTag WHERE DiveId = ? AND TagId = ?',
          [id, tagId]);
      n += _db.updatedRows;
    }
    return n;
  }

  /// Own tags present in [diveIds], each with how many of those dives carry
  /// it, sorted by name. For the "remove tag" picker.
  List<(Tag, int)> ownTagCounts(List<int> diveIds) {
    if (diveIds.isEmpty) return const [];
    final marks = List.filled(diveIds.length, '?').join(',');
    final rows = _db.select(
      'SELECT T.Id, T.Name, COUNT(*) AS N FROM PandiveTag T '
      'JOIN PandiveDiveTag D ON D.TagId = T.Id '
      'WHERE D.DiveId IN ($marks) GROUP BY T.Id',
      diveIds,
    );
    return [
      for (final r in rows)
        (Tag(id: r['Id'] as int, name: _str(r['Name']) ?? ''), r['N'] as int),
    ]..sort((a, b) => compareFold(a.$1.name, b.$1.name));
  }
}
