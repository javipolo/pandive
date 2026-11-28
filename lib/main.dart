import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app.dart';
import 'core/db/open/sqlite_open.dart';
import 'core/services/sync_controller.dart';
import 'core/services/unload_guard.dart';
import 'core/services/web_oauth.dart';
import 'core/services/backup_worker.dart';
import 'core/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // all locales (es + en)
  await initSqlite(); // web: loads sqlite3.wasm (no-op on native)
  initWebOAuth(); // web: preload Google sign-in (popup on click)
  installUnloadGuard(() => syncController.hasUnsyncedChanges); // web
  await initBackupWorker(); // automatic background backup (WorkManager)
  final settings = await Settings.load();
  runApp(PandiveApp(settings: settings));
}
