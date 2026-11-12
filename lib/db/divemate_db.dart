/// Capa de acceso a la base de datos DiveMate (.ddb, SQLite).
///
/// Pandive usa el mismo formato que DiveMate (sin migración). Esta clase abre
/// el fichero y expone consultas tipadas sobre el subconjunto de columnas que
/// la app usa. El decode de perfiles está portado de `divemate-cli`.
library;

import 'package:sqlite3/sqlite3.dart';

import '../models.dart';

class DivemateDb {
  final Database _db;
  int? _ownerId;

  DivemateDb._(this._db);

  /// Abre una .ddb existente en [path] (solo lectura por defecto en Fase 1;
  /// escritura llegará con la importación del computer).
  factory DivemateDb.open(String path, {bool readOnly = false}) {
    final db = sqlite3.open(
      path,
      mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite,
    );
    return DivemateDb._(db);
  }

  void close() => _db.dispose();

  /// DiverID "dueño" = el perfil con más inmersiones (ver owner_id en la CLI).
  /// Una .ddb puede contener varios diver profiles (demo/imports).
  int? get ownerId {
    if (_ownerId != null) return _ownerId;
    final rows = _db.select(
      'SELECT DiverID FROM Logbook GROUP BY DiverID '
      'ORDER BY COUNT(*) DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    return _ownerId = rows.first['DiverID'] as int?;
  }

  /// Comprueba que el fichero parece una DB DiveMate válida.
  bool get looksValid {
    try {
      final t = _db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Logbook'",
      );
      return t.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Lista de inmersiones del owner, más recientes primero.
  /// Excluye las marcadas como borradas (Status = 2).
  /// [search] filtra por sitio, país o notas (case-insensitive).
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
          'OR Buddy LIKE ? OR CAST(Number AS TEXT) = ?)');
      final like = '%$q%';
      params.addAll([like, like, like, like, q]);
    }
    final rows = _db.select(
      'SELECT ID, Number, Divedate, Entrytime, Place, Country, PlaceID, '
      'Divetime, Depth, DepthAvg, Watertemp, Airtemp, PresS, PresE, Weight, '
      'Rating, Computer, Buddy, Divemaster, Divetype, Comments, Surfint, '
      'ProfileInt '
      'FROM Logbook WHERE $where '
      'ORDER BY Divedate DESC, Entrytime DESC, Number DESC',
      params,
    );
    return rows.map(_diveFromRow).toList();
  }

  int countDives() {
    final owner = ownerId;
    final sql = owner != null
        ? 'SELECT COUNT(*) c FROM Logbook WHERE (Status IS NULL OR Status != 2) AND DiverID = ?'
        : 'SELECT COUNT(*) c FROM Logbook WHERE (Status IS NULL OR Status != 2)';
    final rows = _db.select(sql, owner != null ? [owner] : const []);
    return (rows.first['c'] as int?) ?? 0;
  }

  Dive _diveFromRow(Row r) {
    return Dive(
      id: r['ID'] as int,
      number: r['Number'] as int?,
      date: _parseDate(r['Divedate'] as String?, r['Entrytime'] as String?),
      place: _str(r['Place']),
      country: _str(r['Country']),
      placeId: r['PlaceID'] as int?,
      durationMin: _num(r['Divetime']),
      maxDepth: _num(r['Depth']),
      avgDepth: _num(r['DepthAvg']),
      waterTemp: _temp(r['Watertemp']),
      airTemp: _temp(r['Airtemp']),
      pressureStart: _num(r['PresS']),
      pressureEnd: _num(r['PresE']),
      weight: _num(r['Weight']),
      rating: r['Rating'] as int?,
      computer: _str(r['Computer']),
      buddy: _str(r['Buddy']),
      diveMaster: _str(r['Divemaster']),
      diveType: _str(r['Divetype']),
      comments: _str(r['Comments']),
      surfaceInterval: _str(r['Surfint']),
      profileInterval: r['ProfileInt'] as int?,
    );
  }

  /// Una inmersión por su ID (mismo mapeo que listDives).
  Dive? getDive(int id) {
    final rows = _db.select(
      'SELECT ID, Number, Divedate, Entrytime, Place, Country, PlaceID, '
      'Divetime, Depth, DepthAvg, Watertemp, Airtemp, PresS, PresE, Weight, '
      'Rating, Computer, Buddy, Divemaster, Divetype, Comments, Surfint, '
      'ProfileInt FROM Logbook WHERE ID = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _diveFromRow(rows.first);
  }

  /// Columnas editables desde la UI (allowlist: evita tocar perfiles, IDs,
  /// campos de sincronización, etc.).
  static const _editableColumns = {
    'Comments', 'Rating', 'Buddy', 'Divemaster', 'Divetype', 'Weight',
    'Place', 'Country',
  };

  /// Actualiza campos editables de una inmersión. Marca `Updated` con la fecha
  /// actual (formato DiveMate: YYYY-MM-DDTHH:MM:SS, hora local). Respeta UUID y
  /// Status existentes. Ignora columnas fuera de la allowlist.
  void updateDive(int id, Map<String, Object?> fields) {
    final cols = fields.keys.where(_editableColumns.contains).toList();
    if (cols.isEmpty) return;
    final sets = [for (final c in cols) '$c = ?', 'Updated = ?'];
    final params = <Object?>[for (final c in cols) fields[c], _nowStamp(), id];
    _db.execute('UPDATE Logbook SET ${sets.join(', ')} WHERE ID = ?', params);
  }

  static String _nowStamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${p(n.month)}-${p(n.day)}T'
        '${p(n.hour)}:${p(n.minute)}:${p(n.second)}';
  }

  /// Botellas de una inmersión, en orden.
  List<Cylinder> cylinders(int logId) {
    final rows = _db.select(
      'SELECT Tanksize, PresS, PresE, O2, He, Name FROM Tank '
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
            ))
        .toList();
  }

  /// Perfil de profundidad (+ temperatura) de una inmersión.
  ///
  /// Formato DiveMate (portado de divemate-cli/db.py):
  ///  - `Profile`: profundidad, registros de 12 chars, 4 primeros = decímetros.
  ///  - `Profile2`: temperatura, registros de 11 chars, 4 primeros = centi-°C;
  ///    0 = sin muestra.
  ///  - `ProfileInt`: intervalo de muestreo en segundos.
  DiveProfile? diveProfile(int logId) {
    final rows = _db.select(
      'SELECT ProfileInt, Profile, Profile2 FROM Logbook WHERE ID = ?',
      [logId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final interval = (r['ProfileInt'] as int?) ?? 0;
    final prof = _str(r['Profile']) ?? '';
    if (interval <= 0 || prof.length < 12 || prof.length % 12 != 0) return null;

    final depths = <double>[];
    for (var i = 0; i < prof.length; i += 12) {
      final d = int.tryParse(prof.substring(i, i + 4)) ?? 0;
      depths.add(d / 10.0);
    }
    final times = [
      for (var i = 0; i < depths.length; i++) i * interval / 60.0,
    ];

    var temps = List<double?>.filled(depths.length, null);
    final p2 = _str(r['Profile2']) ?? '';
    if (p2.isNotEmpty && p2.length % 11 == 0 && p2.length ~/ 11 == depths.length) {
      var anyTemp = false;
      for (var i = 0, k = 0; i < p2.length; i += 11, k++) {
        final v = int.tryParse(p2.substring(i, i + 4)) ?? 0;
        if (v != 0 && v > -500 && v < 6000) {
          temps[k] = v / 100.0;
          anyTemp = true;
        }
      }
      if (!anyTemp) temps = List<double?>.filled(depths.length, null);
    }

    return DiveProfile(
      intervalSeconds: interval,
      timesMinutes: times,
      depths: depths,
      temps: temps,
    );
  }

  /// Puntos de buceo con nº de inmersiones del owner, más visitados primero.
  List<DiveSite> listSites() {
    final owner = ownerId;
    // Contar dives por PlaceID (solo del owner, no borradas).
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
    final agg = _db.select(
      'SELECT COUNT(*) n, '
      '       COALESCE(SUM(Divetime),0) mins, '
      '       AVG(Divetime) avgmin, '
      '       MAX(Depth) maxd, '
      '       AVG(NULLIF(DepthAvg,0)) avgd, '
      // Excluye centinelas/implausibles (p.ej. -300 = "sin lectura").
      '       AVG(CASE WHEN Watertemp > -50 AND Watertemp < 60 THEN Watertemp END) avgtemp, '
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

    return LogbookStats(
      totalDives: (agg['n'] as int?) ?? 0,
      totalMinutes: _num(agg['mins']) ?? 0,
      avgDiveMinutes: _num(agg['avgmin']),
      maxDepth: _num(agg['maxd']),
      avgDepth: _num(agg['avgd']),
      avgWaterTemp: _num(agg['avgtemp']),
      firstDive: _parseDate(_str(agg['first']), null),
      lastDive: _parseDate(_str(agg['last']), null),
      divesPerYear: perYear,
    );
  }

  // --- helpers de conversión ---

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _num(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Temperatura, descartando centinelas/implausibles (p.ej. -300 °C).
  static double? _temp(Object? v) {
    final t = _num(v);
    if (t == null || t <= -50 || t >= 60) return null;
    return t;
  }

  /// Divedate = "YYYY-MM-DD", Entrytime = "HH:MM" (o "HH:MM:SS").
  static DateTime? _parseDate(String? date, String? time) {
    if (date == null || date.isEmpty) return null;
    final d = DateTime.tryParse(date);
    if (d == null) return null;
    if (time != null && time.isNotEmpty) {
      final parts = time.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return DateTime(d.year, d.month, d.day, h, m);
    }
    return d;
  }
}
