// Abrir un logbook no debe mover el sello de última escritura: si lo mueve,
// la sync ve "modificado aquí" en cada arranque y, con dos dispositivos,
// divergencia falsa (pasaba con el SAC no calculable: NULL -> NULL).
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
    // Sin duración: hay presiones pero el SAC no se puede calcular.
    db.createDive(dateTime: DateTime(2024, 1, 1, 10));
    final id = db.listDives().single.id;
    db.setDiveTanks(id, const [
      Cylinder(size: 12, pressureStart: 200, pressureEnd: 50),
    ]);
    // Con perfil (prof. media / temperaturas se rellenan al abrir).
    db.importExternalDive(
      dateTime: DateTime(2024, 1, 2, 10),
      durationMin: 3,
      samples: [
        for (var i = 0; i < 4; i++) DiveSample(i * 60000, i * 5.0, null),
      ],
    );
    db.close();

    // Primera apertura: puede rellenar lo que falte (una vez).
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
