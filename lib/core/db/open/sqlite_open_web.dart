/// Browser SQLite (WASM): files live in an in-memory file system, so they
/// are gone on reload. The page loads `sqlite3.wasm` from `web/`.
library;

import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';

WasmSqlite3? _sqlite;
final _fs = InMemoryFileSystem();

/// Loads the WASM module once (call before opening anything).
Future<void> initSqlite() async {
  if (_sqlite != null) return;
  final s = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  s.registerVirtualFileSystem(_fs, makeDefault: true);
  _sqlite = s;
}

WasmSqlite3 get _s =>
    _sqlite ?? (throw StateError('initSqlite() was not called'));

/// Opens [path] in the in-memory file system.
CommonDatabase openSqlite(String path,
    {bool readOnly = false, bool create = false}) {
  if (!create && !_fs.fileData.containsKey(path)) {
    throw StateError('No such file: $path');
  }
  return _s.open(
    path,
    mode: create
        ? OpenMode.readWriteCreate
        : (readOnly ? OpenMode.readOnly : OpenMode.readWrite),
  );
}

/// Stores [bytes] as the file [path] (e.g. a .ddb picked by the user).
void putMemoryFile(String path, Uint8List bytes) {
  _fs.fileData[path] = Uint8Buffer()..addAll(bytes);
}
