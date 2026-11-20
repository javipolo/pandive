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
  // Columna propia para el SAC/RMV calculado (DiveMate no la tiene; la ignora).
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveSac REAL');
  } catch (_) {/* ya existe */}
  // Temperatura media (del perfil); la mínima va en Watertemp (convención DiveMate).
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveAvgTemp REAL');
  } catch (_) {/* ya existe */}
  // Fingerprint del ordenador por buceo (para fijar puntos de sync / debug).
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveFp TEXT');
  } catch (_) {/* ya existe */}
  // Ordenadores de buceo guardados (reconexión por MAC sin reescanear).
  db.execute('CREATE TABLE IF NOT EXISTS PandiveComputer '
      '(Address TEXT PRIMARY KEY, Name TEXT, Vendor TEXT, Product TEXT, '
      'Updated TEXT)');
  // Índice de gas por muestra (JSON array) para descargas con cambios de gas.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveGas '
      '(DiveId INTEGER PRIMARY KEY, Json TEXT)');
  // Parámetros extra por muestra (ppo2/cns/presión/rbt) como JSON de arrays.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveSampleExtra '
      '(DiveId INTEGER PRIMARY KEY, Json TEXT)');
  // Documentación (certificaciones, seguro, etc.): imagen en disco + metadatos.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDocument '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Title TEXT, Notes TEXT, '
      'Expires INTEGER, ExpiryDate TEXT, FileName TEXT, Created TEXT, '
      'Updated TEXT, SortOrd INTEGER)');
  // Migración: añadir SortOrd si la tabla se creó antes (orden manual).
  try {
    db.execute('ALTER TABLE PandiveDocument ADD COLUMN SortOrd INTEGER');
  } catch (_) {/* ya existe */}
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

  /// ¿Ya existe una inmersión (no borrada) del owner en esa fecha/hora? (dedupe).
  /// Ignora las borradas (Status=2) para que un buceo borrado pueda re-descargarse.
  bool hasDiveAt(DateTime dt) {
    final owner = ownerId;
    String p(int v) => v.toString().padLeft(2, '0');
    final date = '${dt.year}-${p(dt.month)}-${p(dt.day)}';
    final time = '${p(dt.hour)}:${p(dt.minute)}:00';
    final live = '(Status IS NULL OR Status != 2)';
    final sql = owner != null
        ? 'SELECT 1 FROM Logbook WHERE DiverID=? AND Divedate=? AND Entrytime=? AND $live LIMIT 1'
        : 'SELECT 1 FROM Logbook WHERE Divedate=? AND Entrytime=? AND $live LIMIT 1';
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
    final prof4 = _encodeProfile4(d.samples);
    final o2 = d.gasmixes.isNotEmpty ? d.gasmixes.first.o2 * 100 : null;
    // Prof. media: la del aparato o, si falta, calculada de las muestras.
    var avgDepth = d.avgDepth;
    if (avgDepth == null) {
      final xs = [for (final s in d.samples) if (s.depth > 0) s.depth];
      if (xs.isNotEmpty) avgDepth = xs.reduce((a, b) => a + b) / xs.length;
    }
    // Temperaturas de las muestras: mínima (Watertemp) y media (PandiveAvgTemp).
    final temps = [for (final s in d.samples) if (s.temp != null) s.temp!];
    final minTemp =
        d.tempMin ?? (temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b));
    final avgTemp =
        temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;

    _db.execute(
      'INSERT INTO Logbook (Number, Divedate, Entrytime, DiverID, UUID, Updated, '
      'Status, Depth, DepthAvg, Divetime, Watertemp, PandiveAvgTemp, Computer, '
      'O2, ProfileInt, Profile, Profile2, Profile4) '
      'VALUES (?,?,?,?,?,?,1,?,?,?,?,?,?,?,?,?,?,?)',
      [
        nextDiveNumber(), date, time, owner, _uuid(), now,
        d.maxDepth, avgDepth,
        d.divetimeSec != null ? d.divetimeSec! / 60.0 : null,
        minTemp, avgTemp, computer, o2, interval, prof, prof2, prof4,
      ],
    );
    final id = _db.lastInsertRowId;
    clearDiveAssoc(id); // evita heredar botellas/gas de un ID reutilizado
    if (d.fingerprint.isNotEmpty) {
      _db.execute('UPDATE Logbook SET PandiveFp=? WHERE ID=?', [d.fingerprint, id]);
    }

    for (var i = 0; i < d.gasmixes.length; i++) {
      final g = d.gasmixes[i];
      _db.execute(
        'INSERT INTO Tank (LogID, TankID, SortOrd, O2, He, UUID, Updated) '
        'VALUES (?,?,?,?,?,?,?)',
        [id, i, i, g.o2 * 100, g.he * 100, _uuid(), now],
      );
    }
    // Gas por muestra (si el ordenador registró cambios de mezcla).
    if (d.samples.any((s) => s.gasIndex != null)) {
      _db.execute('INSERT OR REPLACE INTO PandiveGas (DiveId, Json) VALUES (?,?)',
          [id, jsonEncode([for (final s in d.samples) s.gasIndex])]);
    }
    storeSampleExtra(id, d.samples);
    return true;
  }
}
