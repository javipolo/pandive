/// Modal dialog with a progress bar for long imports (Subsurface,
/// SSI…). The task must yield the thread now and then (await) so the
/// bar advances and Android doesn't show "app not responding".
library;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/subsurface_import.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Runs [task] with the dialog open; [task] reports (done, total).
/// [title] defaults to "Importing…".
Future<T> withProgressBar<T>(BuildContext context,
    Future<T> Function(void Function(int done, int total) onProgress) task,
    {String? title}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<(int, int)>((0, 0));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        PopScope(canPop: false, child: _ProgressDialog(progress, title)),
  );
  try {
    await WidgetsBinding.instance.endOfFrame; // so it shows before starting
    return await task((d, t) => progress.value = (d, t));
  } finally {
    if (nav.canPop()) nav.pop();
    progress.dispose();
  }
}

/// Imports [xml] (Subsurface) into [db] with a progress bar. Returns how many
/// dives were added.
Future<int> importSsrfWithProgress(
        BuildContext context, DivemateDb db, String xml) =>
    withProgressBar(
        context, (p) => importSubsurfaceXml(db, xml, onProgress: p));

class _ProgressDialog extends StatelessWidget {
  final ValueListenable<(int, int)> progress;
  final String? title;
  const _ProgressDialog(this.progress, this.title);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? AppLocalizations.of(context).importing),
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
