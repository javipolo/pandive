part of 'divemate_db.dart';

/// Se lanza si el intervalo en superficie entre dos inmersiones supera el máximo.
class MergeTooFarException implements Exception {
  final int gapMinutes;
  MergeTooFarException(this.gapMinutes);
}

extension DivemateDbMerge on DivemateDb {
  /// Fusiona [ids] en una sola (la más antigua conserva nº/fecha/sitio). Suma
  /// los tiempos, prof. máx = la mayor, perfil concatenado (con el hueco en
  /// superficie), compañeros/tags/botellas = unión. Las demás se borran.
  /// Lanza [MergeTooFarException] si algún hueco supera [maxGapMin].
  int mergeDives(List<int> ids, {required int maxGapMin}) {
    final dives = ids.map(getDive).whereType<Dive>().toList()
      ..sort((a, b) =>
          (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    if (dives.length < 2) return dives.isEmpty ? -1 : dives.first.id;

    for (var i = 1; i < dives.length; i++) {
      final prev = dives[i - 1], cur = dives[i];
      if (prev.date == null || cur.date == null || prev.durationMin == null) {
        continue;
      }
      final prevEnd =
          prev.date!.add(Duration(minutes: prev.durationMin!.round()));
      final gap = cur.date!.difference(prevEnd).inMinutes;
      if (gap > maxGapMin) throw MergeTooFarException(gap);
    }

    final first = dives.first;
    final interval = (first.profileInterval ?? 10) > 0
        ? first.profileInterval ?? 10
        : 10;
    final start0 = first.date;

    // Perfil continuo: rellena con superficie (0 m) los huecos entre partes.
    final depths = <double>[];
    final temps = <double?>[];
    for (final d in dives) {
      final p = diveProfile(d.id);
      if (p == null) continue;
      if (start0 != null && d.date != null) {
        final base = (d.date!.difference(start0).inSeconds / interval).round();
        while (depths.length < base) {
          depths.add(0);
          temps.add(null);
        }
      }
      for (var i = 0; i < p.depths.length; i++) {
        depths.add(p.depths[i]);
        temps.add(p.temps[i]);
      }
    }
    final samples = [
      for (var i = 0; i < depths.length; i++)
        DiveSample(i * interval * 1000, depths[i], temps[i]),
    ];
    final (_, prof, prof2) = _encodeProfile(samples);

    final divetime =
        dives.fold<double>(0, (s, d) => s + (d.durationMin ?? 0));
    final maxDepth = dives
        .map((d) => d.maxDepth ?? 0)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final avgVals = depths.where((d) => d > 0).toList();
    final avgDepth = avgVals.isEmpty
        ? null
        : avgVals.reduce((a, b) => a + b) / avgVals.length;
    final tempVals = temps.whereType<double>().toList();
    final watertemp = tempVals.isEmpty
        ? null
        : tempVals.reduce((a, b) => a < b ? a : b);

    _db.execute(
      'UPDATE Logbook SET Divetime=?, Depth=?, DepthAvg=?, Watertemp=?, '
      'ProfileInt=?, Profile=?, Profile2=?, Updated=? WHERE ID=?',
      [divetime, maxDepth, avgDepth, watertemp, interval, prof, prof2,
        _nowStamp(), first.id],
    );

    // Unión de compañeros, tags y botellas.
    final buddies = <int, Buddy>{};
    final tags = <int, Tag>{};
    final tanks = <Cylinder>[];
    for (final d in dives) {
      for (final b in diveBuddies(d.id)) {
        buddies[b.id] = b;
      }
      for (final t in tagsForDive(d.id)) {
        tags[t.id] = t;
      }
      tanks.addAll(cylinders(d.id));
    }
    if (buddies.isNotEmpty) {
      updateDive(first.id, {
        'Buddy': buddies.values.map((b) => b.name).join(', '),
        'BuddyIDs': buddies.values.map((b) => b.id).join(','),
      });
    }
    setDiveTags(first.id, tags.values.toList());
    setDiveTanks(first.id, tanks);

    deleteDives([for (final d in dives.skip(1)) d.id]);
    return first.id;
  }
}
