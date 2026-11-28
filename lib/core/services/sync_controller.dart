/// Cross-device sync via Drive (layer 1): observable state
/// for the UI and triggers (open/return to the app, after editing, every ~2 min
/// and on exit). Decides with [decideSync]; never merges or overwrites silently.
library;

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/db/open/sqlite_open.dart';
import 'package:pandive/core/settings/settings.dart';
import 'backup_worker.dart';
import 'drive_backup.dart';
import 'network.dart';
import 'sync_logic.dart';
import '../platform.dart';

enum SyncStatus {
  off, synced, syncing, pendingRemote, diverged, offline,
  manual, // mobile data with "WiFi only": doesn't sync by itself
}

/// Single instance (attached by AppRoot with [SyncController.attach]).
final syncController = SyncController();

class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  static const _tickEvery = Duration(seconds: 20);
  static const _presenceEvery = Duration(minutes: 1);
  static const _presenceFresh = Duration(minutes: 5);

  final _svc = DriveBackupService();
  Settings? _s;
  DivemateDb? Function()? _db;
  Future<void> Function(List<int>)? _replace;
  bool Function()? _canAutoReplace;
  Timer? _timer;
  int _ticks = 0;
  String? _lastSeenStamp;
  int _quietTicks = 0; // consecutive ticks with the same local stamp
  bool _running = false;
  DateTime _lastPresence = DateTime(0);

  SyncStatus status = SyncStatus.off;
  DateTime? lastSync;
  String? lastError;
  DevicePresence? otherActive; // another device open < 5 min ago

  bool get enabled =>
      (_s?.syncEnabled ?? false) && DriveBackupService.configured;

  /// [db]: currently open DB; [replace]: closes the DB, replaces it with the
  /// given content and reopens it; [canAutoReplace]: whether it can be replaced without
  /// disturbing (no screen open on top of the main one).
  void attach({
    required Settings settings,
    required DivemateDb? Function() db,
    required Future<void> Function(List<int>) replace,
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
      await sync(force: true); // user action: may download right away
    } else {
      _set(SyncStatus.off);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On desktop "resumed" arrives on every focus change: don't repeat if we
    // just synced.
    final recent = lastSync != null &&
        DateTime.now().difference(lastSync!) < const Duration(seconds: 30);
    if (state == AppLifecycleState.resumed && !recent) sync(auto: true);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      sync(allowDownload: false, auto: true); // upload what's pending as we leave
      // Android freezes the app in the background after a few seconds: if the
      // upload doesn't finish, WorkManager does it as soon as there's network.
      final stamp = _db?.call()?.lastWriteRaw;
      if (enabled && stamp != _s!.syncBaseStamp) {
        enqueueSyncUpload(wifiOnly: _s!.syncWifiOnly);
      }
    }
  }

  // Uploads after ~2 min without writes (debounce) and checks Drive every ~2 min.
  void _onTick() {
    if (!enabled || _running || status == SyncStatus.diverged) return;
    _ticks++;
    final stamp = _db?.call()?.lastWriteRaw;
    _quietTicks = stamp == _lastSeenStamp ? _quietTicks + 1 : 0;
    // Upload after 6 ticks (~2 min) without writing: groups an editing session
    // (with pauses to look things up) into a single upload.
    if (stamp != _s!.syncBaseStamp && _quietTicks >= 6) {
      sync(allowDownload: false, auto: true);
    } else if (_ticks % 6 == 0) {
      sync(allowDownload: false, auto: true);
    }
    _lastSeenStamp = stamp;
  }

  /// One pass. If it needs to download and [allowDownload] (or [force]) allows it and
  /// it doesn't disturb, replaces the local DB; otherwise it stays pending. [auto]:
  /// launched by a trigger (not the user); with "WiFi only" and mobile data it
  /// does nothing (not even check) and marks sync as manual.
  Future<void> sync(
      {bool allowDownload = true, bool force = false, bool auto = false}) async {
    if (!enabled) return _set(SyncStatus.off);
    if (_running) return;
    if (auto && _s!.syncWifiOnly && !await onUnmeteredNetwork()) {
      // keep important warnings already known
      if (status != SyncStatus.diverged && status != SyncStatus.pendingRemote) {
        _set(SyncStatus.manual);
      }
      return;
    }
    _running = true;
    _set(SyncStatus.syncing);
    try {
      await _s!.reload(); // the worker may have moved the base
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

  /// Divergence: keep this version ([keepLocal]) or Drive's.
  /// The discarded one is saved as a timestamped backup.
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
    await _replace!(bytes);
    await _svc.syncDocumentsDown();
    // The base stamp is that of the reopened DB (in case opening writes something).
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

  /// Readable name of this device for presence.
  static String get deviceName => isAndroid
      ? 'Android'
      : isWeb
          ? 'Web'
          : '${Platform.operatingSystem} (${Platform.localHostname})';

  /// Local changes not on Drive yet (or a pass running): leaving the page
  /// now would lose them (web asks before closing).
  bool get hasUnsyncedChanges {
    if (!enabled) return false;
    return _running ||
        status == SyncStatus.diverged ||
        _db?.call()?.lastWriteRaw != _s!.syncBaseStamp;
  }

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
// Shared with the background worker
// ---------------------------------------------------------------------------

// Consistent snapshot + its stamp (read at the same instant).
Future<(List<int>, String?)> _snapshot(DivemateDb db) async {
  final path =
      tempDbPath('pandive-snap-${DateTime.now().microsecondsSinceEpoch}.ddb');
  final stamp = db.lastWriteRaw;
  db.snapshotTo(path);
  final bytes = await readDbFile(path);
  await deleteDbFile(path);
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

// Copy of the base version (the three-way merge, layer 2, will need it).
Future<void> _saveBaseCopy(List<int> bytes) async {
  if (isWeb) return; // in-memory only there: nothing to keep
  final dir = await getApplicationSupportDirectory();
  await File('${dir.path}/sync-base.ddb').writeAsBytes(bytes, flush: true);
}

/// Upload from WorkManager (app frozen or closed): opens the DB read-only
/// and uploads only if the only change is local. Never downloads or resolves
/// divergences (that needs the UI).
Future<void> syncUploadInBackground(Settings s) async {
  final path = s.dbPath;
  if (!s.syncEnabled || path == null) return;
  final svc = DriveBackupService();
  final remote = await svc.remoteSync();
  if (remote == null) throw StateError('no network'); // WorkManager retries
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
