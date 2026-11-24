/// Diálogo modal con barra de progreso para importaciones largas (Subsurface,
/// SSI…). La tarea debe ceder el hilo de vez en cuando (await) para que la
/// barra avance y Android no muestre "la app no responde".
library;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/subsurface_import.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Ejecuta [task] con el diálogo abierto; [task] informa con (hechas, total).
Future<T> withProgressBar<T>(BuildContext context,
    Future<T> Function(void Function(int done, int total) onProgress) task) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<(int, int)>((0, 0));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: _ProgressDialog(progress)),
  );
  try {
    await WidgetsBinding.instance.endOfFrame; // que se vea antes de empezar
    return await task((d, t) => progress.value = (d, t));
  } finally {
    if (nav.canPop()) nav.pop();
    progress.dispose();
  }
}

/// Importa [xml] (Subsurface) en [db] con barra de progreso. Devuelve cuántas
/// inmersiones añadió.
Future<int> importSsrfWithProgress(
        BuildContext context, DivemateDb db, String xml) =>
    withProgressBar(
        context, (p) => importSubsurfaceXml(db, xml, onProgress: p));

class _ProgressDialog extends StatelessWidget {
  final ValueListenable<(int, int)> progress;
  const _ProgressDialog(this.progress);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).importing),
      content: ValueListenableBuilder<(int, int)>(
        valueListenable: progress,
        builder: (context, v, _) {
          final (done, total) = v;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: total > 0 ? done / total : null),
              const SizedBox(height: 12),
              Text(total > 0 ? '$done / $total' : '…'),
            ],
          );
        },
      ),
    );
  }
}
