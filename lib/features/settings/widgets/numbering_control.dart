/// Ajustes de numeración de buceos: automática sí/no y primer número. Se
/// guardan en la DB (iguales en todos los dispositivos sincronizados).
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/l10n/app_localizations.dart';

class NumberingControl extends StatefulWidget {
  final DivemateDb db;
  const NumberingControl({super.key, required this.db});

  @override
  State<NumberingControl> createState() => _NumberingControlState();
}

class _NumberingControlState extends State<NumberingControl> {
  DivemateDb get db => widget.db;

  void _done(int n) {
    bumpDataRevision();
    setState(() {});
    if (n > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).renumberResult(n))));
    }
  }

  void _setAuto(bool v) => _done(db.setAutoNumber(v));

  Future<void> _editFirst() async {
    final t = AppLocalizations.of(context);
    final c = TextEditingController(text: '${db.firstNumber}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.firstDiveNumber),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(helperText: t.firstDiveNumberHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
              child: Text(t.save)),
        ],
      ),
    );
    c.dispose();
    if (v == null || v == db.firstNumber || !mounted) return;
    _done(db.setFirstNumber(v));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        SwitchListTile(
          title: Text(t.autoNumbering),
          subtitle: Text(t.autoNumberingHint),
          value: db.autoNumber,
          onChanged: _setAuto,
        ),
        ListTile(
          title: Text(t.firstDiveNumber),
          subtitle: Text(t.firstDiveNumberHint),
          trailing: Text('${db.firstNumber}',
              style: Theme.of(context).textTheme.titleMedium),
          onTap: _editFirst,
        ),
      ],
    );
  }
}
