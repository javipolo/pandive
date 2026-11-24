// Pantalla de revisión del CSV de SSI: desmarcar, importar solo lo marcado y
// volver a la raíz pidiendo la lista de buceos.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/ssi_csv_import.dart';
import 'package:pandive/core/services/home_navigation.dart';
import 'package:pandive/features/settings/screens/import_ssi_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'package:sqlite3/open.dart';

void main() {
  late Directory tmp;
  late DivemateDb db;
  setUp(() {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    tmp = Directory.systemTemp.createTempSync('pandive_ssi_ui');
    DivemateDb.createEmpty('${tmp.path}/a.ddb').close();
    db = DivemateDb.open('${tmp.path}/a.ddb');
  });
  tearDown(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('desmarcar una e importar el resto', (tester) async {
    final entries = [
      for (final (i, site) in ['Uno', 'Dos', 'Tres'].indexed)
        SsiPlanEntry(
            SsiDive(date: DateTime(2026, 4, 10 + i, 10), site: site,
                hasTime: true, minutes: 40, depth: 12),
            duplicate: false),
    ];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ImportSsiScreen(db: db, entries: entries))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(3)'), findsOneWidget);

    await tester.tap(find.text('Dos'));
    await tester.pump();
    expect(find.textContaining('(2)'), findsOneWidget);

    await tester.tap(find.textContaining('(2)'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget); // de vuelta en la raíz
    expect(homeSectionRequest.value, 0);
    expect(db.listDives().map((d) => d.place).toSet(), {'Uno', 'Tres'});
  });
}
