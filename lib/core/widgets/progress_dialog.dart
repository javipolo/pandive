/// Ejecuta [task] mostrando un diálogo de progreso modal (no cancelable) y lo
/// cierra al terminar. Para operaciones que tardan (exportar/importar .ddb).
library;

import 'package:material_ui/material_ui.dart';

Future<T> withProgress<T>(
    BuildContext context, String label, Future<T> Function() task) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  try {
    await Future<void>.delayed(Duration.zero); // deja pintar el diálogo
    return await task();
  } finally {
    if (nav.canPop()) nav.pop();
  }
}
