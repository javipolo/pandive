/// Opens a SQLite file on the current platform: native (FFI) on Android and
/// Linux, WASM in the browser. The rest of the data layer only sees
/// [CommonDatabase], so it compiles for both. The file helpers (read/write/
/// delete, temp path) work on disk natively and in memory on web.
library;

export 'sqlite_open_io.dart' if (dart.library.js_interop) 'sqlite_open_web.dart';
