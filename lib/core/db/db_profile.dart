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

    return DiveProfile(
      intervalSeconds: interval,
      timesMinutes: times,
      depths: depths,
      temps: temps,
    );
  }
}
