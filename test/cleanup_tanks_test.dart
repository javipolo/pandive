// purgeBlankTanks: deletes only cylinders that carry nothing, never the gas.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late String path;
  late DivemateDb db;

  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_cleanup');
    path = '${tmp.path}/a.ddb';
    DivemateDb.createEmpty(path).close();
    db = DivemateDb.open(path);
  });
  tearDown(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  const blank = Cylinder(o2: 21);
  const real = Cylinder(size: 15, pressureStart: 200, pressureEnd: 70, o2: 32);

  int dive(int day, List<Cylinder> tanks) {
    final id = db.createDive(dateTime: DateTime(2024, 1, day, 10));
    db.setDiveTanks(id, tanks);
    return id;
  }

  test('borra la botella vacía junto a una con datos', () {
    final id = dive(1, [real, blank, const Cylinder()]);
    expect(db.purgeBlankTanks(), 2);
    expect(db.cylinders(id).map((c) => c.size), [15]);
  });

  test('conserva botellas con solo mezcla y buceos sin otra botella', () {
    final mixOnly = dive(1, [real, const Cylinder(o2: 50)]);
    final onlyBlank = dive(2, [blank]);
    final onlyMix = dive(3, [const Cylinder(o2: 32)]);
    final trimix = dive(4, [real, const Cylinder(o2: 21, he: 35)]);
    expect(db.purgeBlankTanks(), 0);
    expect(db.cylinders(mixOnly).length, 2);
    expect(db.cylinders(onlyBlank).length, 1);
    expect(db.cylinders(onlyMix).single.o2, 32);
    expect(db.cylinders(trimix).length, 2);
  });

  test('no desplaza los índices de gas por muestra', () {
    final id = dive(1, [blank, real, blank]);
    db.close();
    final raw = sqlite3.open(path);
    raw.execute('CREATE TABLE IF NOT EXISTS PandiveGas '
        '(DiveId INTEGER PRIMARY KEY, Json TEXT)');
    raw.execute('INSERT INTO PandiveGas VALUES (?, ?)', [id, '[0,1,1,null]']);
    raw.dispose();
    db = DivemateDb.open(path);
    // the blank at index 0 sits before a referenced tank: kept; the last goes
    expect(db.purgeBlankTanks(), 1);
    expect(db.cylinders(id).length, 2);
    expect(db.cylinders(id)[1].size, 15);
  });
}
