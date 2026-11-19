/// Diálogo con un campo de texto. Devuelve el texto (recortado) o null si se
/// cancela.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

Future<String?> showTextPrompt(BuildContext context,
    {required String title, String? hint, String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  final t = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(t.confirm)),
      ],
    ),
  );
}
