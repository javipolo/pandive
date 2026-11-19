/// Diálogo modal simple con spinner y mensaje. El llamante lo cierra con
/// Navigator.pop cuando termina la operación.
library;

import 'package:material_ui/material_ui.dart';

void showLoadingDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 20),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
