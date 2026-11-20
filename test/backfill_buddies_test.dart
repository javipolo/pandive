// Valida backfillBuddyIds() sobre una COPIA TEMPORAL de la .ddb real del
// usuario (nunca el original). Se salta si no existe.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:sqlite3/open.dart';

void main() {
  final src = File(
      '${Platform.environment['HOME']}/.config/divemate-cli/pandive.ddb');
  if (!src.existsSync()) {
    test('backfill skipped (no pandive.ddb)', () {}, skip: true);
    return;
  }

  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  late Directory tmp;
  late DivemateDb db;
  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('pandive_backfill');
    final copy = src.copySync('${tmp.path}/copy.ddb');
    db = DivemateDb.open(copy.path);
  });
  tearDownAll(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  // Nombre único: no debe existir ya como buddy en la DB real.
  const name = 'ZZZ Test Backfill Buddy';
  int divesOf(String n) {
    final m = db.listBuddies().where((b) => b.name == n);
    return m.isEmpty ? 0 : m.first.diveCount;
  }

  test('backfill enlaza un buddy solo-texto y es idempotente', () {
    // Monta el estado: una inmersión con texto Buddy pero sin BuddyIDs
    // (como las importadas de DiveMate), autocontenido (no depende del estado
    // actual de la DB, que puede estar ya enlazada).
    final diveId = db.listDives().first.id;
    db.updateDive(diveId, {'Buddy': name, 'BuddyIDs': ''});
    expect(divesOf(name), 0); // aún sin fila Buddy enlazada

    final updated = db.backfillBuddyIds();
    expect(updated, greaterThan(0));
    expect(divesOf(name), greaterThan(0)); // ya enlazado y cuenta
    expect(db.backfillBuddyIds(), 0); // idempotente
  });

  test('mergeBuddies reasigna dives y borra los fusionados', () {
    db.backfillBuddyIds();
    final withDives =
        db.listBuddies().where((b) => b.diveCount > 0).toList();
    expect(withDives.length, greaterThanOrEqualTo(2));
    final keep = withDives[0];
    final gone = withDives[1];
    final maxExpected = keep.diveCount + gone.diveCount; // tope (sin solape)

    db.mergeBuddies(keep.id, [gone.id]);

    final after = db.listBuddies();
    expect(after.any((b) => b.id == gone.id), isFalse); // fusionado borrado
    final keepAfter = after.firstWhere((b) => b.id == keep.id);
    expect(keepAfter.diveCount, greaterThan(keep.diveCount)); // ganó dives
    expect(keepAfter.diveCount, lessThanOrEqualTo(maxExpected));
  });
}
