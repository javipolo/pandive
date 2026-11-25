/// After the next frame, scrolls the list so the widget of [key] becomes
/// visible (e.g. the newly added item).
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
