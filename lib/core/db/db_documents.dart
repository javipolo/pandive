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

  /// Documentos en el orden manual del usuario (SortOrd); los sin orden al final.
  List<DiveDoc> listDocuments() {
    final rows = _db.select(
        'SELECT Id, Title, Notes, Expires, ExpiryDate, FileName, Created, '
        'Updated FROM PandiveDocument '
        'ORDER BY SortOrd IS NULL, SortOrd ASC, Created ASC, Title ASC');
    return rows.map(_docFromRow).toList();
  }

  /// Persiste el orden manual: [ids] en el orden deseado.
  void setDocumentOrder(List<int> ids) {
    for (var i = 0; i < ids.length; i++) {
      _db.execute('UPDATE PandiveDocument SET SortOrd = ? WHERE Id = ?',
          [i, ids[i]]);
    }
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
