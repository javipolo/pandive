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
    // Que el diálogo llegue a pintarse antes de empezar (si la tarea es
    // síncrona, bloquea el hilo y sin esto no se vería nada).
    await WidgetsBinding.instance.endOfFrame;
    return await task();
  } finally {
    if (nav.canPop()) nav.pop();
  }
}
