part of 'divemate_db.dart';

/// Botellas por inmersión, presets "mis botellas", y listados filtrados.
extension DivemateDbTanks on DivemateDb {
  /// Reemplaza las botellas de una inmersión por [tanks] y recalcula el SAC.
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
    recomputeSac(logId);
  }

  /// SAC/RMV persistido de una inmersión (columna propia), o null.
  double? diveSac(int logId) {
    final r = _db.select('SELECT PandiveSac FROM Logbook WHERE ID=?', [logId]);
    return r.isEmpty ? null : _num(r.first['PandiveSac']);
  }

  /// Calcula el SAC/RMV y lo guarda en la columna propia `Logbook.PandiveSac`.
  void recomputeSac(int logId) {
    final d = getDive(logId);
    if (d == null) return;
    final sac = computeSac(cylinders(logId),
        divetimeMin: d.durationMin, avgDepthM: d.avgDepth);
    _db.execute('UPDATE Logbook SET PandiveSac = ? WHERE ID = ?', [sac, logId]);
  }

  /// Rellena `PandiveSac` donde falte y haya botellas con presiones (al abrir).
  int fillMissingSac() {
    final owner = ownerId;
    final filter = owner != null ? 'AND L.DiverID = $owner' : '';
    final rows = _db.select(
      'SELECT L.ID FROM Logbook L WHERE (L.Status IS NULL OR L.Status != 2) '
      '$filter AND L.PandiveSac IS NULL AND EXISTS (SELECT 1 FROM Tank T '
      'WHERE T.LogID = L.ID AND T.PresS IS NOT NULL AND T.PresE IS NOT NULL '
      'AND T.Tanksize IS NOT NULL)',
    );
    for (final r in rows) {
      recomputeSac(r['ID'] as int);
    }
    return rows.length;
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
        .toList()
      ..sort((a, b) {
        final c = a.litres.compareTo(b.litres);
        return c != 0 ? c : compareFold(a.name, b.name);
      });
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
