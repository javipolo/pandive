part of 'divemate_db.dart';

/// Compañeros de buceo (tabla Buddy). Guardamos el nombre en FirstName.
extension DivemateDbBuddies on DivemateDb {
  /// Filtro de inmersiones del owner que referencian a un buddy (por BuddyIDs).
  String _buddyDivesWhere() {
    final owner = ownerId;
    final diverFilter = owner != null ? 'AND L.DiverID = $owner' : '';
    return "(L.Status IS NULL OR L.Status != 2) $diverFilter AND "
        "(',' || IFNULL(L.BuddyIDs,'') || ',') LIKE ('%,' || B.ID || ',%')";
  }

  /// Lista de buddies, alfabética, con nº de inmersiones y fecha del último.
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

  /// Rellena `BuddyIDs` de las inmersiones del owner que tienen texto `Buddy`
  /// pero `BuddyIDs` vacío (dives antiguas de DiveMate, que solo guardaban el
  /// nombre). El texto puede ser CSV de varios nombres; crea los que falten.
  /// Devuelve cuántas inmersiones actualizó.
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

  /// Borra los buddies sin ninguna inmersión. Devuelve cuántos eliminó.
  int purgeUnusedBuddies() {
    final unused = [for (final b in listBuddies()) if (b.diveCount == 0) b.id];
    for (final id in unused) {
      deleteBuddy(id);
    }
    return unused.length;
  }

  /// Busca un buddy por nombre (case-insensitive) o lo crea. Devuelve su ID.
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

  /// Recompone el texto `Logbook.Buddy` de las inmersiones que referencian al
  /// buddy [id] (por BuddyIDs), para reflejar su nombre actual.
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

  /// Compañeros de una inmersión (según Logbook.BuddyIDs).
  List<Buddy> diveBuddies(int diveId) {
    final rows = _db.select('SELECT BuddyIDs FROM Logbook WHERE ID=?', [diveId]);
    if (rows.isEmpty) return [];
    final ids = (_str(rows.first['BuddyIDs']) ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return [];
    final all = listBuddies();
    return [for (final b in all) if (ids.contains(b.id)) b];
  }

  /// Añade [names] como compañeros de la inmersión (crea los que falten) sin
  /// quitar los existentes. Actualiza BuddyIDs y el texto Buddy.
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

