// Ports (db_ports.dart): list with usage, trip departure/arrival, per-dive
// port, delete unlinks, and the trip export carries them.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/features/trips/logic/export_trip.dart';
import 'package:sqlite3/open.dart';

void main() {
  late Directory tmp;
  late DivemateDb db;

  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_ports');
    final path = '${tmp.path}/a.ddb';
    DivemateDb.createEmpty(path).close();
    db = DivemateDb.open(path);
  });
  tearDown(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  test('trip ports, dive port and usage count', () {
    final balis = db.createPort('Port Balís', lat: 41.55, lon: 2.51);
    final mataro = db.createPort('Mataró');
    final trip = db.createTrip('Medes');
    db.setTripPorts(trip, departureId: balis, arrivalId: balis);
    final dive = db.createDive(dateTime: DateTime(2024, 6, 1, 10));
    db.setDivePort(dive, mataro);

    final p = db.tripPorts(trip);
    expect(p.departure?.name, 'Port Balís');
    expect(p.arrival?.id, balis);
    expect(db.portForDive(dive)?.name, 'Mataró');
    expect({for (final x in db.listPorts()) x.name: x.useCount},
        {'Mataró': 1, 'Port Balís': 1});
    expect(db.getPort(mataro)?.hasCoords, isFalse);
  });

  test('a trip without ports and deleting a port unlinks it', () {
    final trip = db.createTrip('Shore');
    expect(db.tripPorts(trip).departure, isNull);
    final port = db.createPort('X');
    final dive = db.createDive(dateTime: DateTime(2024, 6, 1, 10));
    db.setDivePort(dive, port);
    db.setTripPorts(trip, departureId: port);
    db.deletePort(port);
    expect(db.portForDive(dive), isNull);
    expect(db.tripPorts(trip).departure, isNull);
    expect(db.listPorts(), isEmpty);
  });

  test('findOrCreatePort reuses by name and fills a missing position', () {
    final id = db.createPort('Estartit');
    expect(db.findOrCreatePort('estartit', lat: 42.05, lon: 3.2), id);
    expect(db.getPort(id)?.lat, 42.05);
  });

  test('trip export copies the trip ports and the dive ports', () async {
    final dep = db.createPort('Port Balís', lat: 41.55, lon: 2.51);
    final divePort = db.createPort('Mataró', lat: 41.53, lon: 2.44);
    final tripId = db.createTrip('Medes');
    db.setTripPorts(tripId, departureId: dep, arrivalId: dep);
    final dive = db.createDive(dateTime: DateTime(2024, 6, 1, 10));
    db.setDivePort(dive, divePort);
    db.assignDivesToTrip(tripId, [dive]);

    final out = DivemateDb.createEmpty('${tmp.path}/out.ddb');
    final trip = db.listTrips().single;
    await writeTripDdb(db, trip, out, db.listDivesByTrip(tripId));
    final outTrip = out.listTrips().single;
    final ports = out.tripPorts(outTrip.id);
    expect(ports.departure?.name, 'Port Balís');
    expect(ports.arrival?.id, ports.departure?.id);
    final outDive = out.listDivesByTrip(outTrip.id).single;
    expect(out.portForDive(outDive.id)?.lat, 41.53);
    out.close();
  });
}
