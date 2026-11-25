part of 'divemate_db.dart';

/// Dive buddies (Buddy table). We store the name in FirstName.
extension DivemateDbBuddies on DivemateDb {
  /// Filter for the owner's dives that reference a buddy (via BuddyIDs).
  String _buddyDivesWhere() {
    final owner = ownerId;
    final diverFilter = owner != null ? 'AND L.DiverID = $owner' : '';
    return "(L.Status IS NULL OR L.Status != 2) $diverFilter AND "
        "(',' || IFNULL(L.BuddyIDs,'') || ',') LIKE ('%,' || B.ID || ',%')";
  }

  /// Buddy list, alphabetical, with dive count and date of the last one.
  List<Buddy> listBuddies() {
    final where = _buddyDivesWhere();
    final rows = _db.select(
      'SELECT B.ID, B.FirstName, B.LastName, '
      '(SELECT COUNT(*) FROM Logbook L WHERE $where) AS dives, '
      '(SELECT MAX(L.Divedate) FROM Logbook L WHERE $where) AS lastdive '
      'FROM Buddy B ORDER BY B.FirstName COLLATE NOCASE, B.LastName COLLATE NOCASE',
    );
    return rows.map((r) {
      final name = [_str(r['FirstName']), _str(r['LastName'])]
          .whereType<String>()
          .join(' ');
      return Buddy(
        id: r['ID'] as int,
        name: name.isEmpty ? '—' : name,
        diveCount: (r['dives'] as int?) ?? 0,
        lastDive: DateTime.tryParse(_str(r['lastdive']) ?? ''),
      );
    }).toList()
      ..sort((a, b) => compareFold(a.name, b.name));
  }

  /// Fills `BuddyIDs` of the owner's dives that have `Buddy` text
  /// but empty `BuddyIDs` (old DiveMate dives, which only stored the
  /// name). The text may be a CSV of several names; creates the missing ones.
  /// Returns how many dives were updated.
  int backfillBuddyIds() {
    final owner = ownerId;
    final f = owner != null ? 'AND DiverID = $owner' : '';
    final rows = _db.select(
      "SELECT ID, Buddy FROM Logbook WHERE (Status IS NULL OR Status != 2) $f "
      "AND TRIM(IFNULL(Buddy,'')) != '' AND TRIM(IFNULL(BuddyIDs,'')) = ''");
    var n = 0;
    for (final r in rows) {
      final ids = <int>{
        for (final name in (_str(r['Buddy']) ?? '').split(','))
          if (name.trim().isNotEmpty) findOrCreateBuddy(name.trim())
      };
      if (ids.isEmpty) continue;
      updateDive(r['ID'] as int, {'BuddyIDs': ids.join(',')});
      n++;
    }
    return n;
  }

  /// Deletes buddies without any dive. Returns how many were removed.
  int purgeUnusedBuddies() {
    final unused = [for (final b in listBuddies()) if (b.diveCount == 0) b.id];
    for (final id in unused) {
      deleteBuddy(id);
    }
    return unused.length;
  }

  /// Finds a buddy by name (case-insensitive) or creates it. Returns its ID.
  int findOrCreateBuddy(String name) {
    final n = name.trim();
    final found = _db.select(
      'SELECT ID FROM Buddy WHERE '
      "TRIM(IFNULL(FirstName,'') || ' ' || IFNULL(LastName,'')) = ? COLLATE NOCASE",
      [n],
    );
    if (found.isNotEmpty) return found.first['ID'] as int;
    _db.execute(
      'INSERT INTO Buddy (FirstName, UUID, Updated) VALUES (?,?,?)',
      [n, _uuid(), _nowStamp()],
    );
    return _db.lastInsertRowId;
  }

  void renameBuddy(int id, String name) {
    _db.execute(
      'UPDATE Buddy SET FirstName=?, LastName=NULL, Updated=? WHERE ID=?',
      [name.trim(), _nowStamp(), id],
    );
    _refreshBuddyNames(id);
  }

  /// Rebuilds the `Logbook.Buddy` text of the dives that reference
  /// buddy [id] (via BuddyIDs), to reflect its current name.
  void _refreshBuddyNames(int id) {
    final rows = _db.select(
      "SELECT ID, BuddyIDs FROM Logbook WHERE "
      "(',' || IFNULL(BuddyIDs,'') || ',') LIKE ('%,' || ? || ',%')",
      [id],
    );
    if (rows.isEmpty) return;
    final names = {for (final b in listBuddies()) b.id: b.name};
    final now = _nowStamp();
    for (final r in rows) {
      final ids = (_str(r['BuddyIDs']) ?? '')
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>();
      final text = ids
          .map((i) => names[i])
          .whereType<String>()
          .where((n) => n != '—')
          .join(', ');
      _db.execute('UPDATE Logbook SET Buddy=?, Updated=? WHERE ID=?',
          [text.isEmpty ? null : text, now, r['ID']]);
    }
  }

  void deleteBuddy(int id) => _db.execute('DELETE FROM Buddy WHERE ID=?', [id]);

  /// Buddies of a dive (per Logbook.BuddyIDs).
  List<Buddy> diveBuddies(int diveId) {
    final rows = _db.select('SELECT BuddyIDs FROM Logbook WHERE ID=?', [diveId]);
    if (rows.isEmpty) return [];
    final ids = (_str(rows.first['BuddyIDs']) ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return [];
    // Only those buddies (no counts): listBuddies() walks the whole logbook
    // for each buddy (~150 ms) and this is called per dive when
    // exporting/importing.
    final found = _db.select(
      'SELECT ID, FirstName, LastName FROM Buddy '
      'WHERE ID IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
    String nameOf(Row r) {
      final n = [_str(r['FirstName']), _str(r['LastName'])]
          .whereType<String>()
          .join(' ');
      return n.isEmpty ? '—' : n;
    }
    return [for (final r in found) Buddy(id: r['ID'] as int, name: nameOf(r))]
      ..sort((a, b) => compareFold(a.name, b.name));
  }

  /// Adds [names] as buddies of the dive (creating the missing ones) without
  /// removing the existing ones. Updates BuddyIDs and the Buddy text.
  void addDiveBuddies(int diveId, List<String> names) {
    final map = {for (final b in diveBuddies(diveId)) b.id: b.name};
    for (final n in names) {
      final name = n.trim();
      if (name.isEmpty) continue;
      map[findOrCreateBuddy(name)] = name;
    }
    if (map.isEmpty) return;
    updateDive(diveId, {
      'BuddyIDs': map.keys.join(','),
      'Buddy': map.values.join(', '),
    });
  }
}

