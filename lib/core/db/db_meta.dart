part of 'divemate_db.dart';

// Sello de "última escritura" (UTC) de la base de datos, para avisar al
// restaurar un backup más viejo que los datos actuales. Lo mantienen triggers
// de SQLite en cada tabla, así cuenta cualquier escritura (la app, imports, o
// divemate-cli) sin tocar las ~100 sentencias de escritura. Tabla propia
// PandiveMeta (clave/valor): DiveMate la ignora.

const _kLastWrite = 'lastWriteUtc';

/// Crea PandiveMeta y un trigger INSERT/UPDATE/DELETE por tabla (idempotente).
void _ensureLastWriteTriggers(Database db) {
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
  /// Sello tal cual está guardado (para comparar por igualdad en la sync).
  String? get lastWriteRaw {
    if (!_hasTable('PandiveMeta')) return null;
    final r = _db.select(
        'SELECT Value FROM PandiveMeta WHERE Key = ?', [_kLastWrite]);
    return r.isEmpty ? null : r.first['Value'] as String?;
  }

  /// Copia consistente de la DB abierta en [path] (VACUUM INTO, atómico).
  void snapshotTo(String path) => _db.execute('VACUUM INTO ?', [path]);

  /// Momento (UTC) de la última escritura, o null si la DB es anterior a esto
  /// o no tiene la tabla (p.ej. un .ddb de DiveMate).
  DateTime? get lastWriteUtc => DateTime.tryParse(lastWriteRaw ?? '');

  /// Valor guardado en PandiveMeta (null si no existe o no hay tabla).
  String? _metaGet(String key) {
    if (!_hasTable('PandiveMeta')) return null;
    final r = _db.select('SELECT Value FROM PandiveMeta WHERE Key = ?', [key]);
    return r.isEmpty ? null : r.first['Value'] as String?;
  }

  /// Guarda un valor en PandiveMeta. No mueve el sello (PandiveMeta no tiene
  /// trigger): si es un cambio del usuario, llama también a [_touchLastWrite].
  void _metaSet(String key, String value) => _db.execute(
      'INSERT OR REPLACE INTO PandiveMeta (Key, Value) VALUES (?, ?)',
      [key, value]);

  /// Marca "escrito ahora" a mano (para cambios que solo tocan PandiveMeta).
  void _touchLastWrite() => _db.execute(
      'INSERT OR REPLACE INTO PandiveMeta (Key, Value) VALUES '
      "(?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))", [_kLastWrite]);
}

/// [DivemateDb.lastWriteUtc] de un fichero (abre en solo lectura).
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
