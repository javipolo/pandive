/// App raíz: MaterialApp con escala de texto global, y AppRoot que decide la
/// pantalla inicial según haya o no una base de datos cargada.
library;

import 'package:flutter/material.dart';

import 'db/divemate_db.dart';
import 'settings/settings.dart';
import 'theme/app_theme.dart';
import '../features/home/screens/home_screen.dart';
import '../features/load_db/screens/load_db_screen.dart';

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
          theme: appTheme(Brightness.light),
          darkTheme: appTheme(Brightness.dark),
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
}

/// Decide la pantalla inicial: lista de inmersiones si hay DB válida, o la
/// pantalla de carga de un .ddb si no.
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
