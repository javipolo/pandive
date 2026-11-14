/// Hoja modal para añadir/editar una botella: nombre (izquierda, deco…), litros,
/// material y, salvo en modo [template], presiones y gas. En plantillas de tipo
/// de buceo no se piden presiones (antes del buceo no se conocen).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<Cylinder?> showTankEditSheet(
  BuildContext context, {
  Cylinder? initial,
  required List<TankPreset> presets,
  bool template = false,
}) {
  return showModalBottomSheet<Cylinder>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _TankSheet(initial: initial, presets: presets, template: template),
    ),
  );
}

class _TankSheet extends StatefulWidget {
  final Cylinder? initial;
  final List<TankPreset> presets;
  final bool template;
  const _TankSheet(
      {this.initial, required this.presets, this.template = false});

  @override
  State<_TankSheet> createState() => _TankSheetState();
}

class _TankSheetState extends State<_TankSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
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
  String? _s(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  void dispose() {
    for (final c in [_name, _litres, _presIn, _presOut, _o2, _he]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      Cylinder(
        name: _s(_name),
        size: _d(_litres),
        pressureStart: widget.template ? null : _d(_presIn),
        pressureEnd: widget.template ? null : _d(_presOut),
        o2: widget.template ? null : _d(_o2),
        he: widget.template ? null : _d(_he),
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
                  labelText: t.tankTypes, border: const OutlineInputBorder()),
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
                  if (_name.text.trim().isEmpty) _name.text = p.name;
                  _litres.text = '${p.litres}';
                  _material = p.material;
                });
              },
            ),
          ),
        LabeledField(controller: _name, label: t.tankName),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LabeledField(controller: _litres, label: t.liters, number: true)),
          const SizedBox(width: 12),
          Expanded(child: _materialToggle(t)),
        ]),
        if (!widget.template) ...[
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
        ],
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
