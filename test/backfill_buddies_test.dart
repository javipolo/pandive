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
}
