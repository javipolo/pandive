/// Agrupa fechas de inmersión por año/mes/semana (ISO). Pure y testeable.
library;

enum StatsPeriod { year, month, week }

String _p2(int v) => v.toString().padLeft(2, '0');

/// Número de semana ISO-8601 (y su año ISO) de una fecha.
(int isoYear, int week) isoWeek(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final thursday = d.add(Duration(days: 4 - d.weekday)); // lun=1..dom=7
  final firstDay = DateTime.utc(thursday.year, 1, 1);
  final week = 1 + thursday.difference(firstDay).inDays ~/ 7;
  return (thursday.year, week);
}

String periodKey(DateTime d, StatsPeriod p) {
  switch (p) {
    case StatsPeriod.year:
      return '${d.year}';
    case StatsPeriod.month:
      return '${_p2(d.year % 100)}-${_p2(d.month)}'; // año corto: 26-01
    case StatsPeriod.week:
      final (y, w) = isoWeek(d);
      return '${_p2(y % 100)}-W${_p2(w)}'; // 26-W05
  }
}

/// Conteos ordenados por clave ascendente para el periodo [p].
List<(String, int)> bucketByPeriod(List<DateTime> dates, StatsPeriod p) {
  final map = <String, int>{};
  for (final d in dates) {
    final k = periodKey(d, p);
    map[k] = (map[k] ?? 0) + 1;
  }
  final keys = map.keys.toList()..sort();
  return [for (final k in keys) (k, map[k]!)];
}
