/// Hoja modal para añadir/editar una botella (litros, material, presiones, gas).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<Cylinder?> showTankEditSheet(
  BuildContext context, {
  Cylinder? initial,
  required List<TankPreset> presets,
}) {
  return showModalBottomSheet<Cylinder>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TankSheet(initial: initial, presets: presets),
    ),
  );
}

class _TankSheet extends StatefulWidget {
  final Cylinder? initial;
  final List<TankPreset> presets;
  const _TankSheet({this.initial, required this.presets});

  @override
  State<_TankSheet> createState() => _TankSheetState();
}

class _TankSheetState extends State<_TankSheet> {
  late final _litres = _ctrl(widget.initial?.size);
  late final _presIn = _ctrl(widget.initial?.pressureStart);
  late final _presOut = _ctrl(widget.initial?.pressureEnd);
  late final _o2 = _ctrl(widget.initial?.o2);
  late final _he = _ctrl(widget.initial?.he);
  late TankMaterial _material =
      widget.initial?.material ?? TankMaterial.aluminium;

  TextEditingController _ctrl(double? v) =>
      TextEditingController(text: v == null ? '' : '$v');

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_litres, _presIn, _presOut, _o2, _he]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      Cylinder(
        size: _d(_litres),
        pressureStart: _d(_presIn),
        pressureEnd: _d(_presOut),
        o2: _d(_o2),
        he: _d(_he),
        material: _material,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shrinkWrap: true,
      children: [
        if (widget.presets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<TankPreset>(
              decoration: InputDecoration(
                  labelText: t.myTanks, border: const OutlineInputBorder()),
              items: [
                for (final p in widget.presets)
                  DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} · ${p.litres.toStringAsFixed(0)} L'),
                  ),
              ],
              onChanged: (p) {
                if (p == null) return;
                setState(() {
                  _litres.text = '${p.litres}';
                  _material = p.material;
                });
              },
            ),
          ),
        Row(children: [
          Expanded(child: LabeledField(controller: _litres, label: t.liters, number: true)),
          const SizedBox(width: 12),
          Expanded(child: _materialToggle(t)),
        ]),
        Row(children: [
          Expanded(child: LabeledField(controller: _presIn, label: t.pressureIn, number: true)),
          const SizedBox(width: 12),
          Expanded(child: LabeledField(controller: _presOut, label: t.pressureOut, number: true)),
        ]),
        Row(children: [
          Expanded(child: LabeledField(controller: _o2, label: t.o2pct, number: true)),
          const SizedBox(width: 12),
          Expanded(child: LabeledField(controller: _he, label: t.heLabel, number: true)),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: Text(t.save)),
      ],
    );
  }

  Widget _materialToggle(AppLocalizations t) {
    return SegmentedButton<TankMaterial>(
      segments: [
        ButtonSegment(value: TankMaterial.aluminium, label: Text(t.aluminium)),
        ButtonSegment(value: TankMaterial.steel, label: Text(t.steel)),
      ],
      selected: {_material},
      onSelectionChanged: (s) => setState(() => _material = s.first),
    );
  }
}
