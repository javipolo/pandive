// Exporting selected dives to .ddb and importing them into another logbook
// keeps the dive data (not just date/time and site).
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/logic/export_selection.dart';
import 'package:pandive/features/settings/logic/import_dives.dart';
import 'package:sqlite3/open.dart';

void main() {
  late Directory tmp;
  late DivemateDb src;

  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_expsel');
    src = DivemateDb.createEmpty('${tmp.path}/src.ddb');
    src.importExternalDive(
      dateTime: DateTime(2025, 6, 1, 10, 30),
      placeName: 'Medas',
      lat: 42.05,
      lon: 3.22,
      comments: 'Mero enorme',
      buddies: ['Ana'],
      tagNames: ['cueva'],
      maxDepth: 25.7,
      durationMin: 50,
      waterTemp: 18,
      computer: 'Perdix',
      samples: [
        for (var i = 0; i <= 10; i++)
          DiveSample(i * 60000, i == 0 || i == 10 ? 0 : 20, 18),
      ],
      cylinders: const [Cylinder(size: 12)],
    );
    src.importExternalDive(dateTime: DateTime(2025, 6, 2, 10), placeName: 'X');
  });
  tearDown(() {
    src.close();
    tmp.deleteSync(recursive: true);
  });

  Future<DivemateDb> roundTrip({required bool withProfiles}) async {
    final picked = src.listDives().where((d) => d.date!.day == 1).toList();
    final out = DivemateDb.createEmpty('${tmp.path}/out.ddb');
    await writeSelectionDdb(src, out, picked, withProfiles: withProfiles);
    final dst = DivemateDb.createEmpty('${tmp.path}/dst.ddb');
    final r = await importDivesFromDb(dst, out);
    out.close();
    expect(r.imported, 1);
    return dst;
  }

  test('exporta los datos completos del buceo, no solo fecha y sitio',
      () async {
    final dst = await roundTrip(withProfiles: false);
    final d = dst.listDives().single;
    expect(d.date, DateTime(2025, 6, 1, 10, 30));
    expect(d.place, 'Medas');
    expect(d.maxDepth, closeTo(25.7, 0.01));
    expect(d.durationMin, closeTo(50, 0.01));
    expect(d.waterTemp, closeTo(18, 0.01));
    expect(d.comments, 'Mero enorme');
    expect(d.computer, 'Perdix');
    expect(dst.diveBuddies(d.id).map((b) => b.name), ['Ana']);
    expect(dst.tagsForDive(d.id).map((t) => t.name), ['cueva']);
    expect(dst.cylinders(d.id), hasLength(1));
    expect(dst.getSite(d.placeId!)!.lat, closeTo(42.05, 1e-4));
    expect(dst.diveProfile(d.id), isNull); // profiles off
    dst.close();
  });

  test('con perfiles, el perfil también viaja', () async {
    final dst = await roundTrip(withProfiles: true);
    final d = dst.listDives().single;
    expect(dst.diveProfile(d.id)!.depths.length, greaterThan(5));
    dst.close();
  });
}
