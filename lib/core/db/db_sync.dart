part of 'divemate_db.dart';

/// Per-dive fingerprint and "sync point" utility (debug/testing).
extension DivemateDbSync on DivemateDb {
  /// Computer fingerprint stored for a dive (or null).
  String? diveFingerprint(int id) {
    final r = _db.select('SELECT PandiveFp FROM Logbook WHERE ID=?', [id]);
    return r.isEmpty ? null : _str(r.first['PandiveFp']);
  }

  /// Extra per-sample parameters (ppo2/cns/pressure/rbt) from PandiveSampleExtra,
  /// aligned to [n] samples (lists of nulls if there is no data).
  ({List<double?> ppo2, List<double?> cns, List<double?> pressure, List<int?> rbt})
      sampleExtra(int id, int n) {
    final res = (
      ppo2: List<double?>.filled(n, null),
      cns: List<double?>.filled(n, null),
      pressure: List<double?>.filled(n, null),
      rbt: List<int?>.filled(n, null),
    );
    try {
      final r = _db.select('SELECT Json FROM PandiveSampleExtra WHERE DiveId=?', [id]);
      final s = r.isEmpty ? null : _str(r.first['Json']);
      if (s == null) return res;
      final m = jsonDecode(s) as Map<String, dynamic>;
      void fd(String k, List<double?> out) {
        final a = m[k] as List?;
        if (a == null) return;
        for (var i = 0; i < n && i < a.length; i++) {
          if (a[i] != null) out[i] = (a[i] as num).toDouble();
        }
      }
      fd('ppo2', res.ppo2);
      fd('cns', res.cns);
      fd('pressure', res.pressure);
      final a = m['rbt'] as List?;
      if (a != null) {
        for (var i = 0; i < n && i < a.length; i++) {
          if (a[i] != null) res.rbt[i] = (a[i] as num).toInt();
        }
      }
    } catch (_) {}
    return res;
  }

  /// Stores extra per-sample parameters (ppo2/cns/pressure/rbt) in
  /// PandiveSampleExtra, only if some sample carries them.
  void storeSampleExtra(int id, List<DiveSample> ss) {
    if (!ss.any((s) =>
        s.ppo2 != null || s.cns != null || s.pressure != null || s.rbt != null)) {
      return;
    }
    _db.execute(
      'INSERT OR REPLACE INTO PandiveSampleExtra (DiveId, Json) VALUES (?,?)',
      [
        id,
        jsonEncode({
          'ppo2': [for (final s in ss) s.ppo2],
          'cns': [for (final s in ss) s.cns],
          'pressure': [for (final s in ss) s.pressure],
          'rbt': [for (final s in ss) s.rbt],
        }),
      ],
    );
  }

  /// Sets the sync point at [diveId] (its fingerprint, or empty if it has none)
  /// and deletes (Status=2) all later owner dives.
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
