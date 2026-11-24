// Sync capa 1: tabla de decisión e instantánea consistente con su sello.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/sync_logic.dart';
import 'package:sqlite3/open.dart';

SyncAction d({
  String? baseMd5 = 'm1',
  String? baseStamp = 's1',
  String? localStamp = 's1',
  bool localEmpty = false,
  bool remoteExists = true,
  String? remoteMd5 = 'm1',
}) =>
    decideSync(SyncObservation(
      baseMd5: baseMd5,
      baseStamp: baseStamp,
      localStamp: localStamp,
      localEmpty: localEmpty,
      remoteExists: remoteExists,
      remoteMd5: remoteMd5,
    ));

void main() {
  group('decideSync', () {
    test('nada cambió', () => expect(d(), SyncAction.none));
    test('solo yo', () => expect(d(localStamp: 's2'), SyncAction.upload));
    test('solo el otro', () => expect(d(remoteMd5: 'm2'), SyncAction.download));
    test('los dos -> divergencia',
        () => expect(d(localStamp: 's2', remoteMd5: 'm2'), SyncAction.diverged));
    test('sin fichero en Drive -> subir',
        () => expect(d(remoteExists: false, remoteMd5: null), SyncAction.upload));
    test('dispositivo nuevo vacío -> adopta Drive',
        () => expect(d(baseMd5: null, baseStamp: null, localEmpty: true),
            SyncAction.download));
    test('dispositivo nuevo con datos -> preguntar',
        () => expect(d(baseMd5: null, baseStamp: null), SyncAction.diverged));
    test('restaurar un backup viejo cuenta como cambio local',
        () => expect(d(localStamp: 's0'), SyncAction.upload));
  });

  test('snapshotTo: copia consistente con el mismo sello, sin escribir',
      () {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    final tmp = Directory.systemTemp.createTempSync('pandive_snap');
    addTearDown(() => tmp.deleteSync(recursive: true));
    DivemateDb.createEmpty('${tmp.path}/a.ddb').close();
    final db = DivemateDb.open('${tmp.path}/a.ddb');
    db.createTrip('Viaje');
    final stamp = db.lastWriteRaw;
    db.snapshotTo('${tmp.path}/snap.ddb');
    expect(db.lastWriteRaw, stamp); // la instantánea no cuenta como escritura
    db.close();

    final snap = DivemateDb.open('${tmp.path}/snap.ddb', readOnly: true);
    expect(snap.lastWriteRaw, stamp);
    expect(snap.listTrips().map((t) => t.name), contains('Viaje'));
    snap.close();
  });
}
