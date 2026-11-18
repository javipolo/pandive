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

  /// Estadísticas agregadas del owner.
  LogbookStats computeStats() {
    final owner = ownerId;
    final filter = StringBuffer('(Status IS NULL OR Status != 2)');
    final params = <Object?>[];
    if (owner != null) {
      filter.write(' AND DiverID = ?');
      params.add(owner);
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

    final buddies = listBuddies().where((b) => b.diveCount > 0).length;
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
      firstDive: _parseDate(_str(agg['first']), null),
      lastDive: _parseDate(_str(agg['last']), null),
      divesPerYear: perYear,
    );
  }
}
