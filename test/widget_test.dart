// Smoke test básico de Pandive.
import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/backup_util.dart';

void main() {
  test('gasLabel identifica mezclas', () {
    expect(const Cylinder(o2: 21).gasLabel, 'Aire');
    expect(const Cylinder(o2: 32).gasLabel, 'Nitrox EAN32');
    expect(const Cylinder(o2: 18, he: 45).gasLabel, 'Trimix 18/45');
    expect(const Cylinder().gasLabel, 'Aire');
  });

  test('backupFileName da nombre con timestamp', () {
    expect(backupFileName(DateTime(2026, 3, 4, 9, 5, 7)),
        'pandive-20260304-090507.ddb');
    expect(isTimestampedBackup('pandive-20260304-090507.ddb'), isTrue);
    expect(isTimestampedBackup('latest.ddb'), isFalse);
  });

  test('idsToPrune conserva las 10 más nuevas', () {
    final items = [
      for (var i = 0; i < 13; i++) ('id$i', DateTime(2026, 1, 1 + i)),
    ];
    final prune = idsToPrune(items);
    // Las 3 más antiguas (id0,id1,id2) se borran.
    expect(prune.toSet(), {'id0', 'id1', 'id2'});
  });
}
