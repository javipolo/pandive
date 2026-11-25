/// Runs [task] showing a modal (non-cancellable) progress dialog and
/// closes it when done. For slow operations (export/import .ddb).
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
    // Let the dialog get painted before starting (if the task is
    // synchronous, it blocks the thread and without this nothing would show).
    await WidgetsBinding.instance.endOfFrame;
    return await task();
  } finally {
    if (nav.canPop()) nav.pop();
  }
}
