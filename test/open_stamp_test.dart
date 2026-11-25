// Opening a logbook must not move the last-write stamp: if it does,
// sync sees "modified here" on every start and, with two devices,
// a false divergence (happened with the non-computable SAC: NULL -> NULL).
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:sqlite3/open.dart';

void main() {
  late Directory tmp;
  late String path;

  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_stamp');
    path = '${tmp.path}/a.ddb';
    DivemateDb.createEmpty(path).close();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('reabrir no cambia el sello (SAC no calculable, perfiles)', () async {
    var db = DivemateDb.open(path);
    // No duration: there are pressures but the SAC can't be computed.
    db.createDive(dateTime: DateTime(2024, 1, 1, 10));
    final id = db.listDives().single.id;
    db.setDiveTanks(id, const [
      Cylinder(size: 12, pressureStart: 200, pressureEnd: 50),
    ]);
    // With a profile (avg depth / temperatures are filled on open).
    db.importExternalDive(
      dateTime: DateTime(2024, 1, 2, 10),
      durationMin: 3,
      samples: [
        for (var i = 0; i < 4; i++) DiveSample(i * 60000, i * 5.0, null),
      ],
    );
    db.close();

    // First open: may fill in what's missing (once).
    DivemateDb.open(path).close();
    db = DivemateDb.open(path, readOnly: true);
    final before = db.lastWriteRaw;
    db.close();

    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 3; i++) {
      DivemateDb.open(path).close();
    }
    db = DivemateDb.open(path, readOnly: true);
    expect(db.lastWriteRaw, before);
    db.close();
  });
}
