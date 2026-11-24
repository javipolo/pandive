// Imagen exportada del perfil: el pie de datos cabe (sin overflow) con y sin
// deco. Con PANDIVE_CARD_PNG=<ruta> guarda la captura para revisarla.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/logic/dive_facts.dart';
import 'package:pandive/features/dives/logic/share_profile.dart';
import 'package:pandive/l10n/app_localizations.dart';

DiveProfile _profile({bool deco = false}) {
  final n = 60;
  return DiveProfile(
    intervalSeconds: 60,
    timesMinutes: [for (var i = 0; i < n; i++) i.toDouble()],
    depths: [for (var i = 0; i < n; i++) i < 5 ? i * 8.0 : (i > 50 ? (n - i) * 4.0 : 40)],
    temps: [for (var i = 0; i < n; i++) 14.0 + (i < 5 ? 5 - i : 0)],
    ceiling: [for (var i = 0; i < n; i++) deco && i > 30 && i < 55 ? 6.0 : 0],
    tts: [for (var i = 0; i < n; i++) deco && i > 30 && i < 55 ? 18 - i ~/ 4 : null],
  );
}

// Carga Roboto (si está en la caché de Flutter) para que la captura se lea.
Future<void> _loadFonts() async {
  final home = Platform.environment['HOME'];
  final f = File('$home/javi/git/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await loader.load();
}

void main() {
  for (final deco in [false, true]) {
    testWidgets('pie de la imagen ${deco ? 'con' : 'sin'} deco', (tester) async {
      final out = Platform.environment['PANDIVE_CARD_PNG'];
      if (out != null) await _loadFonts(); // solo para la captura de revisión
      final profile = _profile(deco: deco);
      final dive = Dive(id: 1, durationMin: 60, maxDepth: 40.2, deco: deco ? 1 : 0);
      final facts = DiveFacts.of(dive, profile);
      expect(facts.isDeco, deco);
      if (deco) {
        expect(facts.maxTts, 11);
        expect(facts.maxCeiling, 6);
      }
      final key = GlobalKey();
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: out != null ? ThemeData(fontFamily: 'Roboto') : null,
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: ProfileShareCard(
                  profile: profile,
                  title: '15/04/2026 - El Fitó',
                  facts: facts,
                  gasChanges: const []),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Duración'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('40.2 m'), findsOneWidget);
      expect(find.text('14.0 °C'), findsOneWidget);
      expect(find.text('TTS máx.'), deco ? findsOneWidget : findsNothing);

      if (out != null) {
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await ro.toImage();
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          File(out.replaceAll('.png', deco ? '_deco.png' : '.png'))
              .writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
    });
  }
}
