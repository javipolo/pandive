/// Native SQLite (FFI): opens a real file on disk.
library;

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

/// Only meaningful in the browser (in-memory files): unsupported here.
void putMemoryFile(String path, Uint8List bytes) =>
    throw UnsupportedError('putMemoryFile is web only');
