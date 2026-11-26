// Batch edits over a selection: dive type and own tags (db_bulk.dart).
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:sqlite3/open.dart';

void main() {
  late Directory tmp;
  late DivemateDb db;

  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_bulk');
    final path = '${tmp.path}/a.ddb';
    DivemateDb.createEmpty(path).close();
    db = DivemateDb.open(path);
  });
  tearDown(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  List<int> dives(int n) => [
        for (var i = 1; i <= n; i++)
          db.createDive(dateTime: DateTime(2024, 1, i, 10))
      ];
  String? typeOf(int id) => db.getDive(id)?.diveType;

  test('sets and clears the dive type, counting only real changes', () {
    final ids = dives(3);
    db.updateDive(ids[0], {'Divetype': 'Cave'});
    expect(db.setDivesType(ids, 'Cave'), 2);
    expect(ids.map(typeOf), everyElement('Cave'));
    expect(db.setDivesType(ids.sublist(1), null), 2);
    expect(ids.map(typeOf), ['Cave', null, null]);
  });

  test('adds a tag only where missing and removes only the own link', () {
    final ids = dives(3);
    final tag = db.findOrCreateTag('Night');
    db.setDiveTags(ids[0], [db.listTags().first]);
    expect(db.addTagToDives(tag, ids), 2);
    expect(db.ownTagCounts(ids).single.$2, 3);
    expect(db.removeTagFromDives(tag, ids.sublist(0, 2)), 2);
    expect(db.ownTagCounts(ids).single.$2, 1);
    expect(db.tagsForDive(ids[2]).map((t) => t.name), ['Night']);
  });

  test('ownTagCounts ignores dives outside the selection', () {
    final ids = dives(2);
    final a = db.findOrCreateTag('A');
    db.addTagToDives(a, [ids[1]]);
    expect(db.ownTagCounts([ids[0]]), isEmpty);
    expect(db.ownTagCounts([]), isEmpty);
  });
}
