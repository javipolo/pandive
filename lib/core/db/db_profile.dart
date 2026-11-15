part of 'divemate_db.dart';

/// Decode del perfil de inmersión (portado de divemate-cli/db.py).
extension DivemateDbProfile on DivemateDb {
  /// Perfil de profundidad (+ temperatura) de una inmersión.
  ///
  ///  - `Profile`: profundidad, registros de 12 chars, 4 primeros = decímetros.
  ///  - `Profile2`: temperatura, registros de 11 chars, 4 primeros = centi-°C;
  ///    0 = sin muestra.
  ///  - `ProfileInt`: intervalo de muestreo en segundos.
  DiveProfile? diveProfile(int logId) {
    final rows = _db.select(
      'SELECT ProfileInt, Profile, Profile2, Profile4 FROM Logbook WHERE ID = ?',
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
    if (p2.isNotEmpty &&
        p2.length % 11 == 0 &&
        p2.length ~/ 11 == depths.length) {
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

    // Profile4 (9 chars/muestra = NDL/TTS/parada + techo), formato DiveMate.
    // Fuera de deco: a==b==NDL, c=0. En deco: c=techo(m), a=TTS, b=parada(min).
    final ceiling = List<double>.filled(depths.length, 0);
    final ndl = List<int?>.filled(depths.length, null);
    final tts = List<int?>.filled(depths.length, null);
    final p4 = _str(r['Profile4']) ?? '';
    if (p4.length % 9 == 0 && p4.length ~/ 9 == depths.length) {
      for (var i = 0, k = 0; i < p4.length; i += 9, k++) {
        final a = int.tryParse(p4.substring(i, i + 3)) ?? 0;
        final c = int.tryParse(p4.substring(i + 6, i + 9)) ?? 0;
        ceiling[k] = c.toDouble();
        if (c > 0) {
          tts[k] = a;
        } else {
          ndl[k] = a;
        }
      }
    }

    return DiveProfile(
      intervalSeconds: interval,
      timesMinutes: times,
      depths: depths,
      temps: temps,
      ceiling: ceiling,
      ndl: ndl,
      tts: tts,
    );
  }

  /// Temp media persistida (columna propia `PandiveAvgTemp`), o null.
  double? diveAvgTemp(int logId) {
    final r =
        _db.select('SELECT PandiveAvgTemp FROM Logbook WHERE ID=?', [logId]);
    return r.isEmpty ? null : _temp(r.first['PandiveAvgTemp']);
  }

  /// Rellena temp media (`PandiveAvgTemp`) y mínima (`Watertemp`, si falta o es
  /// centinela) a partir del perfil de temperatura. Devuelve cuántas actualizó.
  int fillMissingTemps() {
    final owner = ownerId;
    final filter = owner != null ? 'AND DiverID = $owner' : '';
    final rows = _db.select(
      'SELECT ID FROM Logbook WHERE (Status IS NULL OR Status != 2) $filter '
      "AND ProfileInt > 0 AND Profile2 IS NOT NULL AND Profile2 <> '' "
      'AND PandiveAvgTemp IS NULL',
    );
    var n = 0;
    final now = _nowStamp();
    for (final r in rows) {
      final id = r['ID'] as int;
      final p = diveProfile(id);
      if (p == null) continue;
      final ts = p.temps.whereType<double>().toList();
      if (ts.isEmpty) continue;
      final minT = ts.reduce((a, b) => a < b ? a : b);
      final avgT = ts.reduce((a, b) => a + b) / ts.length;
      _db.execute(
        'UPDATE Logbook SET PandiveAvgTemp=?, Watertemp=CASE WHEN Watertemp '
        'IS NULL OR Watertemp<=-50 OR Watertemp>=60 THEN ? ELSE Watertemp END, '
        'Updated=? WHERE ID=?',
        [avgT, minT, now, id],
      );
      n++;
    }
    return n;
  }

  /// Rellena `DepthAvg` (prof. media) a partir del perfil en las inmersiones que
  /// no la tienen, para que quede persistida (y exportable a DiveMate: su SAC se
  /// deriva de DepthAvg + presiones + tiempo). Devuelve cuántas actualizó.
  int fillMissingAvgDepth() {
    final owner = ownerId;
    final filter = owner != null ? 'AND DiverID = $owner' : '';
    final rows = _db.select(
      'SELECT ID FROM Logbook WHERE (Status IS NULL OR Status != 2) $filter '
      "AND (DepthAvg IS NULL OR DepthAvg = 0) AND ProfileInt > 0 "
      "AND Profile IS NOT NULL AND Profile <> ''",
    );
    var n = 0;
    final now = _nowStamp();
    for (final r in rows) {
      final id = r['ID'] as int;
      final p = diveProfile(id);
      if (p == null || p.isEmpty) continue;
      final xs = p.depths.where((d) => d > 0).toList();
      if (xs.isEmpty) continue;
      final avg = xs.reduce((a, b) => a + b) / xs.length;
      _db.execute('UPDATE Logbook SET DepthAvg = ?, Updated = ? WHERE ID = ?',
          [avg, now, id]);
      n++;
    }
    return n;
  }
}
