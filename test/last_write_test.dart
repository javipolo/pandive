// UTC last-write stamp (triggers) and the restore warning rule.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/backup_util.dart';
import 'package:sqlite3/open.dart';

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('cualquier escritura actualiza el sello (UTC)', () async {
    final tmp = Directory.systemTemp.createTempSync('pandive_lw');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = '${tmp.path}/a.ddb';
    DivemateDb.createEmpty(path).close();

    final db = DivemateDb.open(path);
    final before = db.lastWriteUtc;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final id = db.createTrip('Viaje');
    final afterInsert = db.lastWriteUtc!;
    expect(afterInsert.isUtc, isTrue);
    if (before != null) expect(afterInsert.isAfter(before), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    db.renameTrip(id, 'Otro');
    expect(db.lastWriteUtc!.isAfter(afterInsert), isTrue);
    db.close();

    // Read from another process/connection (like when comparing with a backup).
    expect(lastWriteUtcOf(path), isNotNull);
  });

  test('restoreWouldLoseData', () {
    final old = DateTime.utc(2026, 1, 1);
    final recent = DateTime.utc(2026, 6, 1);
    expect(restoreWouldLoseData(recent, old), isTrue); // local newer
    expect(restoreWouldLoseData(old, recent), isFalse); // backup newer
    expect(restoreWouldLoseData(old, old), isFalse); // the same state
    expect(restoreWouldLoseData(recent, null), isTrue); // backup without stamp
    expect(restoreWouldLoseData(null, old), isFalse); // local without stamp
  });
}
