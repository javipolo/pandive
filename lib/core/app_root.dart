/// AppRoot: decide la pantalla inicial. Si hay una DB válida, la app; si no,
/// crea una vacía automáticamente (primer arranque) o muestra la pantalla de
/// carga (al Cambiar base de datos o ante un error).
library;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'db/divemate_db.dart';
import 'services/drive_backup.dart';
import 'settings/settings.dart';
import '../features/home/screens/home_screen.dart';
import '../features/load_db/screens/load_db_screen.dart';

class AppRoot extends StatefulWidget {
  final Settings settings;
  const AppRoot({super.key, required this.settings});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  DivemateDb? _db;
  DbLoadError? _error;
  String? _errorDetail;
  bool _forceLoad = false; // true = mostrar la pantalla de carga (Cambiar DB)

  @override
  void initState() {
    super.initState();
    _tryOpen(widget.settings.dbPath);
  }

  void _tryOpen(String? path) {
    _db?.close();
    _db = null;
    _error = null;
    _errorDetail = null;
    if (path == null) {
      // Primer arranque sin DB: crear una vacía automáticamente. Si el usuario
      // eligió "Cambiar base de datos" (_forceLoad), mostrar la pantalla.
      if (_forceLoad) {
        setState(() {});
      } else {
        _autoCreate();
      }
      return;
    }
    try {
      final db = DivemateDb.open(path);
      if (!db.looksValid) {
        db.close();
        _error = DbLoadError.invalid;
      } else {
        _db = db;
        _maybeBackup();
      }
    } catch (e) {
      _error = DbLoadError.openFailed;
      _errorDetail = '$e';
    }
    setState(() {});
  }

  // Crea un logbook vacío en los documentos de la app y lo abre.
  Future<void> _autoCreate() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dest = '${docs.path}/logbook.ddb';
      DivemateDb.createEmpty(dest).close();
      await widget.settings.setDbPath(dest);
      if (mounted) _tryOpen(dest);
    } catch (e) {
      _error = DbLoadError.openFailed;
      _errorDetail = '$e';
      _forceLoad = true; // caer a la pantalla de carga manual
      if (mounted) setState(() {});
    }
  }

  // Backup diario automático a Drive (silencioso; no hace nada si no procede).
  void _maybeBackup() {
    DriveBackupService().backupIfNeeded(widget.settings);
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
      // Mientras se crea la DB automáticamente (sin error ni Cambiar DB).
      if (_error == null && !_forceLoad) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return LoadDbScreen(
        settings: widget.settings,
        error: _error,
        errorDetail: _errorDetail,
        onLoaded: (path) async {
          await widget.settings.setDbPath(path);
          _forceLoad = false;
          _tryOpen(path);
        },
      );
    }
    return HomeScreen(
      key: ValueKey(db), // nueva DB (reload/restore) -> reconstruye pestañas
      db: db,
      settings: widget.settings,
      onChangeDb: () async {
        await widget.settings.setDbPath(null);
        _forceLoad = true;
        _tryOpen(null);
      },
      onReloadDb: () => _tryOpen(widget.settings.dbPath),
    );
  }
}
