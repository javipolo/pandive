/// Sincronización entre dispositivos vía Drive (capa 1): estado observable
/// para la UI y disparadores (abrir/volver a la app, tras editar, cada ~2 min
/// y al salir). Decide con [decideSync]; nunca fusiona ni pisa en silencio.
library;

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'backup_worker.dart';
import 'drive_backup.dart';
import 'network.dart';
import 'sync_logic.dart';

enum SyncStatus {
  off, synced, syncing, pendingRemote, diverged, offline,
  manual, // datos móviles con "solo WiFi": no se sincroniza solo
}

/// Instancia única (la conecta AppRoot con [SyncController.attach]).
final syncController = SyncController();

class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  static const _tickEvery = Duration(seconds: 20);
  static const _presenceEvery = Duration(minutes: 1);
  static const _presenceFresh = Duration(minutes: 5);

  final _svc = DriveBackupService();
  Settings? _s;
  DivemateDb? Function()? _db;
  Future<void> Function(File)? _replace;
  bool Function()? _canAutoReplace;
  Timer? _timer;
  int _ticks = 0;
  String? _lastSeenStamp;
  int _quietTicks = 0; // ticks seguidos con el mismo sello local
  bool _running = false;
  DateTime _lastPresence = DateTime(0);

  SyncStatus status = SyncStatus.off;
  DateTime? lastSync;
  String? lastError;
  DevicePresence? otherActive; // otro dispositivo abierto hace < 5 min

  bool get enabled =>
      (_s?.syncEnabled ?? false) && DriveBackupService.configured;

  /// [db]: DB abierta ahora; [replace]: cierra la DB, la sustituye por el
  /// fichero dado y la reabre; [canAutoReplace]: si se puede sustituir sin
  /// molestar (ninguna pantalla abierta encima de la principal).
  void attach({
    required Settings settings,
    required DivemateDb? Function() db,
    required Future<void> Function(File) replace,
    required bool Function() canAutoReplace,
  }) {
    _s = settings;
    _db = db;
    _replace = replace;
    _canAutoReplace = canAutoReplace;
    if (_timer == null) {
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(_tickEvery, (_) => _onTick());
    }
  }

  Future<void> setEnabled(bool v) async {
    await _s?.setSyncEnabled(v);
    if (v) {
      await sync(force: true); // acción del usuario: puede bajar ya
    } else {
      _set(SyncStatus.off);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En escritorio "resumed" llega con cada cambio de foco: no repetir si se
    // acaba de sincronizar.
    final recent = lastSync != null &&
        DateTime.now().difference(lastSync!) < const Duration(seconds: 30);
    if (state == AppLifecycleState.resumed && !recent) sync(auto: true);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      sync(allowDownload: false, auto: true); // subir lo pendiente al irnos
      // Android congela la app en segundo plano a los pocos segundos: si la
      // subida no termina, la hace WorkManager en cuanto haya red.
      final stamp = _db?.call()?.lastWriteRaw;
      if (enabled && stamp != _s!.syncBaseStamp) {
        enqueueSyncUpload(wifiOnly: _s!.syncWifiOnly);
      }
    }
  }

  // Sube tras ~2 min sin escrituras (debounce) y mira Drive cada ~2 min.
  void _onTick() {
    if (!enabled || _running || status == SyncStatus.diverged) return;
    _ticks++;
    final stamp = _db?.call()?.lastWriteRaw;
    _quietTicks = stamp == _lastSeenStamp ? _quietTicks + 1 : 0;
    // Subir tras 6 ticks (~2 min) sin escribir: agrupa una sesión de edición
    // (con pausas para buscar información) en una sola subida.
    if (stamp != _s!.syncBaseStamp && _quietTicks >= 6) {
      sync(allowDownload: false, auto: true);
    } else if (_ticks % 6 == 0) {
      sync(allowDownload: false, auto: true);
    }
    _lastSeenStamp = stamp;
  }

  /// Una pasada. Si hay que bajar y [allowDownload] (o [force]) lo permite y
  /// no molesta, sustituye la DB local; si no, queda pendiente. [auto]: la
  /// lanza un disparador (no el usuario); con "solo WiFi" y datos móviles no
  /// hace nada (ni comprobar) y marca la sync como manual.
  Future<void> sync(
      {bool allowDownload = true, bool force = false, bool auto = false}) async {
    if (!enabled) return _set(SyncStatus.off);
    if (_running) return;
    if (auto && _s!.syncWifiOnly && !await onUnmeteredNetwork()) {
      // conservar avisos importantes ya conocidos
      if (status != SyncStatus.diverged && status != SyncStatus.pendingRemote) {
        _set(SyncStatus.manual);
      }
      return;
    }
    _running = true;
    _set(SyncStatus.syncing);
    try {
      await _s!.reload(); // la base puede haberla movido el worker
      await _syncOnce(allowDownload, force);
    } catch (e) {
      lastError = '$e';
      _set(SyncStatus.offline);
    } finally {
      _running = false;
    }
  }

  Future<void> _syncOnce(bool allowDownload, bool force) async {
    final s = _s!;
    final db = _db?.call();
    if (db == null) return _set(SyncStatus.off);
    final remote = await _svc.remoteSync();
    if (remote == null) return _set(SyncStatus.offline);
    await _presence();
    final action = decideSync(SyncObservation(
      baseMd5: s.syncBaseMd5,
      baseStamp: s.syncBaseStamp,
      localStamp: db.lastWriteRaw,
      localEmpty: db.listDives().isEmpty,
      remoteExists: remote.exists,
      remoteMd5: remote.md5,
    ));
    switch (action) {
      case SyncAction.none:
        _synced();
      case SyncAction.upload:
        await _upload(db, remote);
        _synced();
      case SyncAction.download:
        if (force || (allowDownload && _canAutoReplace!())) {
          await _download(remote);
          _synced();
        } else {
          _set(SyncStatus.pendingRemote);
        }
      case SyncAction.diverged:
        _set(SyncStatus.diverged);
    }
  }

  /// Divergencia: quedarse con esta versión ([keepLocal]) o con la de Drive.
  /// La descartada se guarda como backup con timestamp.
  Future<void> resolve({required bool keepLocal}) async {
    if (_running) return;
    _running = true;
    _set(SyncStatus.syncing);
    try {
      final db = _db!()!;
      final remote = await _svc.remoteSync();
      if (remote == null) return _set(SyncStatus.offline);
      if (keepLocal) {
        final theirs = await _svc.downloadSync(remote);
        if (theirs != null) await _svc.uploadDiscarded(theirs);
        await _upload(db, remote);
      } else {
        await _svc.uploadDiscarded((await _snapshot(db)).$1);
        await _download(remote);
      }
      _synced();
    } catch (e) {
      lastError = '$e';
      _set(SyncStatus.offline);
    } finally {
      _running = false;
    }
  }

  Future<void> _upload(DivemateDb db, RemoteSync remote) =>
      _uploadSnapshot(_svc, _s!, db, remote);

  Future<void> _download(RemoteSync remote) async {
    final bytes = await _svc.downloadSync(remote);
    if (bytes == null) throw StateError('empty download');
    final tmp = File('${Directory.systemTemp.path}/pandive-sync-'
        '${DateTime.now().microsecondsSinceEpoch}.ddb');
    await tmp.writeAsBytes(bytes, flush: true);
    await _replace!(tmp);
    await _svc.syncDocumentsDown();
    // El sello base es el de la DB ya reabierta (por si abrir escribe algo).
    await _s!.setSyncBase(remote.md5, _db?.call()?.lastWriteRaw);
    await _saveBaseCopy(bytes);
  }


  Future<void> _presence() async {
    final now = DateTime.now();
    if (now.difference(_lastPresence) < _presenceEvery) return;
    _lastPresence = now;
    await _svc.writePresence(_s!.deviceId, deviceName);
    final others = await _svc.otherPresence(_s!.deviceId);
    others.sort((a, b) => b.time.compareTo(a.time));
    otherActive = others.isNotEmpty &&
            now.toUtc().difference(others.first.time) < _presenceFresh
        ? others.first
        : null;
  }

  /// Nombre legible de este dispositivo para la presencia.
  static String get deviceName => Platform.isAndroid
      ? 'Android'
      : '${Platform.operatingSystem} (${Platform.localHostname})';

  void _synced() {
    lastSync = DateTime.now();
    lastError = null;
    _lastSeenStamp = _db?.call()?.lastWriteRaw;
    _set(SyncStatus.synced);
  }

  void _set(SyncStatus st) {
    status = st;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Compartido con el worker de segundo plano
// ---------------------------------------------------------------------------

// Instantánea consistente + su sello (leídos en el mismo instante).
Future<(List<int>, String?)> _snapshot(DivemateDb db) async {
  final f = File('${Directory.systemTemp.path}/pandive-snap-'
      '${DateTime.now().microsecondsSinceEpoch}.ddb');
  final stamp = db.lastWriteRaw;
  db.snapshotTo(f.path);
  final bytes = await f.readAsBytes();
  await f.delete();
  return (bytes, stamp);
}

Future<void> _uploadSnapshot(DriveBackupService svc, Settings s, DivemateDb db,
    RemoteSync remote) async {
  final (bytes, stamp) = await _snapshot(db);
  final md5 = await svc.uploadSync(bytes, remote);
  if (md5 == null) throw StateError('upload without md5');
  await s.setSyncBase(md5, stamp);
  await _saveBaseCopy(bytes);
  await svc.syncDocumentsUp(s);
}

// Copia de la versión base (la necesitará la fusión de tres vías, capa 2).
Future<void> _saveBaseCopy(List<int> bytes) async {
  final dir = await getApplicationSupportDirectory();
  await File('${dir.path}/sync-base.ddb').writeAsBytes(bytes, flush: true);
}

/// Subida desde WorkManager (app congelada o cerrada): abre la DB en solo
/// lectura y sube solo si el único cambio es local. Nunca baja ni resuelve
/// divergencias (eso necesita la UI).
Future<void> syncUploadInBackground(Settings s) async {
  final path = s.dbPath;
  if (!s.syncEnabled || path == null) return;
  final svc = DriveBackupService();
  final remote = await svc.remoteSync();
  if (remote == null) throw StateError('no network'); // WorkManager reintenta
  final db = DivemateDb.open(path, readOnly: true);
  try {
    final action = decideSync(SyncObservation(
      baseMd5: s.syncBaseMd5,
      baseStamp: s.syncBaseStamp,
      localStamp: db.lastWriteRaw,
      localEmpty: db.listDives().isEmpty,
      remoteExists: remote.exists,
      remoteMd5: remote.md5,
    ));
    if (action == SyncAction.upload) await _uploadSnapshot(svc, s, db, remote);
  } finally {
    db.close();
  }
}
