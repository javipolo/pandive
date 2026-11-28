/// Access layer for the DiveMate database (.ddb, SQLite).
///
/// Pandive uses the same format as DiveMate (no migration). Opens the file and
/// exposes queries/writes over the subset of columns the app uses.
/// The implementation is split into `part`s: reads, profile, stats and writes.
library;

import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/common.dart';

import 'open/sqlite_open.dart';

import '../models/models.dart';
import '../sac.dart';
import '../text/collate.dart';

part 'db_queries.dart';
part 'db_profile.dart';
part 'db_stats.dart';
part 'db_writes.dart';
part 'db_import.dart';
part 'db_create.dart';
part 'db_helpers.dart';
part 'db_buddies.dart';
part 'db_buddies_merge.dart';
part 'db_trips.dart';
part 'db_ports.dart';
part 'db_sites.dart';
part 'db_tanks.dart';
part 'db_tags.dart';
part 'db_bulk.dart';
part 'db_merge.dart';
part 'db_pending.dart';
part 'db_dive_types.dart';
part 'db_computers.dart';
part 'db_encode.dart';
part 'db_sync.dart';
part 'db_import_ext.dart';
part 'db_documents.dart';
part 'db_meta.dart';
part 'db_numbering.dart';

class DivemateDb {
  final CommonDatabase _db;
  int? _ownerId;

  DivemateDb._(this._db);

  /// Opens an existing .ddb at [path].
  factory DivemateDb.open(String path, {bool readOnly = false}) {
    final db = openSqlite(path, readOnly: readOnly);
    if (!readOnly) {
      _ensureSyncTable(db); // fingerprints per device
      _ensureLastWriteTriggers(db); // UTC last-write stamp
    }
    final inst = DivemateDb._(db);
    // Persist avg depth (exportable) and SAC (own column) where missing.
    if (!readOnly) {
      inst.fillMissingAvgDepth();
      inst.fillMissingTemps();
      inst.fillMissingSac();
    }
    return inst;
  }

  /// Creates a new empty DiveMate database at [path] (with one diver).
  factory DivemateDb.createEmpty(String path) {
    final db = openSqlite(path, create: true);
    _createSchema(db);
    _ensureSyncTable(db);
    _ensureLastWriteTriggers(db);
    return DivemateDb._(db);
  }

  void close() => _db.dispose();

  /// Runs [f] in a transaction (all or nothing). Grouping many writes
  /// like this is much faster: without it each statement does its own commit
  /// to disk. Don't nest (nor call something inside that opens another).
  T inTransaction<T>(T Function() f) {
    _db.execute('BEGIN');
    try {
      final r = f();
      _db.execute('COMMIT');
      return r;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Whether a table exists (Pandive tables aren't in external read-only .ddb files).
  bool _hasTable(String name) => _db
      .select("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", [name])
      .isNotEmpty;

  /// "Owner" DiverID = the profile with the most dives (see owner_id in the CLI).
  /// A .ddb may contain several diver profiles (demo/imports).
  int? get ownerId {
    if (_ownerId != null) return _ownerId;
    final rows = _db.select(
      'SELECT DiverID FROM Logbook GROUP BY DiverID '
      'ORDER BY COUNT(*) DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    return _ownerId = rows.first['DiverID'] as int?;
  }

  /// Checks that the file looks like a valid DiveMate DB.
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
