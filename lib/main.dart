import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app.dart';
import 'core/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final settings = await Settings.load();
  runApp(PandiveApp(settings: settings));
}
