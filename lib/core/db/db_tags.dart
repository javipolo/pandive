part of 'divemate_db.dart';

/// Etiquetas (tags) reutilizables y su enlace por inmersión.
extension DivemateDbTags on DivemateDb {
  List<Tag> listTags() {
    final rows = _db.select('SELECT Id, Name FROM PandiveTag');
    return rows
        .map((r) => Tag(id: r['Id'] as int, name: _str(r['Name']) ?? ''))
        .toList()
      ..sort((a, b) => compareFold(a.name, b.name));
  }

  int findOrCreateTag(String name) {
    final n = name.trim();
    final f = _db.select(
        'SELECT Id FROM PandiveTag WHERE Name = ? COLLATE NOCASE', [n]);
    if (f.isNotEmpty) return f.first['Id'] as int;
    _db.execute('INSERT INTO PandiveTag (Name) VALUES (?)', [n]);
    return _db.lastInsertRowId;
  }

  /// IDs de inmersiones que tienen un tag por nombre (case-insensitive), ya sea
  /// propio del buceo o heredado del tag de su sitio (Place).
  Set<int> diveIdsWithTag(String name) {
    final bySite = _hasTable('PandiveSiteTag')
        ? 'OR L.PlaceID IN (SELECT S.PlaceId FROM PandiveSiteTag S '
            'JOIN PandiveTag T ON T.Id = S.TagId WHERE T.Name = ? COLLATE NOCASE)'
        : '';
    final params = bySite.isEmpty ? [name] : [name, name];
    final rows = _db.select(
      'SELECT L.ID FROM Logbook L WHERE '
      'L.ID IN (SELECT D.DiveId FROM PandiveDiveTag D '
      '         JOIN PandiveTag T ON T.Id = D.TagId WHERE T.Name = ? COLLATE NOCASE) '
      '$bySite',
      params,
    );
    return {for (final r in rows) r['ID'] as int};
  }

  /// Tags propios del buceo (solo el enlace PandiveDiveTag). Es lo que edita y
  /// guarda el editor; no incluye los heredados del sitio.
  List<Tag> tagsForDive(int diveId) {
    final rows = _db.select(
      'SELECT T.Id, T.Name FROM PandiveTag T '
      'JOIN PandiveDiveTag D ON D.TagId = T.Id WHERE D.DiveId = ? '
      'ORDER BY T.Name COLLATE NOCASE',
      [diveId],
    );
    return rows
        .map((r) => Tag(id: r['Id'] as int, name: _str(r['Name']) ?? ''))
        .toList();
  }

  /// Tags efectivos del buceo: propios + los del sitio (Place) al que pertenece.
  /// Derivados en lectura (dinámicos): mostrar/contar, no persistir.
  List<Tag> effectiveTagsForDive(int diveId) {
    if (!_hasTable('PandiveSiteTag')) return tagsForDive(diveId);
    final rows = _db.select(
      'SELECT T.Id, T.Name FROM PandiveTag T WHERE T.Id IN ('
      '  SELECT TagId FROM PandiveDiveTag WHERE DiveId = ?1 '
      '  UNION '
      '  SELECT TagId FROM PandiveSiteTag WHERE PlaceId = '
      '    (SELECT PlaceID FROM Logbook WHERE ID = ?1)'
      ') ORDER BY T.Name COLLATE NOCASE',
      [diveId],
    );
    return rows
        .map((r) => Tag(id: r['Id'] as int, name: _str(r['Name']) ?? ''))
        .toList();
  }

  /// Tags asignados a un sitio (Place).
  List<Tag> tagsForSite(int placeId) {
    final rows = _db.select(
      'SELECT T.Id, T.Name FROM PandiveTag T '
      'JOIN PandiveSiteTag S ON S.TagId = T.Id WHERE S.PlaceId = ? '
      'ORDER BY T.Name COLLATE NOCASE',
      [placeId],
    );
    return rows
        .map((r) => Tag(id: r['Id'] as int, name: _str(r['Name']) ?? ''))
        .toList();
  }

  void setSiteTags(int placeId, List<Tag> tags) {
    _db.execute('DELETE FROM PandiveSiteTag WHERE PlaceId = ?', [placeId]);
    for (final t in tags) {
      _db.execute(
        'INSERT OR IGNORE INTO PandiveSiteTag (PlaceId, TagId) VALUES (?,?)',
        [placeId, t.id],
      );
    }
  }

  /// Recorre los comentarios de todas las inmersiones, extrae #hashtags y los
  /// asigna como tags (creándolos si hace falta). No borra tags existentes.
  /// Si [removeFromComments], quita los #hashtags del comentario. Devuelve el
  /// nº de asignaciones (dive, tag) nuevas.
  int importHashtagsFromComments({bool removeFromComments = false}) {
    final re = RegExp(r'#(\w+)', unicode: true);
    var added = 0;
    final now = _nowStamp();
    for (final d in listDives()) {
      final c = d.comments;
      if (c == null) continue;
      final have = {for (final t in tagsForDive(d.id)) t.name.toLowerCase()};
      for (final m in re.allMatches(c)) {
        final name = m.group(1)!;
        if (have.contains(name.toLowerCase())) continue;
        final tagId = findOrCreateTag(name);
        _db.execute(
          'INSERT OR IGNORE INTO PandiveDiveTag (DiveId, TagId) VALUES (?,?)',
          [d.id, tagId],
        );
        have.add(name.toLowerCase());
        added++;
      }
      if (removeFromComments && re.hasMatch(c)) {
        final stripped =
            c.replaceAll(re, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
        _db.execute('UPDATE Logbook SET Comments=?, Updated=? WHERE ID=?',
            [stripped.isEmpty ? null : stripped, now, d.id]);
      }
    }
    return added;
  }

  /// Añade los tags de cada inmersión como #hashtags al comentario (si no
  /// están ya). Si [removeTags], desvincula los tags tras convertirlos.
  /// Devuelve el nº de #hashtags añadidos.
  int exportTagsToComments({bool removeTags = false}) {
    final re = RegExp(r'#(\w+)', unicode: true);
    var added = 0;
    final now = _nowStamp();
    for (final d in listDives()) {
      final tags = tagsForDive(d.id);
      if (tags.isEmpty) continue;
      final c = d.comments ?? '';
      final have = {for (final m in re.allMatches(c)) m.group(1)!.toLowerCase()};
      final toAdd = [
        for (final t in tags)
          if (!have.contains(t.name.toLowerCase())) '#${t.name}'
      ];
      if (toAdd.isNotEmpty) {
        final base = c.trim();
        final newC = (base.isEmpty ? '' : '$base ') + toAdd.join(' ');
        _db.execute('UPDATE Logbook SET Comments=?, Updated=? WHERE ID=?',
            [newC, now, d.id]);
        added += toAdd.length;
      }
      if (removeTags) {
        _db.execute('DELETE FROM PandiveDiveTag WHERE DiveId=?', [d.id]);
      }
    }
    return added;
  }

  void renameTag(int id, String name) => _db.execute(
      'UPDATE PandiveTag SET Name=? WHERE Id=?', [name.trim(), id]);

  void deleteTag(int id) {
    _db.execute('DELETE FROM PandiveDiveTag WHERE TagId=?', [id]);
    _db.execute('DELETE FROM PandiveSiteTag WHERE TagId=?', [id]);
    _db.execute('DELETE FROM PandiveTag WHERE Id=?', [id]);
  }

  /// Buceos con un tag (propio del buceo o heredado del tag de su sitio).
  List<Dive> listDivesByTag(int tagId) {
    final owner = ownerId;
    final diver = owner != null ? 'AND L.DiverID = $owner' : '';
    final bySite = _hasTable('PandiveSiteTag')
        ? 'OR L.PlaceID IN (SELECT PlaceId FROM PandiveSiteTag WHERE TagId = ?1)'
        : '';
    final rows = _db.select(
      'SELECT ${DivemateDbQueries._diveColumns} FROM Logbook L '
      'WHERE (L.ID IN (SELECT DiveId FROM PandiveDiveTag WHERE TagId = ?1) $bySite) '
      'AND (L.Status IS NULL OR L.Status != 2) $diver '
      'ORDER BY L.Divedate DESC, L.Entrytime DESC',
      [tagId],
    );
    return rows.map(_diveFromRow).toList();
  }

  void setDiveTags(int diveId, List<Tag> tags) {
    _db.execute('DELETE FROM PandiveDiveTag WHERE DiveId = ?', [diveId]);
    for (final t in tags) {
      _db.execute(
        'INSERT OR IGNORE INTO PandiveDiveTag (DiveId, TagId) VALUES (?,?)',
        [diveId, t.id],
      );
    }
  }
}
