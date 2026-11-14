part of 'divemate_db.dart';

/// Botellas por inmersión, presets "mis botellas", y listados filtrados.
extension DivemateDbTanks on DivemateDb {
  /// Reemplaza las botellas de una inmersión por [tanks].
  void setDiveTanks(int logId, List<Cylinder> tanks) {
    _db.execute('DELETE FROM Tank WHERE LogID = ?', [logId]);
    final now = _nowStamp();
    for (var i = 0; i < tanks.length; i++) {
      final t = tanks[i];
      _db.execute(
        'INSERT INTO Tank (LogID, TankID, SortOrd, Tanksize, Tanktype, PresS, '
        'PresE, O2, He, Name, UUID, Updated) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          logId, i, i, t.size, _materialToInt(t.material), t.pressureStart,
          t.pressureEnd, t.o2, t.he, t.name, _uuid(), now,
        ],
      );
    }
  }

  // --- presets "mis botellas" ---

  List<TankPreset> listTankPresets() {
    final rows = _db.select(
      'SELECT Id, Name, Litres, Material FROM PandiveTankPreset '
      'ORDER BY Litres, Name',
    );
    return rows
        .map((r) => TankPreset(
              id: r['Id'] as int,
              name: _str(r['Name']) ?? '',
              litres: _num(r['Litres']) ?? 0,
              material: _materialFromInt(r['Material'] as int?) ??
                  TankMaterial.aluminium,
            ))
        .toList();
  }

  int addTankPreset(String name, double litres, TankMaterial material) {
    _db.execute(
      'INSERT INTO PandiveTankPreset (Name, Litres, Material) VALUES (?,?,?)',
      [name.trim(), litres, _materialToInt(material)],
    );
    return _db.lastInsertRowId;
  }

  void updateTankPreset(
      int id, String name, double litres, TankMaterial material) {
    _db.execute(
      'UPDATE PandiveTankPreset SET Name=?, Litres=?, Material=? WHERE Id=?',
      [name.trim(), litres, _materialToInt(material), id],
    );
  }

  void deleteTankPreset(int id) =>
      _db.execute('DELETE FROM PandiveTankPreset WHERE Id = ?', [id]);

  // --- listados filtrados ---

  List<Dive> listDivesByBuddy(int buddyId) {
    final owner = ownerId;
    final diver = owner != null ? 'AND DiverID = $owner' : '';
    final rows = _db.select(
      'SELECT ${DivemateDbQueries._diveColumns} FROM Logbook '
      "WHERE (Status IS NULL OR Status != 2) $diver "
      "AND (',' || IFNULL(BuddyIDs,'') || ',') LIKE ('%,' || ? || ',%') "
      'ORDER BY Divedate DESC, Entrytime DESC',
      [buddyId],
    );
    return rows.map(_diveFromRow).toList();
  }

  List<Dive> listDivesBySite(int placeId) {
    final owner = ownerId;
    final diver = owner != null ? 'AND DiverID = $owner' : '';
    final rows = _db.select(
      'SELECT ${DivemateDbQueries._diveColumns} FROM Logbook '
      'WHERE (Status IS NULL OR Status != 2) $diver AND PlaceID = ? '
      'ORDER BY Divedate DESC, Entrytime DESC',
      [placeId],
    );
    return rows.map(_diveFromRow).toList();
  }
}
