// Sello UTC de última escritura (triggers) y la regla de aviso al restaurar.
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

    // Leído desde otro proceso/conexión (como al comparar con un backup).
    expect(lastWriteUtcOf(path), isNotNull);
  });

  test('restoreWouldLoseData', () {
    final old = DateTime.utc(2026, 1, 1);
    final recent = DateTime.utc(2026, 6, 1);
    expect(restoreWouldLoseData(recent, old), isTrue); // local más nuevo
    expect(restoreWouldLoseData(old, recent), isFalse); // backup más nuevo
    expect(restoreWouldLoseData(old, old), isFalse); // el mismo estado
    expect(restoreWouldLoseData(recent, null), isTrue); // backup sin sello
    expect(restoreWouldLoseData(null, old), isFalse); // local sin sello
  });
}
