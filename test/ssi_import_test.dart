// Importación del CSV de MySSI (columnas por posición, cabecera localizada).
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/ssi_csv_import.dart';
import 'package:sqlite3/open.dart';

const _header = '"inmersión #","Lugar de buceo","País","Fecha / Tiempo",'
    '"Tipo de actividad de buceo","Inmersión de especialidad",'
    '"Tipo de inmersión","Duración","Profundidad",'
    '"Compañero de buceo / Instructor / Center"\n';

String _row(int n, String site, String date, String min, String depth,
        [String buddy = '']) =>
    '"$n","$site","España","$date","Buceo","Inmersión desde embarcación",'
    '"Inmersión de ocio","$min","$depth","$buddy"\n';

void main() {
  group('parseo', () {
    test('fila real de MySSI (hora, compañero, tabs en la profundidad)', () {
      final p = parseSsiCsv('$_header"1","El Fitó / Tres Pics","España",'
          '"15. Apr 2026 19:59","Buceo","Inmersión desde embarcación",'
          '"Inmersión de ocio","56 min","21 m \t\t\t\t(69 ft)","Ana Pérez"');
      expect(p.skipped, 0);
      final d = p.dives.single;
      expect(d.number, 1);
      expect(d.date, DateTime(2026, 4, 15, 19, 59));
      expect(d.hasTime, isTrue);
      expect(d.site, 'El Fitó / Tres Pics');
      expect(d.country, 'España');
      expect(d.tags, ['Inmersión desde embarcación']);
      expect(d.minutes, 56);
      expect(d.depth, 21);
      expect(d.buddies, ['Ana Pérez']);
    });

    test('el fichero de reference/ (si existe) se lee entero', () {
      final f = File('reference/ssi-divelog.csv');
      if (!f.existsSync()) return;
      final p = parseSsiCsv(f.readAsStringSync());
      expect(p.skipped, 0);
      expect(p.dives, isNotEmpty);
    });

    test('celda de compañeros: nombres pegados + centro + ordenador', () {
      const tabs8 = '\t\t\t\t\t\t\t\t';
      final a = parseSsiPeople('Ana  PérezLuis Gil Ruiz$tabs8       '
          'MAR AZUL DIVE');
      expect(a.people, ['Ana Pérez', 'Luis Gil Ruiz']);
      expect(a.center, 'MAR AZUL DIVE');
      expect(a.computer, isNull);
      final b = parseSsiPeople('José  NúñezÁlvaro Sanz$tabs8$tabs8\t Puck4');
      expect(b.people, ['José Núñez', 'Álvaro Sanz']);
      expect(b.center, isNull);
      expect(b.computer, 'Puck4');
      final c = parseSsiPeople('Ana Pérez$tabs8    SSI Europe - Spain    '
          '$tabs8\t Puck4');
      expect(c.people, ['Ana Pérez']);
      expect((c.center, c.computer), ('SSI Europe - Spain', 'Puck4'));
      expect(parseSsiPeople('Pablo Soto, Eva Mas').people,
          ['Pablo Soto', 'Eva Mas']);
      expect(parseSsiPeople('').people, isEmpty);
    });

    test('etiquetas: especialidades + actividad/tipo no habituales', () {
      String row(String act, String spec, String type) =>
          '"1","X","España","15. Apr 2026 10:00","$act","$spec","$type",'
          '"40 min","10 m",""\n';
      final p = parseSsiCsv(_header +
          row('Buceo', 'Nitrox, Buceo Profundo', 'Inmersión de ocio') +
          row('Buceo\t\t\t\tInmersión con descompresión', '',
              'Inmersión de ocio') +
          row('Extended Range', 'Nitrox', 'Educación'));
      expect(p.dives.map((d) => d.tags), [
        ['Nitrox', 'Buceo Profundo'],
        ['Inmersión con descompresión'],
        ['Nitrox', 'Extended Range', 'Educación'],
      ]);
    });

    test('fechas en varios formatos e idiomas', () {
      DateTime? f(String s) => parseSsiDate(s)?.date;
      expect(f('15. Apr 2026'), DateTime(2026, 4, 15, 12));
      expect(f('3 dic. 2025'), DateTime(2025, 12, 3, 12));
      expect(f('7 juil. 2024'), DateTime(2024, 7, 7, 12));
      expect(f('7 juin 2024'), DateTime(2024, 6, 7, 12));
      expect(f('Apr 15, 2026'), DateTime(2026, 4, 15, 12));
      expect(f('15.04.2026'), DateTime(2026, 4, 15, 12));
      expect(f('2026-04-15'), DateTime(2026, 4, 15, 12));
      final t = parseSsiDate('15. Apr 2026 09:40')!;
      expect(t.date, DateTime(2026, 4, 15, 9, 40));
      expect(t.hasTime, isTrue);
      expect(parseSsiDate('Fecha / Tiempo'), isNull);
    });

    test('duración y profundidad', () {
      expect(parseSsiMinutes('56 min'), 56);
      expect(parseSsiMinutes('1 h 5 min'), 65);
      expect(parseSsiDepth('21 m \t\t(69 ft)'), 21);
      expect(parseSsiDepth('18,5 m'), 18.5);
      expect(parseSsiDepth('69 ft (21 m)'), 21);
      expect(parseSsiDepth('100 ft')!, closeTo(30.48, 0.01));
    });

    test('separador ; y comillas escapadas', () {
      final rows = parseCsv('"a";"b ""c""";d\r\n1;2;3\r\n');
      expect(rows, [
        ['a', 'b "c"', 'd'],
        ['1', '2', '3'],
      ]);
    });
  });

  group('importar', () {
    late Directory tmp;
    late DivemateDb db;
    setUp(() {
      open.overrideFor(
          OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
      tmp = Directory.systemTemp.createTempSync('pandive_ssi');
      DivemateDb.createEmpty('${tmp.path}/a.ddb').close();
      db = DivemateDb.open('${tmp.path}/a.ddb');
    });
    tearDown(() {
      db.close();
      tmp.deleteSync(recursive: true);
    });

    test('dos del mismo día, sitio/compañeros/etiqueta; reimportar = 0', () async {
      final csv = _header +
          _row(2, 'Tres Pics', '15. Apr 2026', '50 min', '18 m (59 ft)') +
          _row(1, 'El Fitó', '15. Apr 2026', '56 min', '21 m (69 ft)',
              'Ana, Pep');
      final r = await importSsiCsv(db, csv);
      expect((r.added, r.duplicates, r.skipped), (2, 0, 0));
      final dives = db.listDives().reversed.toList(); // cronológico
      expect(dives.map((d) => d.place), ['El Fitó', 'Tres Pics']);
      expect(dives.map((d) => d.number), [1, 2]);
      expect(dives.first.maxDepth, 21);
      expect(dives.first.durationMin, 56);
      expect(dives.first.buddy, 'Ana, Pep');
      expect(db.effectiveTagsForDive(dives.first.id).map((t) => t.name),
          contains('Inmersión desde embarcación'));

      final again = await importSsiCsv(db, csv);
      expect((again.added, again.duplicates), (0, 2));
      expect(db.listDives(), hasLength(2));
    });

    test('no duplica un buceo descargado del ordenador (con hora real)', () async {
      db.createDive(dateTime: DateTime(2026, 4, 15, 10, 12));
      final id = db.listDives().single.id;
      db.updateDive(id, {'Depth': 21.3, 'Divetime': 57.0});
      final r = await importSsiCsv(
          db, _header + _row(1, 'X', '15. Apr 2026', '56 min', '21 m'));
      expect((r.added, r.duplicates), (0, 1));
      // Pero una distinta ese mismo día sí entra.
      final r2 = await importSsiCsv(
          db, _header + _row(2, 'Y', '15. Apr 2026', '40 min', '12 m'));
      expect(r2.added, 1);
    });

    test('con hora: igual perfil pero a horas lejanas no es duplicado', () async {
      db.createDive(dateTime: DateTime(2026, 4, 15, 10, 12));
      db.updateDive(db.listDives().single.id, {'Depth': 21.0, 'Divetime': 56.0});
      String row(String t) =>
          _row(1, 'X', '15. Apr 2026 $t', '56 min', '21 m');
      expect((await importSsiCsv(db, _header + row('10:40'))).duplicates, 1);
      final r = await importSsiCsv(db, _header + row('19:59'));
      expect(r.added, 1);
      expect(db.listDives().first.date, DateTime(2026, 4, 15, 19, 59));
    });

    test('desfase de ~1 h y diferencias entre ordenadores; elige la más parecida', () async {
      // Dos buceos tuyos ese día; el CSV trae el de las 10:31 con 1 h de
      // desfase (11:32) y lecturas de otro ordenador.
      db.createDive(dateTime: DateTime(2025, 11, 20, 9, 5));
      db.createDive(dateTime: DateTime(2025, 11, 20, 10, 31));
      final ds = db.listDives(); // más reciente primero
      db.updateDive(ds[0].id, {'Depth': 32.2, 'Divetime': 83.8});
      db.updateDive(ds[1].id, {'Depth': 31.0, 'Divetime': 80.0});
      final r = await importSsiCsv(db,
          _header + _row(1, 'Panorama', '20. Nov 2025 11:32', '84 min', '32.2 m'));
      expect((r.added, r.duplicates), (0, 1));
      // Otro buceo del mismo día con perfil distinto sí entra.
      final r2 = await importSsiCsv(db,
          _header + _row(2, 'Otro', '20. Nov 2025 17:35', '85 min', '16.2 m'));
      expect(r2.added, 1);
    });

    test('plan: marca existentes sin escribir; importa solo lo elegido', () async {
      db.createDive(dateTime: DateTime(2026, 4, 15, 10, 12));
      db.updateDive(db.listDives().single.id, {'Depth': 21.0, 'Divetime': 56.0});
      final csv = _header +
          _row(1, 'A', '15. Apr 2026 10:10', '56 min', '21 m') +
          _row(2, 'B', '16. Apr 2026 10:00', '40 min', '12 m') +
          _row(3, 'C', '17. Apr 2026 10:00', '45 min', '15 m');
      final plan = planSsiImport(db, csv);
      expect(plan.entries.map((e) => e.duplicate), [true, false, false]);
      expect(db.listDives(), hasLength(1)); // el plan no escribe
      final done = <int>[];
      final added = await applySsiImport(db, [plan.entries[2].dive],
          onProgress: (d, _) => done.add(d));
      expect(added, 1);
      expect(done, [1]);
      expect(db.listDives().map((d) => d.place), contains('C'));
      expect(db.listDives().map((d) => d.place), isNot(contains('B')));
    });
  });
}
