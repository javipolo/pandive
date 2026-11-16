/// Ejes y tooltip del gráfico de perfil (funciones auxiliares de ProfileChart).
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

double niceStep(double range, int target) {
  if (range <= 0) return 1;
  final raw = range / target;
  for (final s in [1, 2, 5, 10, 15, 20, 30, 50, 100]) {
    if (s >= raw) return s.toDouble();
  }
  return 100;
}

AxisTitles depthAxis(BuildContext c, AppLocalizations t, double step) => AxisTitles(
      axisNameSize: 22,
      axisNameWidget: Text(t.axisDepth),
      sideTitles: SideTitles(
        showTitles: true,
        interval: step,
        reservedSize: 40,
        getTitlesWidget: (v, m) =>
            Text((-v).round().toString(), style: Theme.of(c).textTheme.bodySmall),
      ),
    );

AxisTitles tempAxis(double minY, double tLo, double tHi) {
  final span = tHi - tLo;
  final tempStep = (span / 5).ceil().clamp(1, 1000);
  return AxisTitles(
    axisNameSize: 22,
    axisNameWidget: const Text('°C'),
    sideTitles: SideTitles(
      showTitles: true,
      interval: (-minY) * tempStep / span,
      reservedSize: 40,
      getTitlesWidget: (v, m) => Text(
        (tLo + (v - minY) / (-minY) * span).round().toString(),
        style: const TextStyle(color: Colors.red, fontSize: 11),
      ),
    ),
  );
}

AxisTitles timeAxis(BuildContext c, AppLocalizations t, double maxTime) => AxisTitles(
      axisNameSize: 24,
      axisNameWidget: Text(t.axisTime),
      sideTitles: SideTitles(
        showTitles: true,
        interval: niceStep(maxTime, 6),
        reservedSize: 28,
        getTitlesWidget: (v, m) =>
            Text(v.round().toString(), style: Theme.of(c).textTheme.bodySmall),
      ),
    );

LineTouchTooltipData profileTooltip(
  List<double> times,
  List<double> depths,
  List<double> prefix,
  List<double?> temps, {
  List<double> ceiling = const [],
  List<int?> ndl = const [],
  List<int?> tts = const [],
  DiveProfile? extra,
}) {
  return LineTouchTooltipData(
    fitInsideVertically: true,
    fitInsideHorizontally: true,
    getTooltipColor: (_) => Colors.black.withValues(alpha: 0.55),
    getTooltipItems: (spots) => [
      for (final s in spots)
        if (s.barIndex == 0)
          LineTooltipItem(
              _tip(s.spotIndex, times, depths, prefix, temps, ceiling, ndl, tts,
                  extra),
              const TextStyle(color: Colors.white, fontSize: 12))
        else
          null,
    ],
  );
}

String _tip(int i, List<double> times, List<double> depths, List<double> prefix,
    List<double?> temps, List<double> ceiling, List<int?> ndl, List<int?> tts,
    DiveProfile? ex) {
  if (i < 0 || i >= depths.length) return '';
  final avg = prefix[i] / (i + 1);
  final temp = temps.length > i ? temps[i] : null;
  final b = StringBuffer('${times[i].round()} min\n${depths[i].toStringAsFixed(1)} m');
  if (temp != null) b.write('\n${temp.toStringAsFixed(1)} °C');
  b.write('\n∅ ${avg.toStringAsFixed(1)} m');
  if (ceiling.length > i && ceiling[i] > 0) {
    b.write('\nTTS ${tts.length > i ? tts[i] : '?'} min\n⬆ ${ceiling[i].round()} m');
  } else if (ndl.length > i && ndl[i] != null) {
    b.write('\nNDL ${ndl[i]! >= 99 ? '99+' : ndl[i]} min');
  }
  if (ex != null) {
    final p = i < ex.ppo2.length ? ex.ppo2[i] : null;
    final c = i < ex.cns.length ? ex.cns[i] : null;
    final pr = i < ex.pressure.length ? ex.pressure[i] : null;
    final rbt = i < ex.rbt.length ? ex.rbt[i] : null;
    if (p != null) b.write('\nppO₂ ${p.toStringAsFixed(2)}');
    if (c != null) b.write('\nCNS ${c.toStringAsFixed(0)} %');
    if (pr != null) b.write('\n${pr.toStringAsFixed(0)} bar');
    if (rbt != null) b.write('\nRBT $rbt min');
  }
  return b.toString();
}
