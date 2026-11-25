part of 'divemate_db.dart';

/// Basic reads of dives and cylinders.
extension DivemateDbQueries on DivemateDb {
  static const _diveColumns =
      'ID, Number, Divedate, Entrytime, Place, Country, PlaceID, '
      'Divetime, Depth, DepthAvg, Watertemp, Airtemp, PresS, PresE, Weight, '
      'Rating, Computer, Buddy, Divemaster, Divetype, Comments, Surfint, '
      'ProfileInt, Deco, O2';

  /// The owner's dives, most recent first. Excludes deleted ones
  /// (Status = 2). [search] filters by site, country, notes, buddy or number.
  List<Dive> listDives({String? search}) {
    final owner = ownerId;
    final where = StringBuffer('(Status IS NULL OR Status != 2)');
    final params = <Object?>[];
    if (owner != null) {
      where.write(' AND DiverID = ?');
      params.add(owner);
    }
    final q = search?.trim();
    if (q != null && q.isNotEmpty) {
      where.write(' AND (Place LIKE ? OR Country LIKE ? OR Comments LIKE ? '
          'OR Buddy LIKE ? OR CAST(Number AS TEXT) = ? '
          // Also buddies linked via BuddyIDs (not just the Buddy text).
          "OR EXISTS (SELECT 1 FROM Buddy B WHERE "
          "(',' || IFNULL(BuddyIDs,'') || ',') LIKE ('%,' || B.ID || ',%') "
          'AND (B.FirstName LIKE ? OR B.LastName LIKE ?)))');
      final like = '%$q%';
      params.addAll([like, like, like, like, q, like, like]);
    }
    final rows = _db.select(
      'SELECT $_diveColumns FROM Logbook WHERE $where '
      'ORDER BY Divedate DESC, Entrytime DESC, Number DESC',
      params,
    );
    return rows.map(_diveFromRow).toList();
  }

  /// The owner's deleted dives (Status = 2), most recent first.
  /// For the trash / undelete.
  List<Dive> listDeletedDives() {
    final owner = ownerId;
    final where = StringBuffer('Status = 2');
    final params = <Object?>[];
    if (owner != null) {
      where.write(' AND DiverID = ?');
      params.add(owner);
    }
    final rows = _db.select(
      'SELECT $_diveColumns FROM Logbook WHERE $where '
      'ORDER BY Divedate DESC, Entrytime DESC, Number DESC',
      params,
    );
    return rows.map(_diveFromRow).toList();
  }

  /// A dive by its ID.
  Dive? getDive(int id) {
    final rows = _db.select(
      'SELECT $_diveColumns FROM Logbook WHERE ID = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _diveFromRow(rows.first);
  }

  int countDives() {
    final owner = ownerId;
    final base =
        'SELECT COUNT(*) c FROM Logbook WHERE (Status IS NULL OR Status != 2)';
    final sql = owner != null ? '$base AND DiverID = ?' : base;
    final rows = _db.select(sql, owner != null ? [owner] : const []);
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Next dive number for the owner (max + 1).
  int nextDiveNumber() {
    final owner = ownerId;
    final sql = owner != null
        ? 'SELECT MAX(Number) m FROM Logbook WHERE DiverID = ?'
        : 'SELECT MAX(Number) m FROM Logbook';
    final rows = _db.select(sql, owner != null ? [owner] : const []);
    return ((rows.first['m'] as int?) ?? 0) + 1;
  }

  /// Cylinders of a dive, in order.
  List<Cylinder> cylinders(int logId) {
    final rows = _db.select(
      'SELECT Tanksize, PresS, PresE, O2, He, Name, Tanktype FROM Tank '
      'WHERE LogID = ? ORDER BY SortOrd, TankID',
      [logId],
    );
    return rows
        .map((r) => Cylinder(
              size: _num(r['Tanksize']),
              pressureStart: _num(r['PresS']),
              pressureEnd: _num(r['PresE']),
              o2: _num(r['O2']),
              he: _num(r['He']),
              name: _str(r['Name']),
              material: _materialFromInt(r['Tanktype'] as int?),
            ))
        .toList();
  }
}
