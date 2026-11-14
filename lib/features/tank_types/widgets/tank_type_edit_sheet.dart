/// Hoja para crear/editar un tipo de botella: nombre, litros y material.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

typedef TankTypeData = ({String name, double litres, TankMaterial material});

Future<TankTypeData?> showTankTypeSheet(BuildContext context,
    {TankPreset? initial}) {
  return showModalBottomSheet<TankTypeData>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Sheet(initial: initial),
    ),
  );
}

class _Sheet extends StatefulWidget {
  final TankPreset? initial;
  const _Sheet({this.initial});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _litres = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial!.litres}');
  late TankMaterial _material =
      widget.initial?.material ?? TankMaterial.aluminium;

  @override
  void dispose() {
    _name.dispose();
    _litres.dispose();
    super.dispose();
  }

  void _save() {
    final litres =
        double.tryParse(_litres.text.trim().replaceAll(',', '.')) ?? 0;
    if (_name.text.trim().isEmpty || litres <= 0) return;
    Navigator.pop(context,
        (name: _name.text.trim(), litres: litres, material: _material));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shrinkWrap: true,
      children: [
        LabeledField(controller: _name, label: t.name),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: LabeledField(
                  controller: _litres, label: t.liters, number: true)),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<TankMaterial>(
              segments: [
                ButtonSegment(
                    value: TankMaterial.aluminium, label: Text(t.aluminium)),
                ButtonSegment(value: TankMaterial.steel, label: Text(t.steel)),
              ],
              selected: {_material},
              onSelectionChanged: (s) => setState(() => _material = s.first),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: Text(t.save)),
      ],
    );
  }
}
