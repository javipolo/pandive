/// Utilidades puras (testeables) de nombres/poda de backups en Drive.
library;

const latestBackupName = 'latest.ddb';
const documentsBackupName = 'documents-latest.zip';

String _p2(int v) => v.toString().padLeft(2, '0');

/// Nombre con timestamp local: pandive-YYYYMMDD-HHMMSS.ddb
String backupFileName(DateTime t) =>
    'pandive-${t.year}${_p2(t.month)}${_p2(t.day)}-'
    '${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}.ddb';

/// ¿Restaurar un backup con sello [backup] pisaría datos más nuevos que los
/// locales ([local])? Sin sello local no se sabe: no avisa. Backup sin sello
/// (anterior a la función) y local con sello: casi seguro más viejo, avisa.
bool restoreWouldLoseData(DateTime? local, DateTime? backup) =>
    local != null && (backup == null || local.isAfter(backup));

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
