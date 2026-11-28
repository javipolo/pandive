/// Browser `beforeunload`: the browser shows its own "leave site?" prompt
/// (custom text isn't allowed) while there are unsynced changes.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

void installUnloadGuard(bool Function() hasPending) {
  web.window.addEventListener(
      'beforeunload',
      ((web.Event e) {
        if (!hasPending()) return;
        e.preventDefault();
        (e as web.BeforeUnloadEvent).returnValue = '';
      }).toJS);
}
