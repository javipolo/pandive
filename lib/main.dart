import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'db/divemate_db.dart';
import 'settings.dart';
import 'ui/home_screen.dart';
import 'ui/load_db_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final settings = await Settings.load();
  runApp(PandiveApp(settings: settings));
}

class PandiveApp extends StatelessWidget {
  final Settings settings;
  const PandiveApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Pandive',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          builder: (context, child) {
            // Escala de texto global (accesibilidad / presbicia).
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: child!,
            );
          },
          home: AppRoot(settings: settings),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00677E), // azul buceo
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }
}

/// Decide la pantalla inicial: si hay una DB activa válida, la lista de
/// inmersiones; si no, la pantalla para cargar un .ddb.
class AppRoot extends StatefulWidget {
  final Settings settings;
  const AppRoot({super.key, required this.settings});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  DivemateDb? _db;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryOpen(widget.settings.dbPath);
  }

  void _tryOpen(String? path) {
    _db?.close();
    _db = null;
    _error = null;
    if (path == null) {
      setState(() {});
      return;
    }
    try {
      final db = DivemateDb.open(path);
      if (!db.looksValid) {
        db.close();
        _error = 'El fichero no parece una base de datos DiveMate válida.';
      } else {
        _db = db;
      }
    } catch (e) {
      _error = 'No se pudo abrir la base de datos: $e';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = _db;
    if (db == null) {
      return LoadDbScreen(
        settings: widget.settings,
        error: _error,
        onLoaded: (path) async {
          await widget.settings.setDbPath(path);
          _tryOpen(path);
        },
      );
    }
    return HomeScreen(
      db: db,
      settings: widget.settings,
      onChangeDb: () async {
        await widget.settings.setDbPath(null);
        _tryOpen(null);
      },
    );
  }
}
