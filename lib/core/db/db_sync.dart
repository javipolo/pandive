part of 'divemate_db.dart';

/// Fingerprint por buceo y utilidad de "punto de sync" (debug/pruebas).
extension DivemateDbSync on DivemateDb {
  /// Fingerprint del ordenador guardado para un buceo (o null).
  String? diveFingerprint(int id) {
    final r = _db.select('SELECT PandiveFp FROM Logbook WHERE ID=?', [id]);
    return r.isEmpty ? null : _str(r.first['PandiveFp']);
  }

  /// Fija el punto de sync en [diveId] (su fingerprint, o vacío si no lo tiene)
  /// y borra (Status=2) todos los buceos del owner posteriores.
  void setSyncPoint(int diveId, String deviceId) {
    final d = getDive(diveId);
    if (d?.date == null) return;
    final newer = [
      for (final e in listDives())
        if (e.date != null && e.date!.isAfter(d!.date!)) e.id,
    ];
    deleteDives(newer);
    setFingerprintFor(deviceId, diveFingerprint(diveId) ?? '');
  }
}
