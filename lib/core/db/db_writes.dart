part of 'divemate_db.dart';

/// Escrituras: edición y alta de inmersiones (respeta convenciones DiveMate).
extension DivemateDbWrites on DivemateDb {
  /// Actualiza campos editables de una inmersión. Marca `Updated` con la fecha
  /// actual. Respeta UUID y Status. Ignora columnas fuera de la allowlist.
  void updateDive(int id, Map<String, Object?> fields) {
    final cols = fields.keys.where(_editableColumns.contains).toList();
    if (cols.isEmpty) return;
    final sets = [for (final c in cols) '$c = ?', 'Updated = ?'];
    final params = <Object?>[for (final c in cols) fields[c], _nowStamp(), id];
    _db.execute('UPDATE Logbook SET ${sets.join(', ')} WHERE ID = ?', params);
  }

  /// Marca inmersiones como borradas (Status=2, convención DiveMate).
  void deleteDives(List<int> ids) {
    final now = _nowStamp();
    for (final id in ids) {
      _db.execute('UPDATE Logbook SET Status=2, Updated=? WHERE ID=?', [now, id]);
    }
  }

  /// Restaura inmersiones borradas (Status=2 -> 1). Inverso de deleteDives.
  void restoreDives(List<int> ids) {
    final now = _nowStamp();
    for (final id in ids) {
      _db.execute('UPDATE Logbook SET Status=1, Updated=? WHERE ID=?', [now, id]);
    }
  }

  /// Fija la fecha/hora de una inmersión (para ajustes en lote).
  void setDiveDateTime(int id, DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    updateDive(id, {
      'Divedate': '${dt.year}-${p(dt.month)}-${p(dt.day)}',
      'Entrytime': '${p(dt.hour)}:${p(dt.minute)}:00',
    });
  }

  /// Borra inmersiones DEFINITIVAMENTE (fila + datos asociados). Irreversible;
  /// permite volver a importarlas desde el ordenador/.ddb.
  void purgeDives(List<int> ids) {
    for (final id in ids) {
      _db.execute('DELETE FROM Tank WHERE LogID=?', [id]);
      for (final tbl in ['PandiveDiveTag', 'PandiveGas', 'PandiveSampleExtra']) {
        try {
          _db.execute('DELETE FROM $tbl WHERE DiveId=?', [id]);
        } catch (_) {/* tabla ausente */}
      }
      _db.execute('DELETE FROM Logbook WHERE ID=?', [id]);
    }
  }

  /// Crea una inmersión nueva (alta manual). Devuelve el ID generado. Genera
  /// Number (si no se pasa), UUID v4, Updated y Status=1, con DiverID del owner.
  /// Las botellas se añaden aparte con setDiveTanks.
  int createDive({
    required DateTime dateTime,
    int? number,
    String? place,
    String? country,
    int? placeId,
    double? maxDepth,
    double? avgDepth,
    double? durationMin,
    double? waterTemp,
    double? airTemp,
    double? weight,
    int rating = 0,
    String? buddy,
    String? buddyIds,
    String? comments,
  }) {
    final owner = ownerId ?? 1;
    final num = number ?? nextDiveNumber();
    final now = _nowStamp();
    String p(int v) => v.toString().padLeft(2, '0');
    final divedate = '${dateTime.year}-${p(dateTime.month)}-${p(dateTime.day)}';
    final entrytime = '${p(dateTime.hour)}:${p(dateTime.minute)}:00';

    _db.execute(
      'INSERT INTO Logbook (Number, Divedate, Entrytime, DiverID, UUID, '
      'Updated, Status, Place, Country, PlaceID, Depth, DepthAvg, Divetime, '
      'Watertemp, Airtemp, Weight, Rating, Buddy, BuddyIDs, Comments) '
      'VALUES (?,?,?,?,?,?,1,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        num, divedate, entrytime, owner, _uuid(), now,
        place, country, placeId, maxDepth, avgDepth, durationMin, waterTemp,
        airTemp, weight, rating, buddy, buddyIds, comments,
      ],
    );
    return _db.lastInsertRowId;
  }
}
