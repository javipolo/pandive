part of 'divemate_db.dart';

/// Documentación del buzo (tabla PandiveDocument). La imagen vive en disco; aquí
/// solo metadatos. Específico de Pandive; divemate-cli lo ignora.
extension DivemateDbDocuments on DivemateDb {
  DiveDoc _docFromRow(Row r) => DiveDoc(
        id: r['Id'] as int,
        title: _str(r['Title']) ?? '',
        notes: _str(r['Notes']),
        expires: (r['Expires'] as int? ?? 0) == 1,
        expiryDate: _parseDate(_str(r['ExpiryDate']), null),
        fileName: _str(r['FileName']) ?? '',
        created: _parseDate(_str(r['Created']), null),
        updated: _parseDate(_str(r['Updated']), null),
      );

  /// Documentos ordenados: caducados y próximos primero, luego por fecha.
  List<DiveDoc> listDocuments() {
    final rows = _db.select(
        'SELECT Id, Title, Notes, Expires, ExpiryDate, FileName, Created, '
        'Updated FROM PandiveDocument ORDER BY '
        'CASE WHEN Expires = 1 THEN 0 ELSE 1 END, ExpiryDate ASC, Title ASC');
    return rows.map(_docFromRow).toList();
  }

  DiveDoc? getDocument(int id) {
    final rows = _db.select(
        'SELECT Id, Title, Notes, Expires, ExpiryDate, FileName, Created, '
        'Updated FROM PandiveDocument WHERE Id = ?',
        [id]);
    return rows.isEmpty ? null : _docFromRow(rows.first);
  }

  String? _dateOnly(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  int insertDocument({
    required String title,
    String? notes,
    bool expires = false,
    DateTime? expiryDate,
    required String fileName,
  }) {
    _db.execute(
      'INSERT INTO PandiveDocument '
      '(Title, Notes, Expires, ExpiryDate, FileName, Created, Updated) '
      'VALUES (?,?,?,?,?,?,?)',
      [
        title.trim(),
        notes?.trim(),
        expires ? 1 : 0,
        _dateOnly(expiryDate),
        fileName,
        _nowStamp(),
        _nowStamp(),
      ],
    );
    return _db.lastInsertRowId;
  }

  void updateDocument(
    int id, {
    required String title,
    String? notes,
    bool expires = false,
    DateTime? expiryDate,
  }) {
    _db.execute(
      'UPDATE PandiveDocument SET Title=?, Notes=?, Expires=?, ExpiryDate=?, '
      'Updated=? WHERE Id=?',
      [
        title.trim(),
        notes?.trim(),
        expires ? 1 : 0,
        _dateOnly(expiryDate),
        _nowStamp(),
        id,
      ],
    );
  }

  void deleteDocument(int id) =>
      _db.execute('DELETE FROM PandiveDocument WHERE Id = ?', [id]);
}
