part of 'divemate_db.dart';

/// Importación de inmersiones externas (p.ej. Subsurface) con perfil, botellas,
/// sitio, compañeros y etiquetas.
extension DivemateDbImportExt on DivemateDb {
  /// Inserta una inmersión externa. Dedupe por fecha/hora (ignora las ya
  /// presentes, salvo borradas). Devuelve true si la insertó.
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
    if (cylinders.isNotEmpty) setDiveTanks(id, cylinders);
    final tags = [
      for (final n in tagNames)
        if (n.trim().isNotEmpty) Tag(id: findOrCreateTag(n.trim()), name: n.trim())
    ];
    if (tags.isNotEmpty) setDiveTags(id, tags);
    return true;
  }
}
