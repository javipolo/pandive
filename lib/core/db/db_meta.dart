part of 'divemate_db.dart';

// Database "last write" stamp (UTC), to warn when restoring a backup
// older than the current data. Maintained by SQLite triggers on each
// table, so any write counts (the app, imports, or divemate-cli) without
// touching the ~100 write statements. Own table PandiveMeta
// (key/value): DiveMate ignores it.

const _kLastWrite = 'lastWriteUtc';

/// Creates PandiveMeta and one INSERT/UPDATE/DELETE trigger per table (idempotent).
void _ensureLastWriteTriggers(CommonDatabase db) {
  db.execute('CREATE TABLE IF NOT EXISTS PandiveMeta '
      '(Key TEXT PRIMARY KEY, Value TEXT)');
  final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' AND name <> 'PandiveMeta'");
  for (final r in tables) {
    final t = r['name'] as String;
    for (final op in const ['INSERT', 'UPDATE', 'DELETE']) {
      db.execute('CREATE TRIGGER IF NOT EXISTS "pandive_lw_${t}_$op" '
          'AFTER $op ON "$t" BEGIN '
          "INSERT OR REPLACE INTO PandiveMeta (Key, Value) VALUES "
          "('$_kLastWrite', strftime('%Y-%m-%dT%H:%M:%fZ', 'now')); END");
    }
  }
}

extension DivemateDbMeta on DivemateDb {
  /// Stamp exactly as stored (for equality comparison in sync).
  String? get lastWriteRaw {
    if (!_hasTable('PandiveMeta')) return null;
    final r = _db.select(
        'SELECT Value FROM PandiveMeta WHERE Key = ?', [_kLastWrite]);
    return r.isEmpty ? null : r.first['Value'] as String?;
  }

  /// Consistent copy of the open DB at [path] (VACUUM INTO, atomic).
  void snapshotTo(String path) => _db.execute('VACUUM INTO ?', [path]);

  /// Time (UTC) of the last write, or null if the DB predates this
  /// or lacks the table (e.g. a DiveMate .ddb).
  DateTime? get lastWriteUtc => DateTime.tryParse(lastWriteRaw ?? '');

  /// Value stored in PandiveMeta (null if missing or no table).
  String? _metaGet(String key) {
    if (!_hasTable('PandiveMeta')) return null;
    final r = _db.select('SELECT Value FROM PandiveMeta WHERE Key = ?', [key]);
    return r.isEmpty ? null : r.first['Value'] as String?;
  }

  /// Stores a value in PandiveMeta. Doesn't move the stamp (PandiveMeta has no
  /// trigger): if it's a user change, also call [_touchLastWrite].
  void _metaSet(String key, String value) => _db.execute(
      'INSERT OR REPLACE INTO PandiveMeta (Key, Value) VALUES (?, ?)',
      [key, value]);

  /// Marks "written now" by hand (for changes that only touch PandiveMeta).
  void _touchLastWrite() => _db.execute(
      'INSERT OR REPLACE INTO PandiveMeta (Key, Value) VALUES '
      "(?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))", [_kLastWrite]);
}

/// [DivemateDb.lastWriteUtc] of a file (opens read-only).
DateTime? lastWriteUtcOf(String path) {
  try {
    final db = DivemateDb.open(path, readOnly: true);
    try {
      return db.lastWriteUtc;
    } finally {
      db.close();
    }
  } catch (_) {
    return null;
  }
}
