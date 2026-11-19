/// Diálogo simple de un campo de texto (nombre). Devuelve el texto o null.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

Future<String?> nameDialog(
  BuildContext context,
  String title, {
  String initial = '',
  String? confirmLabel,
}) {
  final c = TextEditingController(text: initial);
  final t = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(labelText: t.name),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(confirmLabel ?? t.save)),
      ],
    ),
  );
}
