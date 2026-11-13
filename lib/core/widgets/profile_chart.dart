/// Perfil de inmersión: profundidad (azul, superficie arriba) + temperatura
/// (roja, eje derecho). Al tocar, línea vertical y valores en ese punto.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart_axes.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ProfileChart extends StatelessWidget {
  final DiveProfile profile;
  const ProfileChart({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (profile.isEmpty) return Center(child: Text(t.noProfile));
    final cs = Theme.of(context).colorScheme;
    final times = profile.timesMinutes;
    final depths = profile.depths;
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    final maxTime = times.isNotEmpty ? times.last : 1.0;
    final depthStep = niceStep(maxDepth, 5);
    final minY = -(((maxDepth / depthStep).ceil()) * depthStep).toDouble();
    const maxY = 0.0;

    final prefix = <double>[];
    var acc = 0.0;
    for (final d in depths) {
      acc += d;
      prefix.add(acc);
    }

    final depthSpots = [
      for (var i = 0; i < depths.length; i++) FlSpot(times[i], -depths[i]),
    ];

    // Temperatura: rango con mínimo 5° entre arriba y abajo.
    final hasTemp = profile.hasTemp;
    var tLo = 0.0, tHi = 5.0;
    List<FlSpot> tempSpots = [];
    if (hasTemp) {
      final ts = profile.temps.whereType<double>();
      tLo = ts.reduce((a, b) => a < b ? a : b).floorToDouble();
      tHi = ts.reduce((a, b) => a > b ? a : b).ceilToDouble();
      if (tHi - tLo < 5) {
        tLo = ((tHi + tLo) / 2 - 2.5).floorToDouble();
        tHi = tLo + 5;
      }
      double tempY(double v) => minY + (v - tLo) / (tHi - tLo) * (maxY - minY);
      tempSpots = [
        for (var i = 0; i < profile.temps.length; i++)
          if (profile.temps[i] != null)
            FlSpot(times[i], tempY(profile.temps[i]!)),
      ];
    }

    return LineChart(LineChartData(
      minX: 0,
      maxX: maxTime,
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.all(),
      lineTouchData: profileTouch(context, times, depths, prefix, profile.temps),
      gridData: FlGridData(
        show: true,
        horizontalInterval: depthStep,
        verticalInterval: niceStep(maxTime, 6),
        getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
        getDrawingVerticalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: depthAxis(context, t, depthStep),
        rightTitles: hasTemp
            ? tempAxis(minY, tLo, tHi)
            : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: timeAxis(context, t, maxTime),
      ),
      borderData:
          FlBorderData(show: true, border: Border.all(color: cs.outlineVariant)),
      lineBarsData: [
        LineChartBarData(
          spots: depthSpots,
          isCurved: false,
          color: cs.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          aboveBarData:
              BarAreaData(show: true, color: cs.primary.withValues(alpha: 0.28)),
        ),
        if (hasTemp)
          LineChartBarData(
            spots: tempSpots,
            isCurved: false,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
      ],
    ));
  }
}
