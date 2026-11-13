/// Sección de formulario para una botella opcional (litros, O2, presiones).
/// El estado vive en [CylinderInputController] para que el formulario padre lo
/// lea al guardar.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';

class CylinderInputController {
  final size = TextEditingController();
  final o2 = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();

  static double? _d(TextEditingController c) {
    final s = c.text.trim().replaceAll(',', '.');
    return s.isEmpty ? null : double.tryParse(s);
  }

  /// Devuelve la botella si se rellenó algún campo; null si está vacía.
  Cylinder? toCylinder() {
    final s = _d(size), o = _d(o2), ps = _d(start), pe = _d(end);
    if (s == null && o == null && ps == null && pe == null) return null;
    return Cylinder(size: s, o2: o, pressureStart: ps, pressureEnd: pe);
  }

  void dispose() {
    size.dispose();
    o2.dispose();
    start.dispose();
    end.dispose();
  }
}

class CylinderInput extends StatelessWidget {
  final CylinderInputController controller;
  const CylinderInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Botella (opcional)',
            style: Theme.of(context).textTheme.titleMedium),
        Row(children: [
          Expanded(child: LabeledField(controller: c.size, label: 'Litros', number: true)),
          const SizedBox(width: 12),
          Expanded(child: LabeledField(controller: c.o2, label: 'O₂ %', number: true)),
        ]),
        Row(children: [
          Expanded(child: LabeledField(controller: c.start, label: 'Presión ini (bar)', number: true)),
          const SizedBox(width: 12),
          Expanded(child: LabeledField(controller: c.end, label: 'Presión fin (bar)', number: true)),
        ]),
      ],
    );
  }
}
