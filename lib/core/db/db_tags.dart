part of 'divemate_db.dart';

/// Reusable tags and their per-dive link; sites and dive types also carry
/// tags that their dives inherit on read.
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

  /// IDs of dives that have a tag by name (case-insensitive): the dive's own,
  /// or inherited from its site's (Place) or its dive type's tags.
  Set<int> diveIdsWithTag(String name) {
    const byName = 'SELECT Id FROM PandiveTag WHERE Name = ?1 COLLATE NOCASE';
    final rows = _db.select(
      'SELECT L.ID FROM Logbook L WHERE '
      'L.ID IN (SELECT DiveId FROM PandiveDiveTag WHERE TagId IN ($byName)) '
      '${_inheritedTagClause('IN ($byName)')}',
      [name],
    );
    return {for (final r in rows) r['ID'] as int};
  }

  /// `OR …` matching Logbook `L` rows that inherit a tag whose id satisfies
  /// [tagCond] (e.g. `= ?1`) from their site or their dive type. Empty for
  /// external .ddb files without our tables.
  String _inheritedTagClause(String tagCond) {
    final b = StringBuffer();
    if (_hasTable('PandiveSiteTag')) {
      b.write('OR L.PlaceID IN (SELECT PlaceId FROM PandiveSiteTag '
          'WHERE TagId $tagCond) ');
    }
    if (_hasTable('PandiveDiveTypeTag')) {
      b.write('OR L.Divetype COLLATE NOCASE IN (SELECT DT.Name FROM PandiveDiveType DT '
          'JOIN PandiveDiveTypeTag X ON X.TypeId = DT.Id '
          'WHERE X.TagId $tagCond) ');
    }
    return b.toString();
  }

  /// The dive's own tags (only the PandiveDiveTag link). This is what the editor
  /// edits and saves; it doesn't include those inherited from the site.
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

  /// Effective tags of the dive: own + those of its site (Place) + those of
  /// its dive type. Derived on read (dynamic): show/count, don't persist.
  List<Tag> effectiveTagsForDive(int diveId) {
    final own = tagsForDive(diveId);
    final r = _db.select(
        'SELECT PlaceID, Divetype FROM Logbook WHERE ID = ?', [diveId]);
    if (r.isEmpty) return own;
    final inherited = inheritedTags(
        placeId: r.first['PlaceID'] as int?,
        diveType: _str(r.first['Divetype']));
    final ids = {for (final t in own) t.id};
    return [
      ...own,
      for (final i in inherited)
        if (ids.add(i.tag.id)) i.tag,
    ]..sort((a, b) => compareFold(a.name, b.name));
  }

  /// Tags a dive with that site and dive type (by name) inherits, with their
  /// source; a tag that comes from both appears once (as site). Takes the
  /// values instead of a dive id so the editor can show them live.
  List<InheritedTag> inheritedTags({int? placeId, String? diveType}) {
    final out = <InheritedTag>[];
    final seen = <int>{};
    if (placeId != null && _hasTable('PandiveSiteTag')) {
      for (final t in tagsForSite(placeId)) {
        if (seen.add(t.id)) out.add(InheritedTag(t, TagSource.site));
      }
    }
    final type = diveType?.trim();
    if (type != null && type.isNotEmpty && _hasTable('PandiveDiveTypeTag')) {
      final rows = _db.select(
        'SELECT T.Id, T.Name FROM PandiveTag T '
        'JOIN PandiveDiveTypeTag X ON X.TagId = T.Id '
        'JOIN PandiveDiveType DT ON DT.Id = X.TypeId '
        'WHERE DT.Name = ? COLLATE NOCASE ORDER BY T.Name COLLATE NOCASE',
        [type],
      );
      for (final r in rows) {
        final t = Tag(id: r['Id'] as int, name: _str(r['Name']) ?? '');
        if (seen.add(t.id)) out.add(InheritedTag(t, TagSource.diveType));
      }
    }
    return out;
  }

  /// Tags assigned to a site (Place).
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

  /// Walks the comments of all dives, extracts #hashtags and
  /// assigns them as tags (creating them if needed). Doesn't delete existing tags.
  /// If [removeFromComments], removes the #hashtags from the comment. Returns the
  /// number of new (dive, tag) assignments.
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

  /// Adds each dive's tags as #hashtags to the comment (if not
  /// already there). If [removeTags], unlinks the tags after converting them.
  /// Returns the number of #hashtags added.
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
    if (_hasTable('PandiveDiveTypeTag')) {
      _db.execute('DELETE FROM PandiveDiveTypeTag WHERE TagId=?', [id]);
    }
    _db.execute('DELETE FROM PandiveTag WHERE Id=?', [id]);
  }

  /// Dives with a tag (the dive's own or inherited from its site or type).
  List<Dive> listDivesByTag(int tagId) {
    final owner = ownerId;
    final diver = owner != null ? 'AND L.DiverID = $owner' : '';
    final rows = _db.select(
      'SELECT ${DivemateDbQueries._diveColumns} FROM Logbook L '
      'WHERE (L.ID IN (SELECT DiveId FROM PandiveDiveTag WHERE TagId = ?1) '
      '${_inheritedTagClause('= ?1')}) '
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
