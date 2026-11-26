part of 'divemate_db.dart';

/// Ports (PandivePort): a reusable list of name + GPS. A trip has an optional
/// departure and arrival port (PandiveTrip.DeparturePortId/ArrivalPortId) and
/// a dive an optional port (Logbook.PandivePortId). Pandive's own table and
/// columns; DiveMate ignores them. Reads tolerate a read-only .ddb that
/// predates them.
extension DivemateDbPorts on DivemateDb {
  bool _hasColumn(String table, String col) => _db.select(
    'SELECT 1 FROM pragma_table_info(?) WHERE name = ?',
    [table, col],
  ).isNotEmpty;

  bool get _hasPorts => _hasTable('PandivePort');

  Port _portFromRow(Row r) => Port(
    id: r['Id'] as int,
    name: _str(r['Name']) ?? '—',
    lat: _num(r['Lat']),
    lon: _num(r['Lon']),
    useCount: (r['uses'] as int?) ?? 0,
  );

  /// All ports, alphabetically, with how many dives and trips use each.
  List<Port> listPorts() {
    if (!_hasPorts) return const [];
    final rows = _db.select(
      'SELECT P.Id, P.Name, P.Lat, P.Lon, '
      '(SELECT COUNT(*) FROM Logbook L WHERE L.PandivePortId = P.Id '
      ' AND (L.Status IS NULL OR L.Status != 2)) + '
      '(SELECT COUNT(*) FROM PandiveTrip T WHERE T.DeparturePortId = P.Id '
      ' OR T.ArrivalPortId = P.Id) AS uses '
      'FROM PandivePort P',
    );
    return rows.map(_portFromRow).toList()
      ..sort((a, b) => compareFold(a.name, b.name));
  }

  Port? getPort(int? id) {
    if (id == null || !_hasPorts) return null;
    final r = _db.select(
      'SELECT Id, Name, Lat, Lon FROM PandivePort WHERE Id = ?',
      [id],
    );
    return r.isEmpty ? null : _portFromRow(r.first);
  }

  int createPort(String name, {double? lat, double? lon}) {
    _db.execute(
      'INSERT INTO PandivePort (Name, Lat, Lon, Updated) VALUES (?,?,?,?)',
      [name.trim(), lat, lon, _nowStamp()],
    );
    return _db.lastInsertRowId;
  }

  void updatePort(int id, String name, {double? lat, double? lon}) =>
      _db.execute(
        'UPDATE PandivePort SET Name=?, Lat=?, Lon=?, Updated=? WHERE Id=?',
        [name.trim(), lat, lon, _nowStamp(), id],
      );

  /// Same name (case-insensitive) or a new one; used when copying between
  /// .ddb files. Fills in the coordinates if the existing one lacks them.
  int findOrCreatePort(String name, {double? lat, double? lon}) {
    final f = _db.select(
      'SELECT Id, Lat FROM PandivePort WHERE Name = ? COLLATE NOCASE',
      [name.trim()],
    );
    if (f.isEmpty) return createPort(name, lat: lat, lon: lon);
    final id = f.first['Id'] as int;
    if (f.first['Lat'] == null && lat != null && lon != null) {
      updatePort(id, name, lat: lat, lon: lon);
    }
    return id;
  }

  /// Deletes the port and unlinks it from trips and dives.
  void deletePort(int id) {
    final now = _nowStamp();
    _db.execute(
      'UPDATE Logbook SET PandivePortId = NULL, Updated = ? '
      'WHERE PandivePortId = ?',
      [now, id],
    );
    _db.execute(
      'UPDATE PandiveTrip SET DeparturePortId = NULL, Updated = ? '
      'WHERE DeparturePortId = ?',
      [now, id],
    );
    _db.execute(
      'UPDATE PandiveTrip SET ArrivalPortId = NULL, Updated = ? '
      'WHERE ArrivalPortId = ?',
      [now, id],
    );
    _db.execute('DELETE FROM PandivePort WHERE Id = ?', [id]);
  }

  /// Departure and arrival ports of a trip (each may be null).
  ({Port? departure, Port? arrival}) tripPorts(int tripId) {
    if (!_hasColumn('PandiveTrip', 'DeparturePortId')) {
      return (departure: null, arrival: null);
    }
    final r = _db.select(
      'SELECT DeparturePortId d, ArrivalPortId a FROM PandiveTrip '
      'WHERE Id = ?',
      [tripId],
    );
    if (r.isEmpty) return (departure: null, arrival: null);
    return (
      departure: getPort(r.first['d'] as int?),
      arrival: getPort(r.first['a'] as int?),
    );
  }

  /// "Same port for arrival" is stored as arrival = departure.
  void setTripPorts(int tripId, {int? departureId, int? arrivalId}) =>
      _db.execute(
        'UPDATE PandiveTrip SET DeparturePortId = ?, ArrivalPortId = ?, '
        'Updated = ? WHERE Id = ?',
        [departureId, arrivalId, _nowStamp(), tripId],
      );

  /// The port a dive left from, or null.
  Port? portForDive(int diveId) {
    if (!_hasColumn('Logbook', 'PandivePortId')) return null;
    final r = _db.select('SELECT PandivePortId p FROM Logbook WHERE ID = ?', [
      diveId,
    ]);
    return r.isEmpty ? null : getPort(r.first['p'] as int?);
  }

  void setDivePort(int diveId, int? portId) => _db.execute(
    'UPDATE Logbook SET PandivePortId = ?, Updated = ? WHERE ID = ? '
    'AND PandivePortId IS NOT ?',
    [portId, _nowStamp(), diveId, portId],
  );

  /// Distinct ports used by [diveIds] (e.g. a trip's dives), by name.
  List<Port> portsForDives(Iterable<int> diveIds) {
    final ids = diveIds.toList();
    if (ids.isEmpty || !_hasColumn('Logbook', 'PandivePortId')) return const [];
    final rows = _db.select(
      'SELECT DISTINCT P.Id, P.Name, P.Lat, P.Lon FROM PandivePort P '
      'JOIN Logbook L ON L.PandivePortId = P.Id '
      'WHERE L.ID IN (${ids.join(',')})',
    );
    return rows.map(_portFromRow).toList()
      ..sort((a, b) => compareFold(a.name, b.name));
  }
}
