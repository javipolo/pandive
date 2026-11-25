import 'dart:io';
// Basic Pandive smoke test.
import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/backup_util.dart';
import 'package:pandive/features/stats/widgets/stats_buckets.dart';

void main() {
  test('gasLabel identifica mezclas', () {
    expect(const Cylinder(o2: 21).gasLabel, 'Aire');
    expect(const Cylinder(o2: 32).gasLabel, 'Nitrox EAN32');
    expect(const Cylinder(o2: 18, he: 45).gasLabel, 'Trimix 18/45');
    expect(const Cylinder().gasLabel, 'Aire');
  });

  test('backupFileName da nombre con timestamp', () {
    expect(backupFileName(DateTime(2026, 3, 4, 9, 5, 7)),
        'pandive-20260304-090507.ddb.gz');
    expect(isTimestampedBackup('pandive-20260304-090507.ddb.gz'), isTrue);
    expect(isTimestampedBackup('pandive-20260304-090507.ddb'), isTrue); // antiguo
    expect(isTimestampedBackup('latest.ddb.gz'), isFalse);
    expect(isTimestampedBackup('sync-logbook.ddb.gz'), isFalse);
  });

  test('maybeGunzip: gzip se descomprime, .ddb antiguo tal cual', () {
    final raw = 'SQLite format 3\x00 datos'.codeUnits;
    expect(maybeGunzip(gzip.encode(raw)), raw);
    expect(maybeGunzip(raw), raw);
  });

  test('idsToPrune conserva las 10 más nuevas', () {
    final items = [
      for (var i = 0; i < 13; i++) ('id$i', DateTime(2026, 1, 1 + i)),
    ];
    final prune = idsToPrune(items);
    // The 3 oldest (id0,id1,id2) are deleted.
    expect(prune.toSet(), {'id0', 'id1', 'id2'});
  });

  test('bucketByPeriod agrupa por año/mes/semana', () {
    final dates = [
      DateTime(2024, 1, 10),
      DateTime(2024, 1, 20),
      DateTime(2024, 3, 2),
      DateTime(2025, 6, 6),
    ];
    expect(bucketByPeriod(dates, StatsPeriod.year),
        [('2024', 3), ('2025', 1)]);
    expect(bucketByPeriod(dates, StatsPeriod.month),
        [('24-01', 2), ('24-03', 1), ('25-06', 1)]);
    // 1 January 2024 = ISO week 2024-W02; same bucket for 10 and 20 Jan.
    final wk = bucketByPeriod(dates, StatsPeriod.week);
    expect(wk.length, 4); // 10 and 20 Jan fall in different weeks
    expect(wk.fold<int>(0, (s, e) => s + e.$2), 4);
  });
}
