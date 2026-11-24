part of 'divemate_db.dart';

// Numeración automática: los buceos del owner (sin los de la papelera) van
// numerados de forma consecutiva y en orden cronológico, empezando en un
// "primer número" (para quien trae buceos de un logbook anterior). La
// configuración vive en la propia DB (PandiveMeta), no en los ajustes del
// dispositivo: así el móvil y el PC numeran igual y la sync no oscila.

const _kAutoNumber = 'autoNumber';
const _kFirstNumber = 'firstNumber';

/// Un buceo que cambiaría de número al renumerar.
class RenumberChange {
  final int id;
  final int? from;
  final int to;
  const RenumberChange(this.id, this.from, this.to);
}

extension DivemateDbNumbering on DivemateDb {
  /// Numeración automática activada (por defecto sí).
  bool get autoNumber => _metaGet(_kAutoNumber) != '0';

  /// Primer número de la numeración. Si nunca se fijó: el número más bajo
  /// del owner (papelera incluida, para que borrar el primero no lo mueva),
  /// o 1 si no hay buceos.
  int get firstNumber {
    final v = int.tryParse(_metaGet(_kFirstNumber) ?? '');
    if (v != null) return v;
    final owner = ownerId;
    final rows = _db.select(
        'SELECT MIN(Number) m FROM Logbook WHERE Number IS NOT NULL'
        '${owner != null ? ' AND DiverID = ?' : ''}',
        owner != null ? [owner] : const []);
    final m = rows.first['m'] as int?;
    return m != null && m > 0 ? m : 1;
  }

  /// Activa o desactiva la numeración automática; al activarla, renumera.
  /// Devuelve cuántos buceos cambiaron de número.
  int setAutoNumber(bool v) {
    _pinFirstNumber();
    _metaSet(_kAutoNumber, v ? '1' : '0');
    _touchLastWrite(); // que viaje con la sync aunque no cambie ningún nº
    return v ? renumberDives() : 0;
  }

  /// Cambia el primer número; con la numeración automática, renumera.
  /// Devuelve cuántos buceos cambiaron de número.
  int setFirstNumber(int n) {
    _metaSet(_kFirstNumber, '${n < 0 ? 0 : n}');
    _touchLastWrite();
    return autoNumber ? renumberDives() : 0;
  }

  /// Qué buceos cambiarían de número (orden: fecha, hora, nº actual, ID).
  List<RenumberChange> renumberPlan() {
    final owner = ownerId;
    final rows = _db.select(
        'SELECT ID, Number FROM Logbook WHERE (Status IS NULL OR Status != 2)'
        '${owner != null ? ' AND DiverID = ?' : ''} '
        'ORDER BY Divedate, Entrytime, Number, ID',
        owner != null ? [owner] : const []);
    var n = firstNumber;
    final out = <RenumberChange>[];
    for (final r in rows) {
      final old = r['Number'] as int?;
      if (old != n) out.add(RenumberChange(r['ID'] as int, old, n));
      n++;
    }
    return out;
  }

  /// Número que tendría un buceo nuevo en [when] con la numeración
  /// automática (va detrás de los que tienen la misma fecha y hora).
  int numberForNewDive(DateTime when) {
    String p(int v) => v.toString().padLeft(2, '0');
    final date = '${when.year}-${p(when.month)}-${p(when.day)}';
    final time = '${p(when.hour)}:${p(when.minute)}:00';
    final owner = ownerId;
    final rows = _db.select(
        'SELECT COUNT(*) c FROM Logbook WHERE (Status IS NULL OR Status != 2) '
        'AND (Divedate < ? OR (Divedate = ? AND Entrytime <= ?))'
        '${owner != null ? ' AND DiverID = ?' : ''}',
        [date, date, time, ?owner]);
    return firstNumber + ((rows.first['c'] as int?) ?? 0);
  }

  /// ¿El buceo [id] rompe el orden cronológico de los números? (hay uno
  /// posterior con número menor o uno anterior con número mayor).
  bool isOutOfOrder(int id) {
    final r = _db.select(
        'SELECT Number, Divedate, Entrytime, DiverID FROM Logbook WHERE ID = ?',
        [id]);
    if (r.isEmpty || r.first['Number'] == null) return false;
    final d = r.first;
    final key = '${d['Divedate'] ?? ''} ${d['Entrytime'] ?? ''}';
    final rows = _db.select(
        'SELECT 1 FROM Logbook WHERE (Status IS NULL OR Status != 2) '
        'AND ID != ? AND DiverID IS ? AND Number IS NOT NULL AND ('
        "(IFNULL(Divedate,'') || ' ' || IFNULL(Entrytime,'') > ? AND Number < ?) OR "
        "(IFNULL(Divedate,'') || ' ' || IFNULL(Entrytime,'') < ? AND Number > ?)"
        ') LIMIT 1',
        [id, d['DiverID'], key, d['Number'], key, d['Number']]);
    return rows.isNotEmpty;
  }

  /// Aplica [renumberPlan]; solo toca (y marca Updated en) los que cambian.
  /// Devuelve cuántos cambiaron.
  int renumberDives() {
    _pinFirstNumber();
    final plan = renumberPlan();
    if (plan.isEmpty) return 0;
    final now = _nowStamp();
    _db.execute('BEGIN');
    try {
      for (final c in plan) {
        _db.execute('UPDATE Logbook SET Number = ?, Updated = ? WHERE ID = ?',
            [c.to, now, c.id]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return plan.length;
  }

  /// Renumera si la numeración automática está activa. Llamar tras crear,
  /// borrar, restaurar, fusionar, importar o cambiar la fecha de buceos.
  int autoRenumber() => autoNumber ? renumberDives() : 0;

  // Fija el primer número calculado antes de que un borrado definitivo o un
  // cambio lo pueda mover.
  void _pinFirstNumber() {
    if (_metaGet(_kFirstNumber) == null) _metaSet(_kFirstNumber, '$firstNumber');
  }
}
