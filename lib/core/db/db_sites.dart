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
    // Propaga nombre/país a las inmersiones ya registradas de este sitio.
    if (fields.containsKey('Place') || fields.containsKey('Country')) {
      _db.execute(
        'UPDATE Logbook SET Place=?, Country=?, Updated=? WHERE PlaceID=?',
        [fields['Place'], fields['Country'], _nowStamp(), id],
      );
    }
  }

  void deleteSite(int id) => _db.execute('DELETE FROM Place WHERE ID=?', [id]);

  /// Borra los sitios sin ninguna inmersión (del owner). Devuelve cuántos.
  int purgeUnusedSites() {
    final unused = [for (final s in listSites()) if (s.diveCount == 0) s.id];
    for (final id in unused) {
      deleteSite(id);
    }
    return unused.length;
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

  /// Busca un sitio por nombre (+país opcional) o lo crea. Devuelve su ID. Si
  /// existe pero no tiene coordenadas y se pasan [lat]/[lon], las rellena (no
  /// sobrescribe las que ya tenga).
  int findOrCreateSite(String name, {String? country, double? lat, double? lon}) {
    final rows = _db.select(
      'SELECT ID, Lat, Lon FROM Place WHERE Place = ? COLLATE NOCASE '
      "AND IFNULL(Country,'') = IFNULL(?, '')",
      [name.trim(), country],
    );
    if (rows.isNotEmpty) {
      final id = rows.first['ID'] as int;
      final hasCoords =
          _num(rows.first['Lat']) != null && _num(rows.first['Lon']) != null;
      if (!hasCoords && lat != null && lon != null) {
        _db.execute('UPDATE Place SET Lat=?, Lon=?, Updated=? WHERE ID=?', [
          lat.toStringAsFixed(6),
          lon.toStringAsFixed(6),
          _nowStamp(),
          id,
        ]);
      }
      return id;
    }
    return createSite(
        {'Place': name.trim(), 'Country': country, 'Lat': lat, 'Lon': lon});
  }
}
