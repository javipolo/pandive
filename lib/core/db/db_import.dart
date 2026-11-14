part of 'divemate_db.dart';

/// Crea la tabla de sincronización (fingerprints por dispositivo) si falta.
/// Específica de Pandive; divemate-cli la ignora.
void _ensureSyncTable(Database db) {
  db.execute('CREATE TABLE IF NOT EXISTS PandiveSync '
      '(DeviceId TEXT PRIMARY KEY, Fingerprint TEXT, Updated TEXT)');
  // "Mis botellas": presets reutilizables de tamaño + material.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveTankPreset '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Litres REAL, '
      'Material INTEGER)');
  // Etiquetas (tags) reutilizables + enlace por inmersión.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveTag '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT)');
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveTag '
      '(DiveId INTEGER, TagId INTEGER, PRIMARY KEY (DiveId, TagId))');
  // Caché de buceos descargados no guardados (reaparecen "una vez más").
  db.execute('CREATE TABLE IF NOT EXISTS PandivePending '
      '(DeviceId TEXT, Fingerprint TEXT, Json TEXT, Updated TEXT, '
      'PRIMARY KEY (DeviceId, Fingerprint))');
  // Tipos de buceo + su plantilla de botellas.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveType '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT)');
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveTypeTank '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, TypeId INTEGER, Litres REAL, '
      'Material INTEGER, SortOrd INTEGER, Name TEXT)');
  // Migración: añadir Name si la tabla se creó antes (ignora si ya existe).
  try {
    db.execute('ALTER TABLE PandiveDiveTypeTank ADD COLUMN Name TEXT');
  } catch (_) {/* ya existe */}
  // Ordenadores de buceo guardados (reconexión por MAC sin reescanear).
  db.execute('CREATE TABLE IF NOT EXISTS PandiveComputer '
      '(Address TEXT PRIMARY KEY, Name TEXT, Vendor TEXT, Product TEXT, '
      'Updated TEXT)');
}

/// Importación de inmersiones descargadas del ordenador al formato DiveMate.
extension DivemateDbImport on DivemateDb {
  /// Fingerprint de la última inmersión importada de [deviceId] (o null).
  String? fingerprintFor(String deviceId) {
    final r = _db.select(
        'SELECT Fingerprint FROM PandiveSync WHERE DeviceId = ?', [deviceId]);
    return r.isEmpty ? null : r.first['Fingerprint'] as String?;
  }

  /// Guarda el fingerprint de [deviceId] (upsert).
  void setFingerprintFor(String deviceId, String fingerprint) {
    _db.execute(
      'INSERT INTO PandiveSync (DeviceId, Fingerprint, Updated) VALUES (?,?,?) '
      'ON CONFLICT(DeviceId) DO UPDATE SET Fingerprint=excluded.Fingerprint, '
      'Updated=excluded.Updated',
      [deviceId, fingerprint, _nowStamp()],
    );
  }

  /// ¿Ya existe una inmersión del owner en esa fecha/hora? (dedupe simple).
  bool hasDiveAt(DateTime dt) {
    final owner = ownerId;
    String p(int v) => v.toString().padLeft(2, '0');
    final date = '${dt.year}-${p(dt.month)}-${p(dt.day)}';
    final time = '${p(dt.hour)}:${p(dt.minute)}:00';
    final sql = owner != null
        ? 'SELECT 1 FROM Logbook WHERE DiverID=? AND Divedate=? AND Entrytime=? LIMIT 1'
        : 'SELECT 1 FROM Logbook WHERE Divedate=? AND Entrytime=? LIMIT 1';
    final params = owner != null ? [owner, date, time] : [date, time];
    return _db.select(sql, params).isNotEmpty;
  }

  /// Importa una inmersión descargada. Devuelve true si se insertó, false si ya
  /// existía (dedupe por fecha/hora). Escribe perfil en formato DiveMate.
  bool importDownloaded(DownloadedDive d, {String? computer}) {
    final dt = d.datetime;
    if (dt != null && hasDiveAt(dt)) return false;

    final owner = ownerId ?? 1;
    final now = _nowStamp();
    String p(int v) => v.toString().padLeft(2, '0');
    final date = dt != null ? '${dt.year}-${p(dt.month)}-${p(dt.day)}' : null;
    final time = dt != null ? '${p(dt.hour)}:${p(dt.minute)}:00' : null;
    final (interval, prof, prof2) = _encodeProfile(d.samples);
    final o2 = d.gasmixes.isNotEmpty ? d.gasmixes.first.o2 * 100 : null;
    // Prof. media: la del aparato o, si falta, calculada de las muestras.
    var avgDepth = d.avgDepth;
    if (avgDepth == null) {
      final xs = [for (final s in d.samples) if (s.depth > 0) s.depth];
      if (xs.isNotEmpty) avgDepth = xs.reduce((a, b) => a + b) / xs.length;
    }

    _db.execute(
      'INSERT INTO Logbook (Number, Divedate, Entrytime, DiverID, UUID, Updated, '
      'Status, Depth, DepthAvg, Divetime, Watertemp, Computer, O2, ProfileInt, '
      'Profile, Profile2) VALUES (?,?,?,?,?,?,1,?,?,?,?,?,?,?,?,?)',
      [
        nextDiveNumber(), date, time, owner, _uuid(), now,
        d.maxDepth, avgDepth,
        d.divetimeSec != null ? d.divetimeSec! / 60.0 : null,
        d.tempMin, computer, o2, interval, prof, prof2,
      ],
    );
    final id = _db.lastInsertRowId;

    for (var i = 0; i < d.gasmixes.length; i++) {
      final g = d.gasmixes[i];
      _db.execute(
        'INSERT INTO Tank (LogID, TankID, SortOrd, O2, He, UUID, Updated) '
        'VALUES (?,?,?,?,?,?,?)',
        [id, i, i, g.o2 * 100, g.he * 100, _uuid(), now],
      );
    }
    return true;
  }
}

/// Codifica las muestras al formato DiveMate: Profile (12 chars/muestra, 4
/// primeros = decímetros), Profile2 (11 chars, 4 primeros = centi-°C), e
/// intervalo en segundos. Asume muestreo uniforme (como el ordenador).
(int, String?, String?) _encodeProfile(List<DiveSample> samples) {
  if (samples.length < 2) return (0, null, null);
  final totalMs = samples.last.timeMs - samples.first.timeMs;
  var interval = (totalMs / (samples.length - 1) / 1000).round();
  if (interval <= 0) interval = 10;

  final prof = StringBuffer();
  final prof2 = StringBuffer();
  for (final s in samples) {
    final dm = (s.depth * 10).round().clamp(0, 9999);
    prof.write(dm.toString().padLeft(4, '0'));
    prof.write('00000000'); // 12 chars por registro
    final centi = s.temp != null ? (s.temp! * 100).round().clamp(0, 9999) : 0;
    prof2.write(centi.toString().padLeft(4, '0'));
    prof2.write('0000000'); // 11 chars por registro
  }
  return (interval, prof.toString(), prof2.toString());
}
