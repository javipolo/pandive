/// Capa de acceso a la base de datos DiveMate (.ddb, SQLite).
///
/// Pandive usa el mismo formato que DiveMate (sin migración). Abre el fichero y
/// expone consultas/escrituras sobre el subconjunto de columnas que usa la app.
/// La implementación se reparte en `part`s: lecturas, perfil, stats y escritura.
library;

import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../models/models.dart';
import '../text/collate.dart';

part 'db_queries.dart';
part 'db_profile.dart';
part 'db_stats.dart';
part 'db_writes.dart';
part 'db_import.dart';
part 'db_create.dart';
part 'db_helpers.dart';
part 'db_buddies.dart';
part 'db_sites.dart';
part 'db_tanks.dart';
part 'db_tags.dart';
part 'db_merge.dart';
part 'db_pending.dart';
part 'db_dive_types.dart';
part 'db_computers.dart';

class DivemateDb {
  final Database _db;
  int? _ownerId;

  DivemateDb._(this._db);

  /// Abre una .ddb existente en [path].
  factory DivemateDb.open(String path, {bool readOnly = false}) {
    final db = sqlite3.open(
      path,
      mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite,
    );
    if (!readOnly) _ensureSyncTable(db); // fingerprints por dispositivo
    final inst = DivemateDb._(db);
    // Persistir prof. media calculada del perfil donde falte (exportable).
    if (!readOnly) inst.fillMissingAvgDepth();
    return inst;
  }

  /// Crea una base de datos DiveMate vacía nueva en [path] (con un buceador).
  factory DivemateDb.createEmpty(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readWriteCreate);
    _createSchema(db);
    _ensureSyncTable(db);
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
}
