part of 'divemate_db.dart';

// Automatic numbering: the owner's dives (excluding trashed ones) are
// numbered consecutively in chronological order, starting at a
// "first number" (for those bringing dives from a previous logbook). The
// setting lives in the DB itself (PandiveMeta), not in the device
// settings: so phone and PC number alike and sync doesn't oscillate.

const _kAutoNumber = 'autoNumber';
const _kFirstNumber = 'firstNumber';

/// A dive that would change number when renumbering.
class RenumberChange {
  final int id;
  final int? from;
  final int to;
  const RenumberChange(this.id, this.from, this.to);
}

extension DivemateDbNumbering on DivemateDb {
  /// Automatic numbering enabled (yes by default).
  bool get autoNumber => _metaGet(_kAutoNumber) != '0';

  /// First number of the numbering. If never set: the owner's lowest
  /// number (trash included, so deleting the first doesn't move it),
  /// or 1 if there are no dives.
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

  /// Turns automatic numbering on or off; turning it on renumbers.
  /// Returns how many dives changed number.
  int setAutoNumber(bool v) {
    _pinFirstNumber();
    _metaSet(_kAutoNumber, v ? '1' : '0');
    _touchLastWrite(); // so it travels with sync even if no number changes
    return v ? renumberDives() : 0;
  }

  /// Changes the first number; with automatic numbering, renumbers.
  /// Returns how many dives changed number.
  int setFirstNumber(int n) {
    _metaSet(_kFirstNumber, '${n < 0 ? 0 : n}');
    _touchLastWrite();
    return autoNumber ? renumberDives() : 0;
  }

  /// Which dives would change number (order: date, time, current number, ID).
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

  /// Number a new dive at [when] would get with automatic
  /// numbering (goes after those with the same date and time).
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

  /// Does dive [id] break the chronological order of numbers? (there is a
  /// later one with a lower number or an earlier one with a higher number).
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

  /// Applies [renumberPlan]; only touches (and marks Updated on) those that change.
  /// Returns how many changed.
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

  /// Renumbers if automatic numbering is on. Call after creating,
  /// deleting, restoring, merging, importing or changing the date of dives.
  int autoRenumber() => autoNumber ? renumberDives() : 0;

  // Pins the computed first number before a permanent delete or a
  // change can move it.
  void _pinFirstNumber() {
    if (_metaGet(_kFirstNumber) == null) _metaSet(_kFirstNumber, '$firstNumber');
  }
}
