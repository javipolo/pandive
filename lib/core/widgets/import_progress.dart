/// Diálogo de progreso reutilizable para importar un .ssrf en una base de datos.
library;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/subsurface_import.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Muestra un diálogo de progreso mientras importa [xml] en [db]. Devuelve el
/// número de inmersiones añadidas.
Future<int> importSsrfWithProgress(
    BuildContext context, DivemateDb db, String xml) async {
  final progress = ValueNotifier<(int, int)>((0, 0));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportProgressDialog(progress),
  );
  final n = await importSubsurfaceXml(db, xml,
      onProgress: (d, t) => progress.value = (d, t));
  if (context.mounted) Navigator.of(context).pop();
  progress.dispose();
  return n;
}

class _ImportProgressDialog extends StatelessWidget {
  final ValueListenable<(int, int)> progress;
  const _ImportProgressDialog(this.progress);

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
