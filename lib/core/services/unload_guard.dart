/// Web: asks before closing/reloading the page while [hasPending] is true
/// (changes not on Drive yet). No-op on native platforms.
library;

export 'unload_guard_stub.dart' if (dart.library.js_interop) 'unload_guard_web.dart';
