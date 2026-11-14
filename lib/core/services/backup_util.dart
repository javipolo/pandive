/// Utilidades puras (testeables) de nombres/poda de backups en Drive.
library;

const latestBackupName = 'latest.ddb';

String _p2(int v) => v.toString().padLeft(2, '0');

/// Nombre con timestamp local: pandive-YYYYMMDD-HHMMSS.ddb
String backupFileName(DateTime t) =>
    'pandive-${t.year}${_p2(t.month)}${_p2(t.day)}-'
    '${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}.ddb';

/// ¿Es una copia con timestamp (no la "latest")?
bool isTimestampedBackup(String name) =>
    name.startsWith('pandive-') && name.endsWith('.ddb');

/// Dada una lista de copias con timestamp (id + fecha), devuelve los ids a
/// borrar para conservar solo las [keep] más recientes.
List<String> idsToPrune(List<(String id, DateTime when)> items,
    {int keep = 10}) {
  final sorted = [...items]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (var i = keep; i < sorted.length; i++) sorted[i].$1];
}
