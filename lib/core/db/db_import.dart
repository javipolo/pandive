part of 'divemate_db.dart';

/// Creates the sync table (fingerprints per device) if missing.
/// Pandive-specific; divemate-cli ignores it.
void _ensureSyncTable(Database db) {
  db.execute('CREATE TABLE IF NOT EXISTS PandiveSync '
      '(DeviceId TEXT PRIMARY KEY, Fingerprint TEXT, Updated TEXT)');
  // "My cylinders": reusable size + material presets.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveTankPreset '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Litres REAL, '
      'Material INTEGER)');
  // Reusable tags + per-dive link.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveTag '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT)');
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveTag '
      '(DiveId INTEGER, TagId INTEGER, PRIMARY KEY (DiveId, TagId))');
  // Per-site tags (Place): derived onto that site's dives at
  // read time (see effectiveTagsForDive / diveIdsWithTag / listDivesByTag).
  db.execute('CREATE TABLE IF NOT EXISTS PandiveSiteTag '
      '(PlaceId INTEGER, TagId INTEGER, PRIMARY KEY (PlaceId, TagId))');
  // Cache of downloaded but unsaved dives (they show up "one more time").
  db.execute('CREATE TABLE IF NOT EXISTS PandivePending '
      '(DeviceId TEXT, Fingerprint TEXT, Json TEXT, Updated TEXT, '
      'PRIMARY KEY (DeviceId, Fingerprint))');
  // Dive types + their cylinder template.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveType '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT)');
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveTypeTank '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, TypeId INTEGER, Litres REAL, '
      'Material INTEGER, SortOrd INTEGER, Name TEXT)');
  // Per-type tags: derived onto the dives of that type (Logbook.Divetype =
  // type name) at read time, like the site tags.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDiveTypeTag '
      '(TypeId INTEGER, TagId INTEGER, PRIMARY KEY (TypeId, TagId))');
  // Migration: add Name if the table was created earlier (ignore if it exists).
  try {
    db.execute('ALTER TABLE PandiveDiveTypeTank ADD COLUMN Name TEXT');
  } catch (_) {/* already exists */}
  // Own column for the computed SAC/RMV (DiveMate lacks it; it ignores it).
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveSac REAL');
  } catch (_) {/* already exists */}
  // Average temperature (from the profile); the minimum goes in Watertemp (DiveMate convention).
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveAvgTemp REAL');
  } catch (_) {/* already exists */}
  // Computer fingerprint per dive (to pin sync points / debug).
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveFp TEXT');
  } catch (_) {/* already exists */}
  // Saved dive computers (reconnect by MAC without rescanning).
  db.execute('CREATE TABLE IF NOT EXISTS PandiveComputer '
      '(Address TEXT PRIMARY KEY, Name TEXT, Vendor TEXT, Product TEXT, '
      'Updated TEXT)');
  // Gas index per sample (JSON array) for downloads with gas switches.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveGas '
      '(DiveId INTEGER PRIMARY KEY, Json TEXT)');
  // Extra per-sample parameters (ppo2/cns/pressure/rbt) as JSON arrays.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveSampleExtra '
      '(DiveId INTEGER PRIMARY KEY, Json TEXT)');
  // Documents (certifications, insurance, etc.): image on disk + metadata.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveDocument '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Title TEXT, Notes TEXT, '
      'Expires INTEGER, ExpiryDate TEXT, FileName TEXT, Created TEXT, '
      'Updated TEXT, SortOrd INTEGER)');
  // Migration: add SortOrd if the table was created earlier (manual order).
  try {
    db.execute('ALTER TABLE PandiveDocument ADD COLUMN SortOrd INTEGER');
  } catch (_) {/* already exists */}
  // Trips: group dives (own column in Logbook) + trip buddies.
  db.execute('CREATE TABLE IF NOT EXISTS PandiveTrip '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Notes TEXT, Updated TEXT)');
  db.execute('CREATE TABLE IF NOT EXISTS PandiveTripBuddy '
      '(TripId INTEGER, BuddyId INTEGER, PRIMARY KEY (TripId, BuddyId))');
  try {
    db.execute('ALTER TABLE Logbook ADD COLUMN PandiveTripId INTEGER');
  } catch (_) {/* already exists */}
  // Ports (name + GPS): trip departure/arrival and, optionally, per dive.
  db.execute('CREATE TABLE IF NOT EXISTS PandivePort '
      '(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Lat REAL, Lon REAL, '
      'Updated TEXT)');
  for (final (table, col) in const [
    ('PandiveTrip', 'DeparturePortId'),
    ('PandiveTrip', 'ArrivalPortId'),
    ('Logbook', 'PandivePortId'),
  ]) {
    try {
      db.execute('ALTER TABLE $table ADD COLUMN $col INTEGER');
    } catch (_) {/* already exists */}
  }
}

/// Import of dives downloaded from the computer into DiveMate format.
extension DivemateDbImport on DivemateDb {
  /// Fingerprint of the last dive imported from [deviceId] (or null).
  String? fingerprintFor(String deviceId) {
    final r = _db.select(
        'SELECT Fingerprint FROM PandiveSync WHERE DeviceId = ?', [deviceId]);
    return r.isEmpty ? null : r.first['Fingerprint'] as String?;
  }

  /// Stores the fingerprint of [deviceId] (upsert).
  void setFingerprintFor(String deviceId, String fingerprint) {
    _db.execute(
      'INSERT INTO PandiveSync (DeviceId, Fingerprint, Updated) VALUES (?,?,?) '
      'ON CONFLICT(DeviceId) DO UPDATE SET Fingerprint=excluded.Fingerprint, '
      'Updated=excluded.Updated',
      [deviceId, fingerprint, _nowStamp()],
    );
  }

  /// Is there already a (non-deleted) owner dive at that date/time? (dedupe).
  /// Ignores deleted ones (Status=2) so a deleted dive can be re-downloaded.
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

  /// Dives (live, owner's) of a day: id, time, max depth and
  /// duration (min). To dedupe imports without a time (SSI CSV).
  List<({int id, String? time, double? depth, double? minutes})> divesOnDay(
      DateTime day) {
    final owner = ownerId;
    String p(int v) => v.toString().padLeft(2, '0');
    final date = '${day.year}-${p(day.month)}-${p(day.day)}';
    final rows = _db.select(
        'SELECT ID, Entrytime, Depth, Divetime FROM Logbook WHERE Divedate = ? '
        'AND (Status IS NULL OR Status != 2)'
        '${owner != null ? ' AND DiverID = ?' : ''} ORDER BY Entrytime',
        [date, ?owner]);
    return [
      for (final r in rows)
        (
          id: r['ID'] as int,
          time: r['Entrytime'] as String?,
          depth: (r['Depth'] as num?)?.toDouble(),
          minutes: (r['Divetime'] as num?)?.toDouble(),
        ),
    ];
  }

  /// Imports a downloaded dive. Returns true if inserted, false if it already
  /// existed (dedupe by date/time). Writes the profile in DiveMate format.
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
    // Avg depth: the device's or, if missing, computed from the samples.
    var avgDepth = d.avgDepth;
    if (avgDepth == null) {
      final xs = [for (final s in d.samples) if (s.depth > 0) s.depth];
      if (xs.isNotEmpty) avgDepth = xs.reduce((a, b) => a + b) / xs.length;
    }
    // Sample temperatures: minimum (Watertemp) and average (PandiveAvgTemp).
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
    clearDiveAssoc(id); // avoids inheriting cylinders/gas from a reused ID
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
    // Gas per sample (if the computer logged mix switches).
    if (d.samples.any((s) => s.gasIndex != null)) {
      _db.execute('INSERT OR REPLACE INTO PandiveGas (DiveId, Json) VALUES (?,?)',
          [id, jsonEncode([for (final s in d.samples) s.gasIndex])]);
    }
    storeSampleExtra(id, d.samples);
    return true;
  }
}
