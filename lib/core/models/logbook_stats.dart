/// Estadísticas agregadas del logbook (del owner).
library;

import 'dive.dart';

class LogbookStats {
  final int totalDives;
  final int? buddiesCount;
  final double totalMinutes;
  final double? maxDiveMinutes;
  final double? avgDiveMinutes;
  final double? maxDepth; // MAX(Depth)
  final double? avgDepth; // AVG(DepthAvg)
  final double? sacMax; // l/min
  final double? sacMin;
  final double? sacAvg;
  final double? tempMax;
  final double? tempMin;
  final double? avgWaterTemp;
  final int? decoDives; // nº buceos con deco
  final int? maxTts; // min
  final double? maxCeiling; // m (más profundo = mayor)
  final double? maxCeilingMinutes; // tiempo con techo del buceo que más tuvo
  final DateTime? firstDive;
  final DateTime? lastDive;
  final Map<int, int> divesPerYear; // año -> nº inmersiones

  const LogbookStats({
    required this.totalDives,
    this.buddiesCount,
    required this.totalMinutes,
    this.maxDiveMinutes,
    this.avgDiveMinutes,
    this.maxDepth,
    this.avgDepth,
    this.sacMax,
    this.sacMin,
    this.sacAvg,
    this.tempMax,
    this.tempMin,
    this.avgWaterTemp,
    this.decoDives,
    this.maxTts,
    this.maxCeiling,
    this.maxCeilingMinutes,
    this.firstDive,
    this.lastDive,
    this.divesPerYear = const {},
  });

  double get totalHours => totalMinutes / 60.0;

  /// Estadísticas calculadas a partir de una lista concreta de inmersiones
  /// (p.ej. una selección), sin tocar la base de datos.
  factory LogbookStats.fromDives(List<Dive> dives) {
    double sumMin = 0;
    final durations = <double>[];
    final depths = <double>[];
    final temps = <double>[];
    double? maxD;
    int deco = 0;
    DateTime? first, last;
    final perYear = <int, int>{};
    for (final d in dives) {
      if (d.deco == 1) deco++;
      if (d.durationMin != null) {
        sumMin += d.durationMin!;
        durations.add(d.durationMin!);
      }
      if (d.maxDepth != null) {
        maxD = (maxD == null || d.maxDepth! > maxD) ? d.maxDepth : maxD;
      }
      if (d.avgDepth != null && d.avgDepth! > 0) depths.add(d.avgDepth!);
      if (d.waterTemp != null) temps.add(d.waterTemp!);
      final dt = d.date;
      if (dt != null) {
        if (first == null || dt.isBefore(first)) first = dt;
        if (last == null || dt.isAfter(last)) last = dt;
        perYear[dt.year] = (perYear[dt.year] ?? 0) + 1;
      }
    }
    double? avg(List<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    double? maxOf(List<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a > b ? a : b);
    double? minOf(List<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a < b ? a : b);
    return LogbookStats(
      totalDives: dives.length,
      totalMinutes: sumMin,
      maxDiveMinutes: maxOf(durations),
      avgDiveMinutes: avg(durations),
      maxDepth: maxD,
      avgDepth: avg(depths),
      tempMax: maxOf(temps),
      tempMin: minOf(temps),
      avgWaterTemp: avg(temps),
      decoDives: deco,
      firstDive: first,
      lastDive: last,
      divesPerYear: perYear,
    );
  }
}
