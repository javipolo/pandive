/// Estadísticas agregadas del logbook (del owner).
library;

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
}
