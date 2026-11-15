/// Piezas de presentación del detalle de buceo: celda etiqueta/valor compacta,
/// fila de dos columnas y separador de sección.
library;

import 'package:flutter/material.dart';

class LabeledValue extends StatelessWidget {
  final String label;
  final String? value;
  const LabeledValue(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          Text((value != null && value!.isNotEmpty) ? value! : '—',
              style: tt.titleMedium),
        ],
      ),
    );
  }
}

/// Dos columnas alineadas (izquierda | derecha).
Widget twoCol(Widget? a, Widget? b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a ?? const SizedBox()),
        const SizedBox(width: 16),
        Expanded(child: b ?? const SizedBox()),
      ],
    );

Widget sectionLine() => const Divider(height: 20, thickness: 0.6);
