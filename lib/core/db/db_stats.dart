part of 'divemate_db.dart';

/// Agregados: sitios de buceo y estadísticas.
extension DivemateDbStats on DivemateDb {
  /// Puntos de buceo con nº de inmersiones del owner, más visitados primero.
  List<DiveSite> listSites() {
    final owner = ownerId;
    final diveFilter = StringBuffer('(L.Status IS NULL OR L.Status != 2)');
    final params = <Object?>[];
    if (owner != null) {
      diveFilter.write(' AND L.DiverID = ?');
      params.add(owner);
    }
    final rows = _db.select(
      'SELECT P.ID, P.Place, P.Country, P.Region, P.Lat, P.Lon, '
      '       P.MaxDepth, P.Rating, '
      '       (SELECT COUNT(*) FROM Logbook L '
      '        WHERE L.PlaceID = P.ID AND $diveFilter) AS dives '
      'FROM Place P '
      'ORDER BY dives DESC, P.Place COLLATE NOCASE',
      params,
    );
    return rows
        .map((r) => DiveSite(
              id: r['ID'] as int,
              name: _str(r['Place']),
              country: _str(r['Country']),
              region: _str(r['Region']),
              lat: _num(r['Lat']),
              lon: _num(r['Lon']),
              maxDepth: _num(r['MaxDepth']),
              rating: r['Rating'] as int?,
              diveCount: (r['dives'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Estadísticas agregadas del owner. Si [ids] no es null, solo esas
  /// inmersiones (para las stats de una selección); misma plantilla y cálculos.
  LogbookStats computeStats({Iterable<int>? ids}) {
    final owner = ownerId;
    final filter = StringBuffer('(Status IS NULL OR Status != 2)');
    final params = <Object?>[];
    if (owner != null) {
      filter.write(' AND DiverID = ?');
      params.add(owner);
    }
    if (ids != null) {
      final list = ids.toList();
      filter.write(' AND ID IN (${list.isEmpty ? '-1' : list.join(',')})');
    }
    // Solo lecturas de temperatura plausibles (p.ej. -300 = "sin lectura").
    const tempOk = 'Watertemp > -50 AND Watertemp < 60';
    // PandiveSac es columna propia; puede faltar (p.ej. DB abierta solo lectura).
    final hasSac = _db
        .select("SELECT 1 FROM pragma_table_info('Logbook') "
            "WHERE name='PandiveSac'")
        .isNotEmpty;
    final sacCols = hasSac
        ? 'MAX(CASE WHEN PandiveSac > 0 THEN PandiveSac END) sacmax, '
            'MIN(CASE WHEN PandiveSac > 0 THEN PandiveSac END) sacmin, '
            'AVG(CASE WHEN PandiveSac > 0 THEN PandiveSac END) sacavg, '
        : 'NULL sacmax, NULL sacmin, NULL sacavg, ';
    final agg = _db.select(
      'SELECT COUNT(*) n, '
      '       COALESCE(SUM(Divetime),0) mins, '
      '       MAX(Divetime) maxmin, '
      '       AVG(Divetime) avgmin, '
      '       MAX(Depth) maxd, '
      '       AVG(NULLIF(DepthAvg,0)) avgd, '
      '       $sacCols'
      '       MAX(CASE WHEN $tempOk THEN Watertemp END) tmax, '
      '       MIN(CASE WHEN $tempOk THEN Watertemp END) tmin, '
      '       AVG(CASE WHEN $tempOk THEN Watertemp END) avgtemp, '
      '       MIN(Divedate) first, MAX(Divedate) last '
      'FROM Logbook WHERE $filter',
      params,
    ).first;

    final perYear = <int, int>{};
    for (final r in _db.select(
      "SELECT CAST(strftime('%Y', Divedate) AS INTEGER) y, COUNT(*) c "
      'FROM Logbook WHERE $filter AND Divedate IS NOT NULL '
      'GROUP BY y ORDER BY y',
      params,
    )) {
      final y = r['y'] as int?;
      if (y != null) perYear[y] = (r['c'] as int?) ?? 0;
    }

    // Deco: cuenta por columna; TTS/ceiling máx. decodificando Profile4 solo de
    // los buceos con deco (barato frente a decodificar todo el logbook).
    int decoDives = 0;
    int maxTts = 0;
    double maxCeiling = 0;
    int maxCeilSecs = 0; // más tiempo con techo (segundos) de un solo buceo
    for (final r
        in _db.select('SELECT ID FROM Logbook WHERE $filter AND Deco = 1', params)) {
      decoDives++;
      final p = diveProfile(r['ID'] as int);
      if (p == null) continue;
      int ceilSamples = 0;
      for (final c in p.ceiling) {
        if (c <= 0) continue;
        ceilSamples++;
        if (c > maxCeiling) maxCeiling = c;
      }
      final secs = ceilSamples * p.intervalSeconds;
      if (secs > maxCeilSecs) maxCeilSecs = secs;
      for (final x in p.tts) {
        if (x != null && x > maxTts) maxTts = x;
      }
    }

    // Buddies distintos referenciados por las inmersiones del filtro.
    final buddyIds = <int>{};
    for (final r in _db.select(
        'SELECT BuddyIDs FROM Logbook WHERE $filter', params)) {
      for (final e in (_str(r['BuddyIDs']) ?? '').split(',')) {
        final v = int.tryParse(e.trim());
        if (v != null) buddyIds.add(v);
      }
    }
    final buddies = buddyIds.length;
    return LogbookStats(
      totalDives: (agg['n'] as int?) ?? 0,
      buddiesCount: buddies,
      totalMinutes: _num(agg['mins']) ?? 0,
      maxDiveMinutes: _num(agg['maxmin']),
      avgDiveMinutes: _num(agg['avgmin']),
      maxDepth: _num(agg['maxd']),
      avgDepth: _num(agg['avgd']),
      sacMax: _num(agg['sacmax']),
      sacMin: _num(agg['sacmin']),
      sacAvg: _num(agg['sacavg']),
      tempMax: _num(agg['tmax']),
      tempMin: _num(agg['tmin']),
      avgWaterTemp: _num(agg['avgtemp']),
      decoDives: decoDives,
      maxTts: maxTts > 0 ? maxTts : null,
      maxCeiling: maxCeiling > 0 ? maxCeiling : null,
      maxCeilingMinutes: maxCeilSecs > 0 ? maxCeilSecs / 60.0 : null,
      firstDive: _parseDate(_str(agg['first']), null),
      lastDive: _parseDate(_str(agg['last']), null),
      divesPerYear: perYear,
    );
  }

  /// Récords personales del owner: el buceo más profundo, más largo y más frío.
  PersonalRecords personalRecords() {
    final owner = ownerId;
    final f = owner != null ? 'AND DiverID = $owner' : '';
    DiveRecord? top(String col, String order, String extra) {
      final rows = _db.select(
        "SELECT ID, $col v, Divedate, Entrytime, Place FROM Logbook "
        "WHERE (Status IS NULL OR Status != 2) $f AND $extra "
        "ORDER BY $order LIMIT 1");
      if (rows.isEmpty) return null;
      final r = rows.first;
      final v = _num(r['v']);
      if (v == null) return null;
      return DiveRecord(r['ID'] as int, v,
          _parseDate(_str(r['Divedate']), _str(r['Entrytime'])), _str(r['Place']));
    }

    // Récords de deco: recorrer buceos con deco y decodificar el perfil.
    int? ttsId, ceilId;
    int bestTts = 0, bestCeilSecs = 0;
    for (final r in _db.select(
        "SELECT ID FROM Logbook WHERE (Status IS NULL OR Status != 2) $f AND Deco = 1")) {
      final id = r['ID'] as int;
      final p = diveProfile(id);
      if (p == null) continue;
      var ceilSamples = 0;
      for (final c in p.ceiling) {
        if (c > 0) ceilSamples++;
      }
      final secs = ceilSamples * p.intervalSeconds;
      if (secs > bestCeilSecs) {
        bestCeilSecs = secs;
        ceilId = id;
      }
      for (final x in p.tts) {
        if (x != null && x > bestTts) {
          bestTts = x;
          ttsId = id;
        }
      }
    }
    DiveRecord? decoRec(int? id, double value) {
      if (id == null || value <= 0) return null;
      final r = _db.select(
          'SELECT Divedate, Entrytime, Place FROM Logbook WHERE ID = ?', [id]);
      final row = r.isEmpty ? null : r.first;
      return DiveRecord(id, value,
          row == null ? null : _parseDate(_str(row['Divedate']), _str(row['Entrytime'])),
          row == null ? null : _str(row['Place']));
    }

    return PersonalRecords(
      deepest: top('Depth', 'Depth DESC', 'Depth > 0'),
      longest: top('Divetime', 'Divetime DESC', 'Divetime > 0'),
      coldest: top('Watertemp', 'Watertemp ASC', 'Watertemp > -50 AND Watertemp < 60'),
      longestDeco: decoRec(ttsId, bestTts.toDouble()),
      longestCeiling: decoRec(ceilId, bestCeilSecs / 60.0),
    );
  }
}
