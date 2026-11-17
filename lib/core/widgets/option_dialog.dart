/// Diálogo de confirmación con una casilla opcional. Devuelve null si se
/// cancela, o el valor de la casilla si se confirma.
library;

import 'package:flutter/material.dart';

import 'package:pandive/l10n/app_localizations.dart';

Future<bool?> showOptionDialog(
  BuildContext context, {
  required String title,
  required String checkboxLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _OptionDialog(title: title, checkboxLabel: checkboxLabel),
  );
}

class _OptionDialog extends StatefulWidget {
  final String title;
  final String checkboxLabel;
  const _OptionDialog({required this.title, required this.checkboxLabel});

  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _checked,
        onChanged: (v) => setState(() => _checked = v ?? false),
        title: Text(widget.checkboxLabel),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _checked),
            child: Text(t.confirm)),
      ],
    );
  }
}
