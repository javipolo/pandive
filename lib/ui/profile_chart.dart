/// Gráfico del perfil de profundidad de una inmersión (superficie arriba).
/// La temperatura se muestra como línea secundaria normalizada cuando existe.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';

class ProfileChart extends StatelessWidget {
  final DiveProfile profile;
  const ProfileChart({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) {
      return const Center(child: Text('Sin perfil registrado'));
    }
    final cs = Theme.of(context).colorScheme;
    final times = profile.timesMinutes;
    final depths = profile.depths;
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    final maxTime = times.isNotEmpty ? times.last : 1.0;

    // Profundidad: se dibuja negada para que 0 (superficie) quede arriba.
    final depthSpots = [
      for (var i = 0; i < depths.length; i++) FlSpot(times[i], -depths[i]),
    ];

    // Temperatura normalizada al rango del eje (solo visual, línea de apoyo).
    List<FlSpot>? tempSpots;
    double? tMin, tMax;
    if (profile.hasTemp) {
      final ts = profile.temps.whereType<double>();
      tMin = ts.reduce((a, b) => a < b ? a : b);
      tMax = ts.reduce((a, b) => a > b ? a : b);
      final span = (tMax - tMin).abs() < 0.1 ? 1.0 : (tMax - tMin);
      tempSpots = [
        for (var i = 0; i < profile.temps.length; i++)
          if (profile.temps[i] != null)
            FlSpot(times[i], -maxDepth * (1 - (profile.temps[i]! - tMin) / span)),
      ];
    }

    final depthStep = _niceStep(maxDepth, 5);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxTime,
        minY: -(((maxDepth / depthStep).ceil()) * depthStep),
        maxY: 0,
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: depthStep,
          verticalInterval: _niceStep(maxTime, 6),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              FlLine(color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('prof (m)'),
            sideTitles: SideTitles(
              showTitles: true,
              interval: depthStep,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                (-value).round().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('tiempo (min)'),
            sideTitles: SideTitles(
              showTitles: true,
              interval: _niceStep(maxTime, 6),
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: cs.outlineVariant),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: depthSpots,
            isCurved: false,
            color: cs.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.15),
            ),
          ),
          if (tempSpots != null)
            LineChartBarData(
              spots: tempSpots,
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 1.5,
              dashArray: [4, 3],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  static double _niceStep(double range, int target) {
    if (range <= 0) return 1;
    final raw = range / target;
    final mag = raw <= 0 ? 1 : raw;
    for (final s in [1, 2, 5, 10, 15, 20, 30, 50, 100]) {
      if (s >= mag) return s.toDouble();
    }
    return 100;
  }
}
