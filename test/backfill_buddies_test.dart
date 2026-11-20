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

  int guillemDives() => db
      .listBuddies()
      .firstWhere((b) => b.name == 'Guillem de Castro')
      .diveCount;

  test('Guillem de Castro empieza con 0 buceos (solo texto)', () {
    expect(guillemDives(), 0);
  });

  test('backfill enlaza las dives antiguas y es idempotente', () {
    final updated = db.backfillBuddyIds();
    expect(updated, greaterThan(0));
    expect(guillemDives(), greaterThan(0));
    // Segunda pasada: nada que hacer.
    expect(db.backfillBuddyIds(), 0);
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
