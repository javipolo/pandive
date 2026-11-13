part of 'divemate_db.dart';

/// Puntos de buceo (tabla Place). Campos usados: nombre, país, stretch of
/// water (WaterName), región, lat/lon, dificultad, valoración.
extension DivemateDbSites on DivemateDb {
  static const _siteCols =
      'ID, Place, Country, WaterName, Region, Lat, Lon, Difficulty, Rating, MaxDepth';

  DiveSite _siteFromRow(Row r) => DiveSite(
        id: r['ID'] as int,
        name: _str(r['Place']),
        country: _str(r['Country']),
        region: _str(r['Region']),
        waterName: _str(r['WaterName']),
        lat: _num(r['Lat']),
        lon: _num(r['Lon']),
        maxDepth: _num(r['MaxDepth']),
        difficulty: _str(r['Difficulty']),
        rating: r['Rating'] as int?,
      );

  DiveSite? getSite(int id) {
    final rows = _db.select('SELECT $_siteCols FROM Place WHERE ID=?', [id]);
    return rows.isEmpty ? null : _siteFromRow(rows.first);
  }

  static const _siteEditable = {
    'Place', 'Country', 'WaterName', 'Region', 'Lat', 'Lon', 'Difficulty', 'Rating',
  };

  void updateSite(int id, Map<String, Object?> fields) {
    final cols = fields.keys.where(_siteEditable.contains).toList();
    if (cols.isEmpty) return;
    final sets = [for (final c in cols) '$c = ?', 'Updated = ?'];
    final params = <Object?>[for (final c in cols) fields[c], _nowStamp(), id];
    _db.execute('UPDATE Place SET ${sets.join(', ')} WHERE ID=?', params);
  }

  int createSite(Map<String, Object?> fields) {
    _db.execute(
      'INSERT INTO Place (Place, Country, WaterName, Region, Lat, Lon, '
      'Difficulty, Rating, UUID, Updated) VALUES (?,?,?,?,?,?,?,?,?,?)',
      [
        fields['Place'], fields['Country'], fields['WaterName'],
        fields['Region'], fields['Lat'], fields['Lon'], fields['Difficulty'],
        fields['Rating'], _uuid(), _nowStamp(),
      ],
    );
    return _db.lastInsertRowId;
  }

  /// Busca un sitio por nombre (+país opcional) o lo crea. Devuelve su ID.
  int findOrCreateSite(String name, {String? country}) {
    final rows = _db.select(
      'SELECT ID FROM Place WHERE Place = ? COLLATE NOCASE '
      "AND IFNULL(Country,'') = IFNULL(?, '')",
      [name.trim(), country],
    );
    if (rows.isNotEmpty) return rows.first['ID'] as int;
    return createSite({'Place': name.trim(), 'Country': country});
  }
}
