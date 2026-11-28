import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app.dart';
import 'core/db/open/sqlite_open.dart';
import 'core/services/backup_worker.dart';
import 'core/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // all locales (es + en)
  await initSqlite(); // web: loads sqlite3.wasm (no-op on native)
  await initBackupWorker(); // automatic background backup (WorkManager)
  final settings = await Settings.load();
  runApp(PandiveApp(settings: settings));
}
