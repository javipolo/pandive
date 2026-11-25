part of 'divemate_db.dart';

/// Writes: editing and creating dives (follows DiveMate conventions).
extension DivemateDbWrites on DivemateDb {
  /// Updates editable fields of a dive. Sets `Updated` to the current
  /// date. Respects UUID and Status. Ignores columns outside the allowlist.
  void updateDive(int id, Map<String, Object?> fields) {
    final cols = fields.keys.where(_editableColumns.contains).toList();
    if (cols.isEmpty) return;
    final sets = [for (final c in cols) '$c = ?', 'Updated = ?'];
    final params = <Object?>[for (final c in cols) fields[c], _nowStamp(), id];
    _db.execute('UPDATE Logbook SET ${sets.join(', ')} WHERE ID = ?', params);
  }

  /// Marks dives as deleted (Status=2, DiveMate convention).
  void deleteDives(List<int> ids) {
    final now = _nowStamp();
    for (final id in ids) {
      _db.execute('UPDATE Logbook SET Status=2, Updated=? WHERE ID=?', [now, id]);
    }
  }

  /// Restores deleted dives (Status=2 -> 1). Inverse of deleteDives.
  void restoreDives(List<int> ids) {
    final now = _nowStamp();
    for (final id in ids) {
      _db.execute('UPDATE Logbook SET Status=1, Updated=? WHERE ID=?', [now, id]);
    }
  }

  /// Sets the date/time of a dive (for batch adjustments).
  void setDiveDateTime(int id, DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    updateDive(id, {
      'Divedate': '${dt.year}-${p(dt.month)}-${p(dt.day)}',
      'Entrytime': '${p(dt.hour)}:${p(dt.minute)}:00',
    });
  }

  /// Removes rows associated with a LogID (cylinders, gas, extras, tags). Used
  /// when creating a new dive in case SQLite reuses an ID and it inherits
  /// orphan rows from an earlier dive.
  void clearDiveAssoc(int id) {
    _db.execute('DELETE FROM Tank WHERE LogID=?', [id]);
    for (final tbl in ['PandiveDiveTag', 'PandiveGas', 'PandiveSampleExtra']) {
      try {
        _db.execute('DELETE FROM $tbl WHERE DiveId=?', [id]);
      } catch (_) {/* tabla ausente */}
    }
  }

  /// Deletes orphan rows: cylinders and per-dive data whose LogID/DiveId doesn't
  /// match any dive. Returns how many cylinders were removed.
  int purgeOrphanData() {
    final n = (_db.select('SELECT COUNT(*) c FROM Tank '
            'WHERE LogID NOT IN (SELECT ID FROM Logbook)').first['c'] as int?) ??
        0;
    _db.execute('DELETE FROM Tank WHERE LogID NOT IN (SELECT ID FROM Logbook)');
    for (final tbl in ['PandiveDiveTag', 'PandiveGas', 'PandiveSampleExtra']) {
      try {
        _db.execute(
            'DELETE FROM $tbl WHERE DiveId NOT IN (SELECT ID FROM Logbook)');
      } catch (_) {/* tabla ausente */}
    }
    return n;
  }

  /// Deletes dives PERMANENTLY (row + associated data). Irreversible;
  /// allows importing them again from the computer/.ddb.
  void purgeDives(List<int> ids) {
    for (final id in ids) {
      clearDiveAssoc(id);
      _db.execute('DELETE FROM Logbook WHERE ID=?', [id]);
    }
  }

  /// Creates a new dive (manual entry). Returns the generated ID. Generates
  /// Number (if not given), UUID v4, Updated and Status=1, with the owner's DiverID.
  /// Cylinders are added separately with setDiveTanks.
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
    final id = _db.lastInsertRowId;
    clearDiveAssoc(id); // in case an ID with orphan rows is reused
    return id;
  }
}
