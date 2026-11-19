/// Cambios de gas a lo largo del buceo (para la gráfica ampliada): marca el
/// minuto del cambio con la etiqueta de la mezcla y un color.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';

class GasChange {
  final double timeMin;
  final String label;
  final Color color;
  const GasChange(this.timeMin, this.label, this.color);
}

const _palette = [
  Color(0xFF1565C0), // azul (aire)
  Color(0xFF2E7D32), // verde
  Color(0xFFEF6C00), // naranja
  Color(0xFF6A1B9A), // morado
  Color(0xFF00838F), // teal
];

Color gasColor(int index) => _palette[index % _palette.length];

String _label(List<Cylinder> cyls, int idx) {
  final gas = (idx >= 0 && idx < cyls.length) ? cyls[idx].gasLabel : 'Gas ${idx + 1}';
  final size = (idx >= 0 && idx < cyls.length) ? cyls[idx].size : null;
  return size != null ? '${size.toStringAsFixed(0)}L $gas' : gas;
}

/// Líneas verticales (fl_chart) para marcar los cambios de gas.
List<VerticalLine> gasVerticalLines(List<GasChange> changes) => [
      for (final gc in changes)
        VerticalLine(
          x: gc.timeMin,
          color: gc.color,
          strokeWidth: 1.5,
          dashArray: const [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: TextStyle(color: gc.color, fontSize: 10),
            labelResolver: (_) => gc.label,
          ),
        ),
    ];

/// Lista de cambios de gas a partir del índice por muestra. Vacía si no hay.
List<GasChange> buildGasChanges(
    List<int?>? perSample, List<double> timesMin, List<Cylinder> cyls) {
  if (perSample == null) return const [];
  final out = <GasChange>[];
  int? prev;
  for (var i = 0; i < perSample.length && i < timesMin.length; i++) {
    final g = perSample[i];
    if (g != null && g != prev) {
      out.add(GasChange(timesMin[i], _label(cyls, g), gasColor(g)));
      prev = g;
    }
  }
  return out;
}
