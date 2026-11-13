// Valida la capa DB contra la .ddb real (si está presente) comparando con los
// valores que da divemate-cli. Se salta si no existe el fichero.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
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

  test('createDive añade inmersión con Number siguiente (copia temporal)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_new_${DateTime.now().microsecondsSinceEpoch}.ddb');
    dbFile.copySync(tmp.path);
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);

    final w = DivemateDb.open(tmp.path);
    try {
      final before = w.countDives();
      final nextNum = w.nextDiveNumber();
      expect(nextNum, 731); // owner tenía hasta la 730

      final id = w.createDive(
        dateTime: DateTime(2026, 11, 12, 10, 30),
        place: 'Sitio de prueba',
        country: 'España',
        maxDepth: 30.5,
        durationMin: 45,
        waterTemp: 19,
        rating: 5,
      );
      w.setDiveTanks(id, const [
        Cylinder(size: 12, pressureStart: 200, pressureEnd: 50, o2: 32),
      ]);
      expect(id, greaterThan(0));
      expect(w.countDives(), before + 1);

      final created = w.getDive(id)!;
      expect(created.number, 731);
      expect(created.place, 'Sitio de prueba');
      expect(created.maxDepth, 30.5);
      expect(created.rating, 5);

      final cyls = w.cylinders(id);
      expect(cyls, hasLength(1));
      expect(cyls.first.size, 12);
      expect(cyls.first.gasLabel, 'Nitrox EAN32');
    } finally {
      w.close();
    }
  });

  test('createEmpty crea una DB válida y vacía', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_new_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      expect(w.looksValid, isTrue);
      expect(w.countDives(), 0);
      expect(w.nextDiveNumber(), 1);
      // se puede importar en ella
      final ok = w.importDownloaded(
        const DownloadedDive(
          fingerprint: 'x',
          samples: [DiveSample(0, 3, 21), DiveSample(10000, 5, 21)],
        ),
      );
      expect(ok, isTrue);
      expect(w.countDives(), 1);
      // fingerprint vive en la DB: nueva => vacío; roundtrip
      expect(w.fingerprintFor('AA:BB'), isNull);
      w.setFingerprintFor('AA:BB', 'cafe');
      expect(w.fingerprintFor('AA:BB'), 'cafe');
    } finally {
      w.close();
    }
  });

  test('importHashtagsFromComments crea y asigna tags', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_tags_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final id = w.createDive(
        dateTime: DateTime(2030, 1, 1, 10, 0),
        comments: 'Buceo guapo #sidemount en #cueva',
      );
      final added = w.importHashtagsFromComments();
      expect(added, 2);
      final names = w.tagsForDive(id).map((t) => t.name).toSet();
      expect(names, {'sidemount', 'cueva'});
      // idempotente
      expect(w.importHashtagsFromComments(), 0);
    } finally {
      w.close();
    }
  });

  test('importDownloaded guarda perfil y deduplica (copia temporal)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_imp_${DateTime.now().microsecondsSinceEpoch}.ddb');
    dbFile.copySync(tmp.path);
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);

    final w = DivemateDb.open(tmp.path);
    try {
      final dl = DownloadedDive(
        fingerprint: 'deadbeef',
        datetime: DateTime(2031, 3, 4, 9, 30),
        divetimeSec: 1800,
        maxDepth: 10,
        avgDepth: 7,
        tempMin: 19,
        gasmixes: const [GasMix(0.32, 0)],
        samples: const [
          DiveSample(0, 5, 20),
          DiveSample(10000, 10, 19),
          DiveSample(20000, 8, null),
        ],
      );
      final before = w.countDives();
      expect(w.importDownloaded(dl, computer: 'Shearwater Peregrine'), isTrue);
      expect(w.countDives(), before + 1);
      // re-import: dedupe por fecha/hora
      expect(w.importDownloaded(dl, computer: 'Shearwater Peregrine'), isFalse);
      expect(w.countDives(), before + 1);

      final dive = w.listDives().firstWhere((d) => d.date == DateTime(2031, 3, 4, 9, 30));
      expect(dive.maxDepth, 10);
      expect(dive.computer, 'Shearwater Peregrine');
      final p = w.diveProfile(dive.id)!;
      expect(p.intervalSeconds, 10);
      expect(p.depths, [5.0, 10.0, 8.0]);
      expect(p.temps[0], 20);
      expect(p.temps[1], 19);
      expect(p.temps[2], isNull);
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
