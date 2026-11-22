import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app.dart';
import 'core/services/backup_worker.dart';
import 'core/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // todos los locales (es + en)
  await initBackupWorker(); // backup automático en segundo plano (WorkManager)
  final settings = await Settings.load();
  runApp(PandiveApp(settings: settings));
}
