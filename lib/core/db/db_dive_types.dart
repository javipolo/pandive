part of 'divemate_db.dart';

/// Configurable dive types and their cylinder template.
extension DivemateDbDiveTypes on DivemateDb {
  List<DiveType> listDiveTypes() {
    final rows = _db.select('SELECT Id, Name FROM PandiveDiveType');
    return rows
        .map((r) => DiveType(
              id: r['Id'] as int,
              name: _str(r['Name']) ?? '',
              tanks: diveTypeTanks(r['Id'] as int),
            ))
        .toList()
      ..sort((a, b) => compareFold(a.name, b.name));
  }

  /// Template cylinders of a type (name + litres + material; no pressures).
  List<Cylinder> diveTypeTanks(int typeId) {
    final rows = _db.select(
      'SELECT Litres, Material, Name FROM PandiveDiveTypeTank '
      'WHERE TypeId = ? ORDER BY SortOrd, Id',
      [typeId],
    );
    return rows
        .map((r) => Cylinder(
              name: _str(r['Name']),
              size: _num(r['Litres']),
              material: _materialFromInt(r['Material'] as int?),
            ))
        .toList();
  }

  int addDiveType(String name, List<Cylinder> tanks) {
    _db.execute('INSERT INTO PandiveDiveType (Name) VALUES (?)', [name.trim()]);
    final id = _db.lastInsertRowId;
    _setDiveTypeTanks(id, tanks);
    return id;
  }

  void updateDiveType(int id, String name, List<Cylinder> tanks) {
    _db.execute('UPDATE PandiveDiveType SET Name=? WHERE Id=?', [name.trim(), id]);
    _setDiveTypeTanks(id, tanks);
  }

  void deleteDiveType(int id) {
    _db.execute('DELETE FROM PandiveDiveTypeTank WHERE TypeId=?', [id]);
    _db.execute('DELETE FROM PandiveDiveType WHERE Id=?', [id]);
  }

  void _setDiveTypeTanks(int typeId, List<Cylinder> tanks) {
    _db.execute('DELETE FROM PandiveDiveTypeTank WHERE TypeId=?', [typeId]);
    for (var i = 0; i < tanks.length; i++) {
      _db.execute(
        'INSERT INTO PandiveDiveTypeTank (TypeId, Litres, Material, SortOrd, '
        'Name) VALUES (?,?,?,?,?)',
        [typeId, tanks[i].size, _materialToInt(tanks[i].material), i,
          tanks[i].name],
      );
    }
  }
}
