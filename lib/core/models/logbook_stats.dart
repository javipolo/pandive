/// Estadísticas agregadas del logbook (del owner).
library;

class LogbookStats {
  final int totalDives;
  final double totalMinutes;
  final double? avgDiveMinutes;
  final double? maxDepth; // MAX(Depth)
  final double? avgDepth; // AVG(DepthAvg)
  final double? avgWaterTemp;
  final DateTime? firstDive;
  final DateTime? lastDive;
  final Map<int, int> divesPerYear; // año -> nº inmersiones

  const LogbookStats({
    required this.totalDives,
    required this.totalMinutes,
    this.avgDiveMinutes,
    this.maxDepth,
    this.avgDepth,
    this.avgWaterTemp,
    this.firstDive,
    this.lastDive,
    this.divesPerYear = const {},
  });

  double get totalHours => totalMinutes / 60.0;
}
