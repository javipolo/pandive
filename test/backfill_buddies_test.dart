// Valida backfillBuddyIds() sobre una COPIA TEMPORAL de la .ddb real del
// usuario (nunca el original). Se salta si no existe.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/features/settings/logic/import_site_coords.dart';
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

  test('importSiteCoordsFromJson rellena por nombre/region/country', () {
    final a = db.createSite({'Place': 'ZZZ Abu Test', 'Country': 'Egypt'});
    final b = db.createSite(
        {'Place': 'ZZZ Brother Test', 'Country': 'Egypt', 'Region': 'Brothers'});
    final acc = db.createSite({'Place': 'ZZZ Niño Test'});
    const json = '''[
      {"name":"ZZZ Abu Test","region":null,"country":"Egypt","coordinates":{"latitude":25.3,"longitude":34.7}},
      {"name":"ZZZ Brother Test","region":"Brothers","country":"Egypt","coordinates":{"latitude":26.3,"longitude":34.8}},
      {"name":"ZZZ Brother Test","region":"WrongRegion","country":"Egypt","coordinates":{"latitude":9,"longitude":9}},
      {"name":"ZZZ Nino Test","coordinates":{"latitude":1.5,"longitude":2.5}},
      {"name":"ZZZ Abu Test","country":"Egypt","coordinates":null}
    ]''';
    final n = importSiteCoordsFromJson(db, json);
    expect(n, 3); // Abu, Brother (region correcta), Niño (sin acento) ; null ignorado
    expect(db.getSite(a)!.lat, closeTo(25.3, 1e-4));
    expect(db.getSite(b)!.lon, closeTo(34.8, 1e-4)); // no la de WrongRegion
    expect(db.getSite(acc)!.lat, closeTo(1.5, 1e-4)); // acento-insensible
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
