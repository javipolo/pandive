/// Native SQLite (FFI): opens a real file on disk.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// Nothing to load on native platforms.
Future<void> initSqlite() async {}

/// Opens [path] on disk (read-only, read-write or creating it).
CommonDatabase openSqlite(String path,
    {bool readOnly = false, bool create = false}) {
  return sqlite3.open(
    path,
    mode: create
        ? OpenMode.readWriteCreate
        : (readOnly ? OpenMode.readOnly : OpenMode.readWrite),
  );
}

/// Path for a scratch database file (system temp dir).
String tempDbPath(String name) => '${Directory.systemTemp.path}/$name';

/// Whole content of the database file at [path].
Future<Uint8List> readDbFile(String path) => File(path).readAsBytes();

/// Writes [bytes] as the database file [path] (replacing it).
Future<void> writeDbFile(String path, List<int> bytes) =>
    File(path).writeAsBytes(bytes, flush: true);

Future<void> deleteDbFile(String path) async {
  final f = File(path);
  if (await f.exists()) await f.delete();
}
