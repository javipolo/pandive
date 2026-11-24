// Numeración automática: consecutiva, cronológica, desde el primer número.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:sqlite3/open.dart';

void main() {
  late Directory tmp;
  late DivemateDb db;

  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_num');
    DivemateDb.createEmpty('${tmp.path}/a.ddb').close();
    db = DivemateDb.open('${tmp.path}/a.ddb');
  });
  tearDown(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  // Números en orden cronológico.
  List<int?> numbers() => db.listDives().reversed.map((d) => d.number).toList();

  test('buceo añadido a posteriori: renumera y queda en orden', () {
    db.createDive(dateTime: DateTime(2024, 1, 1, 10)); // 1
    db.createDive(dateTime: DateTime(2024, 1, 3, 10)); // 2
    db.createDive(dateTime: DateTime(2024, 1, 2, 10)); // 3, pero va en medio
    final mid = db.listDives()[1].id;
    expect(db.isOutOfOrder(mid), isTrue);
    expect(db.renumberPlan().length, 2);
    expect(db.autoRenumber(), 2);
    expect(numbers(), [1, 2, 3]);
    expect(db.isOutOfOrder(mid), isFalse);
  });

  test('borrar uno cierra el hueco; restaurarlo lo devuelve a su sitio', () {
    for (var d = 1; d <= 4; d++) {
      db.createDive(dateTime: DateTime(2024, 1, d, 10));
    }
    final second = db.listDives().reversed.elementAt(1).id;
    db.deleteDives([second]);
    db.autoRenumber();
    expect(numbers(), [1, 2, 3]);
    db.restoreDives([second]);
    db.autoRenumber();
    expect(numbers(), [1, 2, 3, 4]);
    expect(db.getDive(second)!.number, 2);
  });

  test('primer número: por defecto el mínimo actual, y al cambiarlo renumera',
      () {
    db.createDive(dateTime: DateTime(2024, 1, 1, 10), number: 87);
    db.createDive(dateTime: DateTime(2024, 1, 2, 10), number: 90);
    expect(db.firstNumber, 87);
    db.autoRenumber();
    expect(numbers(), [87, 88]);
    expect(db.setFirstNumber(1), 2);
    expect(numbers(), [1, 2]);
  });

  test('borrar el primero no mueve el primer número', () {
    db.createDive(dateTime: DateTime(2024, 1, 1, 10), number: 10);
    db.createDive(dateTime: DateTime(2024, 1, 2, 10), number: 11);
    db.deleteDives([db.listDives().last.id]);
    db.autoRenumber();
    db.purgeDives([db.listDeletedDives().first.id]);
    db.autoRenumber();
    expect(numbers(), [10]);
  });

  test('desactivada: no renumera; cambiarla mueve el sello de sync', () {
    db.createDive(dateTime: DateTime(2024, 1, 2, 10));
    db.createDive(dateTime: DateTime(2024, 1, 1, 10));
    final before = db.lastWriteRaw;
    sleep(const Duration(milliseconds: 5));
    db.setAutoNumber(false);
    expect(db.autoNumber, isFalse);
    expect(db.lastWriteRaw, isNot(before));
    expect(db.autoRenumber(), 0);
    expect(numbers(), [2, 1]);
    expect(db.setAutoNumber(true), 2);
    expect(numbers(), [1, 2]);
  });

  test('número de un buceo nuevo según su fecha', () {
    db.createDive(dateTime: DateTime(2024, 1, 1, 10));
    db.createDive(dateTime: DateTime(2024, 1, 3, 10));
    expect(db.numberForNewDive(DateTime(2024, 1, 2, 9)), 2);
    expect(db.numberForNewDive(DateTime(2024, 2, 1)), 3);
  });
}
