/// AppRoot: picks the initial screen. With a valid DB, the app; otherwise it
/// creates an empty one automatically (first launch) or shows the load
/// screen (on Change database or after an error).
library;

import 'package:material_ui/material_ui.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'db/divemate_db.dart';
import 'platform.dart';
import 'services/backup_worker.dart';
import 'services/drive_backup.dart';
import 'services/sync_controller.dart';
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
  // true = show the load screen (Change DB). On web the logbook lives in
  // memory and is gone on reload: always start by picking a file.
  bool _forceLoad = isWeb;

  @override
  void initState() {
    super.initState();
    _tryOpen(isWeb ? null : widget.settings.dbPath);
  }

  void _tryOpen(String? path) {
    _db?.close();
    _db = null;
    _error = null;
    _errorDetail = null;
    if (path == null) {
      // First launch without DB: create an empty one automatically. If the user
      // chose "Change database" (_forceLoad), show the screen.
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
        if (!isWeb) {
          _maybeBackup();
          _startSync();
        }
      }
    } catch (e) {
      _error = DbLoadError.openFailed;
      _errorDetail = '$e';
    }
    setState(() {});
  }

  // Creates an empty logbook in the app documents and opens it.
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
      _forceLoad = true; // fall back to the manual load screen
      if (mounted) setState(() {});
    }
  }

  // Drive backup: immediate copy on startup (silent) and, if automatic
  // backup is on, (re)schedules the periodic background task.
  void _maybeBackup() {
    DriveBackupService().backupIfNeeded(widget.settings);
    if (widget.settings.autoBackup) {
      registerAutoBackup(wifiOnly: widget.settings.backupWifiOnly);
    }
  }

  // Cross-device sync: attach the controller to this DB and sync
  // (also after reload/restore: a local change gets uploaded).
  void _startSync() {
    syncController.attach(
      settings: widget.settings,
      db: () => _db,
      replace: _replaceFromSync,
      canAutoReplace: () => mounted && !Navigator.of(context).canPop(),
    );
    Future.microtask(() => syncController.sync(auto: true));
  }

  // Replaces the active DB with the version downloaded from Drive (close, copy,
  // reopen). Goes back to the main screen: open ones use the old DB.
  Future<void> _replaceFromSync(File src) async {
    final path = widget.settings.dbPath;
    if (path == null) return;
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    _db?.close();
    _db = null;
    await src.copy(path);
    await src.delete();
    _tryOpen(path);
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
      // While the DB is created automatically (no error and no Change DB).
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
      key: ValueKey(db), // new DB (reload/restore) -> rebuild tabs
      db: db,
      settings: widget.settings,
      onChangeDb: () async {
        await widget.settings.setDbPath(null);
        _forceLoad = true;
        _tryOpen(null);
      },
      onReloadDb: () => _tryOpen(widget.settings.dbPath),
      onReplaceDb: _replaceDb,
    );
  }

  // Replaces the active DB with the .ddb at [src] (copy to documents and open).
  Future<void> _replaceDb(String src) async {
    final docs = await getApplicationDocumentsDirectory();
    final dest = '${docs.path}/logbook-${DateTime.now().millisecondsSinceEpoch}.ddb';
    await File(src).copy(dest);
    await widget.settings.setDbPath(dest);
    _tryOpen(dest);
  }
}
