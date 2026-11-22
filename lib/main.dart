import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app.dart';
import 'core/services/backup_worker.dart';
import 'core/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // DIAGNÓSTICO (temporal): pinta el texto del error en vez del cuadro gris de
  // release, para ver en captura si las zonas grises son excepciones.
  ErrorWidget.builder = (FlutterErrorDetails d) => Container(
        color: const Color(0xFFB00020),
        padding: const EdgeInsets.all(6),
        alignment: Alignment.center,
        child: Text(
          d.exceptionAsString(),
          textDirection: TextDirection.ltr,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 9),
        ),
      );
  await initializeDateFormatting(); // todos los locales (es + en)
  await initBackupWorker(); // backup automático en segundo plano (WorkManager)
  final settings = await Settings.load();
  runApp(PandiveApp(settings: settings));
}
