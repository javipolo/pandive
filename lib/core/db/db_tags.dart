part of 'divemate_db.dart';

/// Etiquetas (tags) reutilizables y su enlace por inmersión.
extension DivemateDbTags on DivemateDb {
  List<Tag> listTags() {
    final rows = _db.select(
        'SELECT Id, Name FROM PandiveTag ORDER BY Name COLLATE NOCASE');
    return rows
        .map((r) => Tag(id: r['Id'] as int, name: _str(r['Name']) ?? ''))
        .toList();
  }

  int findOrCreateTag(String name) {
    final n = name.trim();
    final f = _db.select(
        'SELECT Id FROM PandiveTag WHERE Name = ? COLLATE NOCASE', [n]);
    if (f.isNotEmpty) return f.first['Id'] as int;
    _db.execute('INSERT INTO PandiveTag (Name) VALUES (?)', [n]);
    return _db.lastInsertRowId;
  }

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
