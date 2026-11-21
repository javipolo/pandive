/// Tras el siguiente frame, desplaza la lista para que el widget de [key] quede
/// visible (p.ej. el elemento recién añadido).
library;

import 'package:material_ui/material_ui.dart';

void scrollToHighlight(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    }
  });
}
