part of 'divemate_db.dart';

/// Viajes de buceo: agrupan inmersiones (columna `PandiveTripId`) y guardan los
/// compañeros del viaje (`PandiveTripBuddy`). Tablas/columna propias de Pandive.
extension DivemateDbTrips on DivemateDb {
  bool get _hasTrips => _db
      .select("SELECT 1 FROM pragma_table_info('Logbook') "
          "WHERE name='PandiveTripId'")
      .isNotEmpty;

  String get _ownerDiveFilter {
    final owner = ownerId;
    return owner != null ? 'AND DiverID = $owner' : '';
  }

  List<Trip> listTrips() {
    if (!_hasTrips) return const [];
    final f = _ownerDiveFilter;
    final rows = _db.select(
      'SELECT T.Id, T.Name, '
      '  (SELECT COUNT(*) FROM Logbook L WHERE L.PandiveTripId = T.Id '
      "   AND (L.Status IS NULL OR L.Status != 2) ${f.replaceAll('DiverID', 'L.DiverID')}) dives, "
      '  (SELECT COUNT(*) FROM PandiveTripBuddy B WHERE B.TripId = T.Id) buds, '
      '  (SELECT MIN(Divedate) FROM Logbook L WHERE L.PandiveTripId = T.Id) first, '
      '  (SELECT MAX(Divedate) FROM Logbook L WHERE L.PandiveTripId = T.Id) last '
      'FROM PandiveTrip T ORDER BY last DESC, T.Name COLLATE NOCASE',
    );
    return [
      for (final r in rows)
        Trip(
          id: r['Id'] as int,
          name: _str(r['Name']) ?? '—',
          diveCount: (r['dives'] as int?) ?? 0,
          buddyCount: (r['buds'] as int?) ?? 0,
          firstDate: _parseDate(_str(r['first']), null),
          lastDate: _parseDate(_str(r['last']), null),
        ),
    ];
  }

  int createTrip(String name) {
    _db.execute('INSERT INTO PandiveTrip (Name, Updated) VALUES (?, ?)',
        [name.trim(), _nowStamp()]);
    return _db.lastInsertRowId;
  }

  void renameTrip(int id, String name) => _db.execute(
      'UPDATE PandiveTrip SET Name = ?, Updated = ? WHERE Id = ?',
      [name.trim(), _nowStamp(), id]);

  void deleteTrip(int id) {
    _db.execute('UPDATE Logbook SET PandiveTripId = NULL, Updated = ? '
        'WHERE PandiveTripId = ?', [_nowStamp(), id]);
    _db.execute('DELETE FROM PandiveTripBuddy WHERE TripId = ?', [id]);
    _db.execute('DELETE FROM PandiveTrip WHERE Id = ?', [id]);
  }

  void assignDivesToTrip(int? tripId, Iterable<int> diveIds) {
    final ids = diveIds.toList();
    if (ids.isEmpty) return;
    _db.execute(
        'UPDATE Logbook SET PandiveTripId = ?, Updated = ? '
        'WHERE ID IN (${ids.join(',')})',
        [tripId, _nowStamp()]);
  }

  List<Dive> listDivesByTrip(int tripId) {
    final rows = _db.select(
      'SELECT ${DivemateDbQueries._diveColumns} FROM Logbook '
      'WHERE (Status IS NULL OR Status != 2) $_ownerDiveFilter '
      'AND PandiveTripId = ? ORDER BY Divedate DESC, Entrytime DESC',
      [tripId],
    );
    return rows.map(_diveFromRow).toList();
  }

  List<Buddy> tripBuddies(int tripId) {
    final rows = _db.select(
      'SELECT B.ID, B.FirstName, B.LastName FROM Buddy B '
      'JOIN PandiveTripBuddy P ON P.BuddyId = B.ID WHERE P.TripId = ? '
      'ORDER BY B.FirstName COLLATE NOCASE, B.LastName COLLATE NOCASE',
      [tripId],
    );
    return [
      for (final r in rows)
        Buddy(
          id: r['ID'] as int,
          name: [_str(r['FirstName']), _str(r['LastName'])]
              .whereType<String>()
              .join(' ')
              .trim(),
        ),
    ];
  }

  void setTripBuddies(int tripId, Iterable<int> buddyIds) {
    _db.execute('DELETE FROM PandiveTripBuddy WHERE TripId = ?', [tripId]);
    for (final b in buddyIds.toSet()) {
      _db.execute(
          'INSERT INTO PandiveTripBuddy (TripId, BuddyId) VALUES (?, ?)',
          [tripId, b]);
    }
  }
}
