// Valida backfillBuddyIds() sobre una COPIA TEMPORAL de la .ddb real del
// usuario (nunca el original). Se salta si no existe.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/settings/logic/import_dives.dart';
import 'package:pandive/features/sites/logic/site_import.dart';
import 'package:pandive/features/sites/logic/export_sites.dart';
import 'package:pandive/features/trips/logic/export_trip.dart';
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

  test('personalRecords: más profundo coherente con computeStats', () {
    final r = db.personalRecords();
    final s = db.computeStats();
    if (s.maxDepth != null) {
      expect(r.deepest, isNotNull);
      expect(r.deepest!.value, closeTo(s.maxDepth!, 0.01));
      expect(r.deepest!.diveId, greaterThan(0));
    }
    if ((s.decoDives ?? 0) > 0 && (s.maxTts ?? 0) > 0) {
      expect(r.longestDeco, isNotNull);
      expect(r.longestDeco!.value, closeTo(s.maxTts!.toDouble(), 0.01));
    }
  });

  test('createSite guarda Lat/Lon y listSites los devuelve', () {
    final id = db.createSite(
        {'Place': 'ZZZ Map Test', 'Lat': '41.123456', 'Lon': '2.654321'});
    final site = db.listSites().firstWhere((s) => s.id == id);
    expect(site.hasCoords, isTrue);
    expect(site.lat, closeTo(41.123456, 1e-5));
    expect(site.lon, closeTo(2.654321, 1e-5));
  });

  test('viajes: crear, asignar buceos/compañeros, listar y borrar', () {
    final dives = db.listDives().take(2).map((d) => d.id).toList();
    expect(dives.length, 2);
    final tripId = db.createTrip('ZZZ Trip Test');
    db.assignDivesToTrip(tripId, dives);

    final trip = db.listTrips().firstWhere((t) => t.id == tripId);
    expect(trip.diveCount, 2);
    expect(db.listDivesByTrip(tripId).length, 2);

    final buddyId = db.listBuddies().first.id;
    db.setTripBuddies(tripId, [buddyId]);
    expect(db.tripBuddies(tripId).map((b) => b.id), contains(buddyId));

    db.deleteTrip(tripId);
    expect(db.listTrips().any((t) => t.id == tripId), isFalse);
    // Los buceos siguen existiendo (solo se desasignan).
    expect(db.listDives().where((d) => dives.contains(d.id)).length, 2);
  });

  test('planSiteImport: add nuevos, modify difiere, null/igual no listan', () {
    final ex = db.createSite({
      'Place': 'ZZZ Plan Exist',
      'Country': 'Egypt',
      'Region': 'Old',
      'Lat': '1.000000',
      'Lon': '2.000000',
    });
    const json = '''[
      {"name":"ZZZ Plan New","region":"R","country":"Spain","coordinates":{"latitude":5.5,"longitude":6.6}},
      {"name":"ZZZ Plan Exist","region":null,"country":"Egypt","coordinates":{"latitude":9.9,"longitude":2.0}}
    ]''';
    final plan = planSiteImport(db, json);
    final add = plan.firstWhere((p) => p.name == 'ZZZ Plan New');
    expect(add.action, SiteImportAction.add);
    final mod = plan.firstWhere((p) => p.name == 'ZZZ Plan Exist');
    expect(mod.action, SiteImportAction.modify);
    expect(mod.existingId, ex);
    // region null no toca; Lon igual no cambia; solo Lat difiere.
    expect(mod.fields.keys.toSet(), {'Lat'});
  });

  test('planSiteImport: sin cambios no se lista', () {
    db.createSite({
      'Place': 'ZZZ Plan Same',
      'Country': 'Egypt',
      'Lat': '3.000000',
      'Lon': '4.000000',
    });
    const json =
        '[{"name":"ZZZ Plan Same","region":null,"country":"Egypt","coordinates":{"latitude":3.0,"longitude":4.0}}]';
    final plan = planSiteImport(db, json);
    expect(plan.any((p) => p.name == 'ZZZ Plan Same'), isFalse);
  });

  test('applySiteImport: add crea, modify pisa solo no-null', () {
    final ex = db.createSite({
      'Place': 'ZZZ Apply Exist',
      'Country': 'Egypt',
      'Region': 'KeepMe',
      'Lat': '1.000000',
    });
    const json = '''[
      {"name":"ZZZ Apply New","region":null,"country":"Spain","coordinates":{"latitude":7.7,"longitude":8.8}},
      {"name":"ZZZ Apply Exist","region":null,"country":"Egypt","coordinates":{"latitude":5.5,"longitude":6.6}}
    ]''';
    final n = applySiteImport(db, planSiteImport(db, json));
    expect(n, 2);
    final created = db.listSites().firstWhere((s) => s.name == 'ZZZ Apply New');
    expect(created.lat, closeTo(7.7, 1e-4));
    expect(created.country, 'Spain');
    final after = db.getSite(ex)!;
    expect(after.lat, closeTo(5.5, 1e-4)); // pisado
    expect(after.region, 'KeepMe'); // null no pisó
  });

  test('sitesToJson: roundtrip no genera cambios', () {
    final id = db.createSite({
      'Place': 'ZZZ Round Trip',
      'Country': 'Malta',
      'Region': 'Gozo',
      'Lat': '36.000000',
      'Lon': '14.000000',
    });
    final site = db.listSites().firstWhere((s) => s.id == id);
    final plan = planSiteImport(db, sitesToJson([site]));
    expect(plan.any((p) => p.name == 'ZZZ Round Trip'), isFalse);
  });

  test('findOrCreateSite rellena coords si faltan y no las pisa', () {
    final id = db.createSite({'Place': 'ZZZ Enrich Site', 'Country': 'X'});
    final again =
        db.findOrCreateSite('ZZZ Enrich Site', country: 'X', lat: 10, lon: 20);
    expect(again, id); // mismo sitio
    expect(db.getSite(id)!.lat, closeTo(10, 1e-4)); // coords rellenadas
    db.findOrCreateSite('ZZZ Enrich Site', country: 'X', lat: 99, lon: 99);
    expect(db.getSite(id)!.lat, closeTo(10, 1e-4)); // no se pisan
  });

  test('purgeUnusedSites borra solo los sitios sin buceos', () {
    final empty = db.createSite({'Place': 'ZZZ Purge Empty'});
    final before = db.listSites().length;
    final n = db.purgeUnusedSites();
    expect(n, greaterThan(0));
    expect(db.getSite(empty), isNull);
    expect(db.listSites().length, before - n);
    expect(db.listSites().every((s) => s.diveCount > 0), isTrue);
  });

  test('tags de sitio: derivados y dinámicos sobre sus buceos', () {
    final site = db.createSite({'Place': 'ZZZ Tag Site'});
    final tagId = db.findOrCreateTag('ZZZ sitetag');
    final diveId = db.listDives().first.id;
    db.updateDive(diveId, {'PlaceID': site});

    // Sin tag en el sitio: no aparece.
    expect(db.effectiveTagsForDive(diveId).any((t) => t.id == tagId), isFalse);

    // Asignar tag al sitio -> aparece en el buceo (efectivo), no en los propios.
    db.setSiteTags(site, [Tag(id: tagId, name: 'ZZZ sitetag')]);
    expect(db.tagsForSite(site).map((t) => t.id), [tagId]);
    // listSites expone los tags (para buscar en la lista de sitios).
    expect(db.listSites().firstWhere((s) => s.id == site).tags,
        contains('ZZZ sitetag'));
    expect(db.effectiveTagsForDive(diveId).any((t) => t.id == tagId), isTrue);
    expect(db.tagsForDive(diveId).any((t) => t.id == tagId), isFalse);
    expect(db.listDivesByTag(tagId).any((d) => d.id == diveId), isTrue);

    // Quitar del sitio -> desaparece al instante (dinámico).
    db.setSiteTags(site, []);
    expect(db.effectiveTagsForDive(diveId).any((t) => t.id == tagId), isFalse);
    expect(db.listDivesByTag(tagId).any((d) => d.id == diveId), isFalse);
  });

  test('diveIdsWithTag incluye buceos por tag de sitio; deleteTag limpia', () {
    final site = db.createSite({'Place': 'ZZZ Cave Site'});
    final tagId = db.findOrCreateTag('ZZZ cavez');
    final diveId = db.listDives().first.id;
    db.updateDive(diveId, {'PlaceID': site});
    db.setSiteTags(site, [Tag(id: tagId, name: 'ZZZ cavez')]);
    expect(db.diveIdsWithTag('ZZZ cavez').contains(diveId), isTrue);

    db.deleteTag(tagId);
    expect(db.tagsForSite(site), isEmpty);
    expect(db.diveIdsWithTag('ZZZ cavez'), isEmpty);
  });

  test('export de viaje: nombre de fichero + .ddb con viaje/buceos/compañeros',
      () async {
    final dives = db.listDives().take(2).map((d) => d.id).toList();
    final tripId = db.createTrip('Egipto 2024');
    db.assignDivesToTrip(tripId, dives);
    db.setTripBuddies(tripId, [db.listBuddies().first.id]);
    final trip = db.listTrips().firstWhere((t) => t.id == tripId);

    final base = tripFileBase(trip, db.listDivesByTrip(tripId));
    expect(base, contains('Egipto 2024'));
    expect(base, endsWith('PanDive'));

    final outPath = '${tmp.path}/out_trip.ddb';
    final out = DivemateDb.createEmpty(outPath);
    await writeTripDdb(db, trip, out, db.listDivesByTrip(tripId));
    out.close();

    final r = DivemateDb.open(outPath);
    final trips = r.listTrips();
    expect(trips.length, 1);
    expect(trips.first.name, 'Egipto 2024');
    expect(r.listDivesByTrip(trips.first.id).length, 2);
    expect(r.tripBuddies(trips.first.id).length, 1);
    r.close();
  });

  test('importDivesFromDb copia buceos de otro ddb y dedupe por fecha/hora', () async {
    final src = DivemateDb.createEmpty('${tmp.path}/src.ddb');
    src.importExternalDive(
        dateTime: DateTime(2099, 1, 1, 10),
        placeName: 'ZZZ Src A',
        buddies: ['ZZZ SrcBuddy']);
    src.importExternalDive(
        dateTime: DateTime(2099, 1, 2, 10), placeName: 'ZZZ Src B');

    src.importExternalDive(
        dateTime: DateTime(2099, 1, 3, 10), placeName: 'ZZZ Src C');
    final c = src.listDives().firstWhere((d) => d.date!.day == 3).id;
    final plan = planDdbImport(db, src);
    expect(plan.where((e) => e.duplicate), isEmpty);

    // Solo los seleccionados (todos menos C).
    final only = {for (final e in plan) if (e.dive.id != c) e.dive.id};
    final r1 = await importDivesFromDb(db, src, only: only);
    expect(r1.imported, 2);
    expect(r1.notSelected, 1);
    expect(r1.duplicates, 0);
    expect(r1.newBuddies, 1);
    expect(r1.newSites, 2);

    // Los ya importados aparecen como duplicados y se ignoran.
    expect(planDdbImport(db, src).where((e) => e.duplicate).length, 2);
    final r2 = await importDivesFromDb(db, src);
    expect(r2.imported, 1); // solo C
    expect(r2.duplicates, 2);
    src.close();

    expect(db.listDives().where((d) => d.date?.year == 2099).length, 3);
  });

  test('export de varios viajes: nombre + ddb con todos los viajes', () async {
    final dives = db.listDives().map((d) => d.id).toList();
    final t1 = db.createTrip('Viaje Uno');
    final t2 = db.createTrip('Viaje Dos');
    db.assignDivesToTrip(t1, [dives[0]]);
    db.assignDivesToTrip(t2, [dives[1]]);
    final trips = [
      db.listTrips().firstWhere((t) => t.id == t1),
      db.listTrips().firstWhere((t) => t.id == t2),
    ];

    final base = tripsFileBase(trips);
    expect(base, endsWith('PanDive'));
    expect(base, contains('Viaje Uno'));

    final out = DivemateDb.createEmpty('${tmp.path}/multi.ddb');
    for (final tr in trips) {
      await writeTripDdb(db, tr, out, db.listDivesByTrip(tr.id));
    }
    out.close();
    final r = DivemateDb.open('${tmp.path}/multi.ddb');
    expect(r.listTrips().length, 2);
    r.close();
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
