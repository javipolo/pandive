part of 'divemate_db.dart';

/// Aggregates: dive sites and statistics.
extension DivemateDbStats on DivemateDb {
  /// Dive sites with the owner's dive count, most visited first.
  List<DiveSite> listSites() {
    final owner = ownerId;
    final diveFilter = StringBuffer('(L.Status IS NULL OR L.Status != 2)');
    final params = <Object?>[];
    if (owner != null) {
      diveFilter.write(' AND L.DiverID = ?');
      params.add(owner);
    }
    // PandiveSiteTag only exists in our own DBs (not in external read-only .ddb files).
    final tagsCol = _hasTable('PandiveSiteTag')
        ? "(SELECT GROUP_CONCAT(T.Name, char(10)) FROM PandiveSiteTag S "
            'JOIN PandiveTag T ON T.Id = S.TagId WHERE S.PlaceId = P.ID)'
        : 'NULL';
    final rows = _db.select(
      'SELECT P.ID, P.Place, P.Country, P.Region, P.Lat, P.Lon, '
      '       P.MaxDepth, P.Rating, '
      '       (SELECT COUNT(*) FROM Logbook L '
      '        WHERE L.PlaceID = P.ID AND $diveFilter) AS dives, '
      '       $tagsCol AS tags '
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
              tags: (_str(r['tags']) ?? '').isEmpty
                  ? const []
                  : _str(r['tags'])!.split('\n'),
            ))
        .toList();
  }

  /// The owner's aggregate statistics. If [ids] is not null, only those
  /// dives (for the stats of a selection); same template and calculations.
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
    // Only plausible temperature readings (e.g. -300 = "no reading").
    const tempOk = 'Watertemp > -50 AND Watertemp < 60';
    // PandiveSac is our own column; it may be missing (e.g. DB opened read-only).
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

    // Deco: count by column; max TTS/ceiling by decoding Profile4 only for
    // dives with deco (cheap compared to decoding the whole logbook).
    int decoDives = 0;
    int maxTts = 0;
    double maxCeiling = 0;
    int maxCeilSecs = 0; // longest time under a ceiling (seconds) in a single dive
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

    // Distinct buddies referenced by the filtered dives.
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

  /// The owner's personal records: deepest, longest and coldest dive.
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

    // Deco records: walk dives with deco and decode the profile.
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
