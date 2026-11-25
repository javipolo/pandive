/// Aggregate logbook statistics (the owner's).
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
  final int? decoDives; // number of dives with deco
  final int? maxTts; // min
  final double? maxCeiling; // m (deeper = larger)
  final double? maxCeilingMinutes; // ceiling time of the dive that had the most
  final DateTime? firstDive;
  final DateTime? lastDive;
  final Map<int, int> divesPerYear; // year -> dive count

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
