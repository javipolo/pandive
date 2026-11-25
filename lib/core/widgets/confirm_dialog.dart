/// Reusable confirmation dialog (Yes/No). Returns true if confirmed.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

Future<bool> confirmDialog(
  BuildContext context,
  String message, {
  String? confirmLabel,
}) async {
  final t = AppLocalizations.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel ?? t.confirm)),
      ],
    ),
  );
  return r ?? false;
}
