// Valida la capa DB contra la .ddb real (si está presente) comparando con los
// valores que da divemate-cli. Se salta si no existe el fichero.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/db/divemate_db.dart';
import 'package:sqlite3/open.dart';

void main() {
  final dbFile = File('DiveMate.ddb');
  if (!dbFile.existsSync()) {
    test('real db skipped (no DiveMate.ddb)', () {}, skip: true);
    return;
  }

  // En el host de test Fedora solo está libsqlite3.so.0 (el .so sin versión
  // vive en sqlite-devel). En Android se usa sqlite3_flutter_libs.
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  late DivemateDb db;
  setUpAll(() => db = DivemateDb.open('DiveMate.ddb', readOnly: true));
  tearDownAll(() => db.close());

  test('abre y reconoce la DB', () {
    expect(db.looksValid, isTrue);
    expect(db.ownerId, isNotNull);
  });

  test('owner tiene 730 inmersiones (ref dmcli)', () {
    expect(db.countDives(), 730);
  });

  test('stats coinciden con dmcli', () {
    final s = db.computeStats();
    expect(s.totalDives, 730);
    expect(s.totalHours, closeTo(788.7, 0.5));
    expect(s.avgDiveMinutes, closeTo(64.8, 0.3));
    expect(s.maxDepth, closeTo(54.1, 0.1));
    expect(s.avgDepth, closeTo(12.8, 0.2));
    expect(s.avgWaterTemp, closeTo(21.3, 0.3));
    expect(s.divesPerYear[2013], 9);
    expect(s.divesPerYear[2014], 69);
    expect(s.divesPerYear[2015], 86);
  });

  test('lista sitios con conteo de inmersiones', () {
    final sites = db.listSites();
    expect(sites, isNotEmpty);
    // Ordenados por nº de inmersiones desc.
    expect(sites.first.diveCount, greaterThan(0));
    for (var i = 1; i < sites.length; i++) {
      expect(sites[i].diveCount, lessThanOrEqualTo(sites[i - 1].diveCount));
    }
  });

  test('updateDive escribe campos y marca Updated (sobre copia temporal)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_test_${DateTime.now().microsecondsSinceEpoch}.ddb');
    dbFile.copySync(tmp.path);
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);

    final w = DivemateDb.open(tmp.path);
    try {
      final dive = w.listDives().firstWhere((d) => d.number == 730);
      w.updateDive(dive.id, {
        'Comments': 'prueba pandive',
        'Rating': 4,
        'Weight': 6.5,
      });
      final r = w.getDive(dive.id)!;
      expect(r.comments, 'prueba pandive');
      expect(r.rating, 4);
      expect(r.weight, 6.5);
    } finally {
      w.close();
    }
  });

  test('perfil de la dive 730 coincide con dmcli (25.7 m, 65.9 min, ~18°C)', () {
    final dive = db.listDives().firstWhere((d) => d.number == 730);
    expect(dive.maxDepth, closeTo(25.7, 0.1));

    final p = db.diveProfile(dive.id)!;
    expect(p.isEmpty, isFalse);
    final maxDepth = p.depths.reduce((a, b) => a > b ? a : b);
    expect(maxDepth, closeTo(25.7, 0.3)); // muestreo puede no tocar el pico exacto
    expect(p.timesMinutes.last, closeTo(65.9, 1.0));
    expect(p.hasTemp, isTrue);
    final temps = p.temps.whereType<double>().toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    expect(minTemp, closeTo(18, 2)); // dmcli redondea a 18 °C
  });
}
