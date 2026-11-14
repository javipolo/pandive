/// Diálogo de confirmación reutilizable (Sí/No). Devuelve true si se confirma.
library;

import 'package:flutter/material.dart';

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
