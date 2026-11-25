part of 'divemate_db.dart';

/// Cache of downloaded but unsaved dives. Lets them reappear in the
/// next download without fetching them from the computer again (see download_screen).
extension DivemateDbPending on DivemateDb {
  List<DownloadedDive> listPending(String deviceId) {
    final rows = _db.select(
      'SELECT Json FROM PandivePending WHERE DeviceId = ? ORDER BY Updated DESC',
      [deviceId],
    );
    final out = <DownloadedDive>[];
    for (final r in rows) {
      final s = _str(r['Json']);
      if (s == null) continue;
      try {
        out.add(DownloadedDive.fromJson(
            jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // corrupt entry: ignored
      }
    }
    return out;
  }

  void addPending(String deviceId, DownloadedDive dive) {
    _db.execute(
      'INSERT OR REPLACE INTO PandivePending (DeviceId, Fingerprint, Json, '
      'Updated) VALUES (?,?,?,?)',
      [deviceId, dive.fingerprint, jsonEncode(dive.toJson()), _nowStamp()],
    );
  }

  void removePending(String deviceId, String fingerprint) {
    _db.execute(
      'DELETE FROM PandivePending WHERE DeviceId = ? AND Fingerprint = ?',
      [deviceId, fingerprint],
    );
  }
}
