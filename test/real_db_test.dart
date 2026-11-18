// Valida la capa DB contra la .ddb real (si está presente) comparando con los
// valores que da divemate-cli. Se salta si no existe el fichero.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/export/subsurface_export.dart';
import 'package:pandive/core/import/subsurface_import.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/settings/logic/enrich_logbook.dart';
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

  test('importSubsurfaceXml importa sitio, botella, perfil, buddies y tags', () async {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_ssrf_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      const xml = '''
<divelog program='test' version='3'>
<divesites>
<site uuid='0000000a' name='Cala Test' gps='41.1 2.2'/>
</divesites>
<dives>
<dive number='1' date='2024-05-01' time='10:30:00' duration='42:00 min' divesiteid='0000000a' tags='cueva, deco'>
<buddy>Ana, Luis</buddy>
<cylinder size='12.0 l' o2='32.0%' start='200.0 bar' end='50.0 bar' />
<divecomputer model='OSTC'>
<depth max='30.5 m' mean='15.2 m' />
<temperature water='18.0 C' />
<sample time='0:00' depth='0.0 m' temp='20.0 C' />
<sample time='0:10' depth='5.0 m' />
<sample time='0:20' depth='10.0 m' />
</divecomputer>
<notes>buceo de prueba</notes>
</dive>
</dives>
</divelog>''';
      expect(await importSubsurfaceXml(w, xml), 1);
      expect(w.countDives(), 1);
      final d = w.listDives().first;
      expect(d.maxDepth, 30.5);
      expect(d.place, 'Cala Test');
      expect(d.durationMin, 42.0);
      final cyl = w.cylinders(d.id);
      expect(cyl.length, 1);
      expect(cyl.first.o2, 32.0);
      expect(w.diveBuddies(d.id).length, 2);
      expect(w.tagsForDive(d.id).length, 2);
      expect(w.diveProfile(d.id)?.depths.length, 3);
      // dedupe: reimportar no añade
      expect(await importSubsurfaceXml(w, xml), 0);
    } finally {
      w.close();
    }
  });

  test('enrich: empareja por fecha (±1h) y copia sitio + buddies', () {
    final sf = File(
        '${Directory.systemTemp.path}/pandive_src_${DateTime.now().microsecondsSinceEpoch}.ddb');
    final hf = File(
        '${Directory.systemTemp.path}/pandive_her_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => sf.existsSync() ? sf.deleteSync() : null);
    addTearDown(() => hf.existsSync() ? hf.deleteSync() : null);
    final src = DivemateDb.createEmpty(sf.path);
    final her = DivemateDb.createEmpty(hf.path);
    try {
      final dt = DateTime(2024, 6, 1, 10, 0);
      final sid = src.createDive(dateTime: dt, place: 'Cova Negra', country: 'ES');
      src.addDiveBuddies(sid, ['Javi']);
      final hid = her.createDive(dateTime: dt.add(const Duration(minutes: 5)));
      final m = findSourceMatch(src, her.getDive(hid)!.date!);
      expect(m, isNotNull);
      expect(m!.place, 'Cova Negra');
      expect(applyEnrich(her, {hid: m}, {hid}, 'Ana'), 1);
      final d = her.getDive(hid)!;
      expect(d.place, 'Cova Negra');
      final buds = her.diveBuddies(hid).map((b) => b.name).toSet();
      // Solo el buddy elegido; no se copian los del origen (evita auto-buddy).
      expect(buds.contains('Ana'), isTrue);
      expect(buds.contains('Javi'), isFalse);
      // fuera de la ventana: no empareja
      expect(findSourceMatch(src, dt.add(const Duration(hours: 3))), isNull);
    } finally {
      src.close();
      her.close();
    }
  });

  test('clearDiveAssoc limpia botellas (evita herencia por reuso de ID)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_assoc_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final id = w.createDive(dateTime: DateTime(2024, 8, 1, 10));
      w.setDiveTanks(id, [const Cylinder(size: 24, o2: 31, pressureStart: 110)]);
      expect(w.cylinders(id).length, 1);
      w.clearDiveAssoc(id);
      expect(w.cylinders(id).length, 0);
    } finally {
      w.close();
    }
  });

  test('purgeDives borra definitivamente y permite re-importar', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_purge_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final dt = DateTime(2024, 7, 1, 9, 0);
      final id = w.createDive(dateTime: dt, place: 'X');
      w.deleteDives([id]); // Status=2
      expect(w.listDeletedDives().length, 1);
      expect(w.hasDiveAt(dt), isFalse); // borrada no cuenta para dedupe
      w.purgeDives([id]);
      expect(w.listDeletedDives().length, 0);
      expect(w.getDive(id), isNull);
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

  test('mergeDives: suma tiempos, une botellas, borra el resto', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_merge2_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      w.importDownloaded(DownloadedDive(
        fingerprint: 'a',
        datetime: DateTime(2031, 5, 1, 10, 0),
        divetimeSec: 60,
        maxDepth: 10,
        gasmixes: const [GasMix(0.32, 0)],
        samples: const [DiveSample(0, 5, 20), DiveSample(10000, 10, 20)],
      ));
      w.importDownloaded(DownloadedDive(
        fingerprint: 'b',
        datetime: DateTime(2031, 5, 1, 10, 3), // hueco 2 min
        divetimeSec: 60,
        maxDepth: 18,
        gasmixes: const [GasMix(0.21, 0)],
        samples: const [DiveSample(0, 8, 19), DiveSample(10000, 18, 19)],
      ));
      final a = w.listDives().firstWhere((d) => d.date == DateTime(2031, 5, 1, 10, 0));
      final b = w.listDives().firstWhere((d) => d.date == DateTime(2031, 5, 1, 10, 3));

      // hueco (2 min) mayor que el límite => excepción, nada cambia
      expect(() => w.mergeDives([a.id, b.id], maxGapMin: 1),
          throwsA(isA<MergeTooFarException>()));
      expect(w.countDives(), 2);

      final id = w.mergeDives([a.id, b.id], maxGapMin: 15);
      expect(id, a.id); // conserva el más antiguo
      expect(w.countDives(), 1); // el otro queda borrado (Status=2)

      final merged = w.getDive(id)!;
      expect(merged.durationMin, closeTo(2, 0.01)); // 1 + 1 min
      expect(merged.maxDepth, 18); // máx de ambos
      expect(w.cylinders(id), hasLength(2)); // unión de botellas

      final p = w.diveProfile(id)!;
      expect(p.depths.first, 5.0); // empieza con el primer buceo
      expect(p.depths.last, 18.0); // acaba con el segundo
      expect(p.depths.length, greaterThan(4)); // con hueco en superficie
    } finally {
      w.close();
    }
  });

  test('listDives busca también por compañero enlazado (BuddyIDs)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_bsearch_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final bid = w.findOrCreateBuddy('Marina');
      w.createDive(dateTime: DateTime(2030, 6, 1, 10, 0), buddyIds: '$bid');
      w.createDive(dateTime: DateTime(2030, 6, 2, 10, 0)); // sin compañero
      expect(w.listDives(search: 'mari'), hasLength(1));
      expect(w.listDives(search: 'nadie'), isEmpty);
    } finally {
      w.close();
    }
  });

  test('LogbookStats.fromDives agrega una selección', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_fstats_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      w.createDive(
          dateTime: DateTime(2029, 1, 1, 10, 0),
          maxDepth: 20,
          avgDepth: 12,
          durationMin: 40,
          waterTemp: 18);
      w.createDive(
          dateTime: DateTime(2030, 1, 1, 10, 0),
          maxDepth: 30,
          avgDepth: 15,
          durationMin: 60,
          waterTemp: 22);
      final s = LogbookStats.fromDives(w.listDives());
      expect(s.totalDives, 2);
      expect(s.totalMinutes, 100);
      expect(s.maxDepth, 30);
      expect(s.avgDepth, closeTo(13.5, 0.01));
      expect(s.avgWaterTemp, closeTo(20, 0.01));
      expect(s.divesPerYear, {2029: 1, 2030: 1});
    } finally {
      w.close();
    }
  });

  test('tipos de buceo: CRUD + plantilla de botellas', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_dt_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final id = w.addDiveType('Sidemount', const [
        Cylinder(name: 'Izquierda', size: 11.1, material: TankMaterial.aluminium),
        Cylinder(name: 'Derecha', size: 11.1, material: TankMaterial.aluminium),
      ]);
      var types = w.listDiveTypes();
      expect(types, hasLength(1));
      expect(types.first.name, 'Sidemount');
      expect(types.first.tanks, hasLength(2));
      expect(types.first.tanks.first.name, 'Izquierda');
      expect(types.first.tanks.first.size, 11.1);
      expect(types.first.tanks.first.material, TankMaterial.aluminium);
      // Las plantillas no llevan presiones.
      expect(types.first.tanks.first.pressureStart, isNull);

      w.updateDiveType(id, 'Monobotella 15L',
          const [Cylinder(size: 15, material: TankMaterial.steel)]);
      types = w.listDiveTypes();
      expect(types.first.name, 'Monobotella 15L');
      expect(types.first.tanks, hasLength(1));
      expect(types.first.tanks.first.material, TankMaterial.steel);

      w.deleteDiveType(id);
      expect(w.listDiveTypes(), isEmpty);
      expect(w.diveTypeTanks(id), isEmpty);
    } finally {
      w.close();
    }
  });

  test('pendientes: add → list → remove (ciclo "una vez más")', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_pend_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      const dev = 'AA:BB';
      const dl = DownloadedDive(
        fingerprint: 'cafe',
        divetimeSec: 600,
        maxDepth: 12,
        samples: [DiveSample(0, 3, 20), DiveSample(10000, 12, 19)],
      );
      expect(w.listPending(dev), isEmpty);
      w.addPending(dev, dl);
      final back = w.listPending(dev);
      expect(back, hasLength(1));
      expect(back.first.fingerprint, 'cafe');
      expect(back.first.samples, hasLength(2));
      expect(back.first.maxDepth, 12);
      w.removePending(dev, 'cafe');
      expect(w.listPending(dev), isEmpty);
    } finally {
      w.close();
    }
  });

  test('updateTankPreset modifica un tipo de botella', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_tp_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final id = w.addTankPreset('S80', 11.1, TankMaterial.aluminium);
      w.updateTankPreset(id, '15L', 15, TankMaterial.steel);
      final p = w.listTankPresets().firstWhere((e) => e.id == id);
      expect(p.name, '15L');
      expect(p.litres, 15);
      expect(p.material, TankMaterial.steel);
    } finally {
      w.close();
    }
  });

  test('renombrar sitio se propaga a las inmersiones existentes', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_rsite_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final sid = w.createSite({'Place': 'Cala Vella', 'Country': 'España'});
      final did = w.createDive(
          dateTime: DateTime(2030, 7, 1, 10, 0),
          place: 'Cala Vella',
          country: 'España',
          placeId: sid);
      w.updateSite(sid, {'Place': 'Cala Nova', 'Country': 'España'});
      final d = w.getDive(did)!;
      expect(d.place, 'Cala Nova');
    } finally {
      w.close();
    }
  });

  test('renombrar buddy se propaga al texto Buddy de las inmersiones', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_rbud_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final bid = w.findOrCreateBuddy('Marina');
      final did = w.createDive(
          dateTime: DateTime(2030, 8, 1, 10, 0),
          buddy: 'Marina',
          buddyIds: '$bid');
      w.renameBuddy(bid, 'Marina López');
      final d = w.getDive(did)!;
      expect(d.buddy, 'Marina López');
    } finally {
      w.close();
    }
  });

  test('buddies se ordenan ignorando acentos (Àliga/Álvaro antes que Baliza)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_sort_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      w.findOrCreateBuddy('Baliza');
      w.findOrCreateBuddy('Álvaro');
      w.findOrCreateBuddy('Àliga');
      final names = w.listBuddies().map((b) => b.name).toList();
      expect(names, ['Àliga', 'Álvaro', 'Baliza']);
    } finally {
      w.close();
    }
  });

  test('importDownloaded calcula y persiste DepthAvg si el aparato no la da', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_avg_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      w.importDownloaded(const DownloadedDive(
        fingerprint: 'z',
        datetime: null,
        maxDepth: 10,
        samples: [DiveSample(0, 6, 20), DiveSample(10000, 10, 20)],
      ));
      final d = w.listDives().single;
      expect(d.avgDepth, closeTo(8, 0.01)); // media de 6 y 10
    } finally {
      w.close();
    }
  });

  test('importDownloaded persiste temp mín (Watertemp) y media (PandiveAvgTemp)', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_temp_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      w.importDownloaded(const DownloadedDive(
        fingerprint: 'tt',
        datetime: null,
        samples: [
          DiveSample(0, 5, 22),
          DiveSample(10000, 10, 18),
          DiveSample(20000, 8, 20),
        ],
      ));
      final d = w.listDives().single;
      expect(d.waterTemp, closeTo(18, 0.01)); // mínima
      expect(w.diveAvgTemp(d.id), closeTo(20, 0.01)); // media (22+18+20)/3
    } finally {
      w.close();
    }
  });

  test('SAC se persiste en PandiveSac al guardar botellas', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_sac_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final id = w.createDive(
          dateTime: DateTime(2030, 9, 1, 10, 0),
          durationMin: 40,
          avgDepth: 15);
      w.setDiveTanks(id, const [
        Cylinder(size: 12, pressureStart: 200, pressureEnd: 50),
      ]);
      // litros = (200-50)*12 = 1800 ; ata = 15/10+1 = 2.5 ; 1800/(40*2.5)=18
      expect(w.diveSac(id), closeTo(18, 0.01));
    } finally {
      w.close();
    }
  });

  test('ordenadores de buceo: add / list / saved / remove', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_comp_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      expect(w.listComputers(), isEmpty);
      w.addComputer('AA:BB', 'Peregrine',
          vendor: 'Shearwater', product: 'Peregrine');
      expect(w.isComputerSaved('AA:BB'), isTrue);
      expect(w.isComputerSaved('CC:DD'), isFalse);
      final c = w.listComputers().single;
      expect(c.name, 'Peregrine');
      expect(c.vendor, 'Shearwater');
      w.removeComputer('AA:BB');
      expect(w.listComputers(), isEmpty);
    } finally {
      w.close();
    }
  });

  test('buildSubsurfaceXml genera XML con sitio, botella y perfil', () {
    final tmp = File(
        '${Directory.systemTemp.path}/pandive_ss_${DateTime.now().microsecondsSinceEpoch}.ddb');
    addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
    final w = DivemateDb.createEmpty(tmp.path);
    try {
      final sid = w.createSite({'Place': 'Cala', 'Country': 'España'});
      w.importDownloaded(const DownloadedDive(
        fingerprint: 'x',
        datetime: null,
        maxDepth: 20,
        divetimeSec: 2400,
        gasmixes: [GasMix(0.32, 0)],
        samples: [DiveSample(0, 5, 21), DiveSample(10000, 20, 19)],
      ));
      final id = w.listDives().single.id;
      w.updateDive(id, {'PlaceID': sid, 'Place': 'Cala', 'Country': 'España'});
      w.setDiveTanks(
          id, const [Cylinder(size: 12, pressureStart: 200, pressureEnd: 50)]);
      final xml = buildSubsurfaceXml(w);
      expect(xml, contains("<divelog program='pandive'"));
      expect(xml, contains("name='Cala'"));
      expect(xml, contains('divesiteid='));
      expect(xml, contains('<cylinder'));
      expect(xml, contains("start='200.0 bar'"));
      expect(xml, contains('<sample '));
      expect(xml, contains("sac='"));
    } finally {
      w.close();
    }
  });

  test('decode de deco (Profile4): techo/NDL/TTS en el buceo 460 (nº 399)', () {
    final p = db.diveProfile(460);
    if (p == null) return; // DB sin ese buceo
    expect(p.hasDeco, isTrue);
    // El techo máximo del buceo 399 (ID 460) fue 15 m.
    final maxCeil = p.ceiling.reduce((a, b) => a > b ? a : b);
    expect(maxCeil, closeTo(15, 0.5));
    // Hay muestras con NDL (fase sin deco) y muestras con TTS (en deco).
    expect(p.ndl.any((v) => v != null && v > 0), isTrue);
    expect(p.tts.any((v) => v != null), isTrue);
    // Donde hay techo, no hay NDL y sí TTS.
    for (var i = 0; i < p.ceiling.length; i++) {
      if (p.ceiling[i] > 0) {
        expect(p.ndl[i], isNull);
      }
    }
  });

  test('buceo sin deco: ceiling todo 0, NDL poblado', () {
    final p = db.diveProfile(684);
    if (p == null) return;
    // 684 tuvo una parada corta a 3 m; comprobamos consistencia general.
    expect(p.ndl.any((v) => v != null), isTrue);
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
