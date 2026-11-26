part of 'divemate_db.dart';

/// Import of external dives (e.g. Subsurface) with profile, cylinders,
/// site, buddies and tags.
extension DivemateDbImportExt on DivemateDb {
  /// Inserts an external dive. Dedupe by date/time (ignores those already
  /// present, except deleted ones). Returns true if it inserted it.
  bool importExternalDive({
    required DateTime dateTime,
    String? placeName,
    String? country,
    double? lat,
    double? lon,
    String? comments,
    List<String> buddies = const [],
    List<String> tagNames = const [],
    double? maxDepth,
    double? avgDepth,
    double? durationMin,
    double? waterTemp,
    double? airTemp,
    String? computer,
    double? o2,
    List<DiveSample> samples = const [],
    List<Cylinder> cylinders = const [],
  }) {
    if (hasDiveAt(dateTime)) return false;
    final owner = ownerId ?? 1;
    final now = _nowStamp();
    String p(int v) => v.toString().padLeft(2, '0');
    final date = '${dateTime.year}-${p(dateTime.month)}-${p(dateTime.day)}';
    final time = '${p(dateTime.hour)}:${p(dateTime.minute)}:00';
    final (interval, prof, prof2) = _encodeProfile(samples);

    final temps = [for (final s in samples) if (s.temp != null) s.temp!];
    final minTemp =
        waterTemp ?? (temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b));
    final avgTemp =
        temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;
    var avg = avgDepth;
    if (avg == null) {
      final xs = [for (final s in samples) if (s.depth > 0) s.depth];
      if (xs.isNotEmpty) avg = xs.reduce((a, b) => a + b) / xs.length;
    }

    final placeId = (placeName != null && placeName.trim().isNotEmpty)
        ? findOrCreateSite(placeName.trim(), country: country, lat: lat, lon: lon)
        : null;
    final ids = [
      for (final n in buddies)
        if (n.trim().isNotEmpty) findOrCreateBuddy(n.trim())
    ];
    final buddyText = buddies.map((n) => n.trim()).where((n) => n.isNotEmpty).join(', ');

    _db.execute(
      'INSERT INTO Logbook (Number, Divedate, Entrytime, DiverID, UUID, Updated, '
      'Status, Place, Country, PlaceID, Depth, DepthAvg, Divetime, Watertemp, '
      'PandiveAvgTemp, Airtemp, Computer, O2, ProfileInt, Profile, Profile2, '
      'Comments, Buddy, BuddyIDs) VALUES (?,?,?,?,?,?,1,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        nextDiveNumber(), date, time, owner, _uuid(), now,
        placeName, country, placeId, maxDepth, avg, durationMin, minTemp,
        avgTemp, airTemp, computer, o2, interval, prof, prof2, comments,
        buddyText.isEmpty ? null : buddyText, ids.isEmpty ? null : ids.join(','),
      ],
    );
    final id = _db.lastInsertRowId;
    clearDiveAssoc(id); // avoids inheriting rows from a reused ID
    if (cylinders.isNotEmpty) setDiveTanks(id, cylinders);
    final tags = [
      for (final n in tagNames)
        if (n.trim().isNotEmpty) Tag(id: findOrCreateTag(n.trim()), name: n.trim())
    ];
    if (tags.isNotEmpty) setDiveTags(id, tags);
    return true;
  }

  /// Fills an existing dive with the data of an imported one (e.g. the SSI
  /// CSV) without touching what it already has: site, country, depth,
  /// duration and computer only if empty; buddies and tags are added to the
  /// existing ones. Profile, cylinders and everything else are kept.
  /// Returns true if anything changed.
  bool fillDiveFromImport(
    int id, {
    String? placeName,
    String? country,
    double? maxDepth,
    double? durationMin,
    String? computer,
    List<String> buddies = const [],
    List<String> tagNames = const [],
  }) {
    final rows = _db.select(
      'SELECT Place, PlaceID, Country, Depth, Divetime, Computer '
      'FROM Logbook WHERE ID=?',
      [id],
    );
    if (rows.isEmpty) return false;
    final r = rows.first;
    bool blank(Object? v) => v == null || (v is String && v.trim().isEmpty);
    bool zero(Object? v) => v == null || (v is num && v <= 0);
    final place = placeName?.trim();
    final fields = <String, Object?>{};
    if (place != null &&
        place.isNotEmpty &&
        blank(r['Place']) &&
        r['PlaceID'] == null) {
      fields['Place'] = place;
      fields['PlaceID'] = findOrCreateSite(place, country: country);
    }
    if (!blank(country) && blank(r['Country'])) fields['Country'] = country;
    if (maxDepth != null && zero(r['Depth'])) fields['Depth'] = maxDepth;
    if (durationMin != null && zero(r['Divetime'])) {
      fields['Divetime'] = durationMin;
    }
    var changed = fields.isNotEmpty;
    if (changed) updateDive(id, fields);
    if (!blank(computer) && blank(r['Computer'])) {
      _db.execute(
        'UPDATE Logbook SET Computer=?, Updated=? WHERE ID=?',
        [computer, _nowStamp(), id],
      );
      changed = true;
    }
    final have = {for (final b in diveBuddies(id)) b.name.toLowerCase()};
    final newBuddies = [
      for (final n in buddies)
        if (n.trim().isNotEmpty && !have.contains(n.trim().toLowerCase()))
          n.trim(),
    ];
    if (newBuddies.isNotEmpty) {
      addDiveBuddies(id, newBuddies);
      changed = true;
    }
    for (final n in tagNames) {
      if (n.trim().isEmpty) continue;
      if (addTagToDives(findOrCreateTag(n.trim()), [id]) > 0) changed = true;
    }
    return changed;
  }

  /// Logbook columns with the profile and computer data (copied as is
  /// between .ddb files; only those present on both sides).
  static const _profileCols = [
    'ProfileInt', 'Profile', 'Profile2', 'Profile3', 'Profile4', 'Profile10',
    'Deco', 'O2', 'MaxPPO2', 'PresS', 'PresE', 'PandiveAvgTemp', 'PandiveSac',
  ];

  Set<String> _logbookCols() => {
        for (final r in _db.select('PRAGMA table_info(Logbook)'))
          r['name'] as String
      };

  /// Copies from [src] (dive [srcId]) to this dive [id]: computer, cylinders and
  /// own tags; with [withProfile] also the profile (Profile*, deco, per-sample
  /// extras).
  void copyDiveDetailsFrom(int id, DivemateDb src, int srcId,
      {bool withProfile = false}) {
    final mine = _logbookCols();
    final theirs = src._logbookCols();
    final cols = [
      'Computer',
      if (withProfile) ..._profileCols,
    ].where((c) => mine.contains(c) && theirs.contains(c)).toList();
    final row = src._db
        .select('SELECT ${cols.join(',')} FROM Logbook WHERE ID=?', [srcId]);
    if (row.isNotEmpty) {
      _db.execute(
        'UPDATE Logbook SET ${cols.map((c) => '$c=?').join(',')} WHERE ID=?',
        [for (final c in cols) row.first[c], id],
      );
    }
    final tanks = src.cylinders(srcId);
    if (tanks.isNotEmpty) setDiveTanks(id, tanks);
    if (src._hasTable('PandiveDiveTag')) {
      final tags = [
        for (final tg in src.tagsForDive(srcId))
          Tag(id: findOrCreateTag(tg.name), name: tg.name)
      ];
      if (tags.isNotEmpty) setDiveTags(id, tags);
    }
    if (withProfile &&
        src._hasTable('PandiveSampleExtra') &&
        _hasTable('PandiveSampleExtra')) {
      final r = src._db
          .select('SELECT Json FROM PandiveSampleExtra WHERE DiveId=?', [srcId]);
      if (r.isNotEmpty) {
        _db.execute(
            'INSERT OR REPLACE INTO PandiveSampleExtra (DiveId, Json) VALUES (?,?)',
            [id, r.first['Json']]);
      }
    }
  }
}
